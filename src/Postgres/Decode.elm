module Postgres.Decode exposing
    ( array1
    , array2
    , array2Column
    , arrayColumn
    , arrayN
    , bigint
    , bigintAsInt
    , boolean
    , bytea
    , cstring
    , cstringList
    , expandFlags
    , int
    , isFlagSet
    , jsonb
    , jsonbArray
    , list
    , nullable
    , nullableBytea
    , nullableString
    , nullableWithLength
    , oid
    , read
    , skip
    , smallint
    , string
    , trueIfNotZero
    )

import Bitwise
import Bytes exposing (Endianness(..))
import Bytes.Decode as Bytes exposing (Decoder, Step(..), andThen, bytes, fail, loop, map, map2, signedInt16, signedInt32, succeed, unsignedInt32, unsignedInt8)
import Json.Decode
import Postgres.Types.Bigint as Bigint exposing (Bigint, toIntWithDefault)
import Postgres.Types.Bytea exposing (Bytea)



-- General Decoders


read : Decoder a -> Decoder (a -> b) -> Decoder b
read decoder prev =
    andThen (\p -> map p decoder) prev


skip : Decoder ignore -> Decoder keep -> Decoder keep
skip decoderIgnore decoderKeep =
    andThen (\p -> map (always p) decoderIgnore) decoderKeep


list : Int -> Decoder a -> Decoder (List a)
list len decoder =
    let
        listStep dec ( n, xs ) =
            if n <= 0 then
                succeed (Done <| List.reverse xs)

            else
                map (\x -> Loop ( n - 1, x :: xs )) dec
    in
    loop ( len, [] ) (listStep decoder)


nullable : Decoder a -> Decoder (Maybe a)
nullable decoder =
    signedInt32 BE
        |> andThen
            (\len ->
                if len > -1 then
                    map Just decoder

                else
                    succeed Nothing
            )


nullableWithLength : (Int -> Decoder a) -> Decoder (Maybe a)
nullableWithLength decoder =
    signedInt32 BE
        |> andThen
            (\len ->
                if len > -1 then
                    map Just (decoder len)

                else
                    succeed Nothing
            )


string : Decoder String
string =
    andThen Bytes.string (unsignedInt32 BE)


int : Decoder Int
int =
    andThen (always (signedInt32 BE)) (unsignedInt32 BE)


oid : Decoder Int
oid =
    andThen (always (unsignedInt32 BE)) (unsignedInt32 BE)


smallint : Decoder Int
smallint =
    andThen (always (signedInt16 BE)) (unsignedInt32 BE)


bigint : Decoder Bigint
bigint =
    andThen (always Bigint.decoder) (unsignedInt32 BE)


bigintAsInt : Decoder Int
bigintAsInt =
    map (toIntWithDefault -1) bigint


boolean : Decoder Bool
boolean =
    andThen (always (map trueIfNotZero unsignedInt8)) (unsignedInt32 BE)


bytea : Decoder Bytea
bytea =
    unsignedInt32 BE
        |> andThen
            Postgres.Types.Bytea.decoder


nullableBytea : Decoder (Maybe Bytea)
nullableBytea =
    signedInt32 BE
        |> andThen
            (\len ->
                if len > -1 then
                    map Just (Postgres.Types.Bytea.decoder len)

                else
                    succeed Nothing
            )


jsonb : Decoder Json.Decode.Value
jsonb =
    {- Jsonb starts with a version number byte (0x01), followed by a cstring containing the json data.
       Len includes the version byte, so we need to reduce by one
    -}
    andThen Bytes.string (map2 (\len _ -> len - 1) (unsignedInt32 BE) unsignedInt8)
        |> andThen
            (\str ->
                case Json.Decode.decodeString Json.Decode.value str of
                    Ok v ->
                        succeed v

                    Err _ ->
                        fail
            )


jsonbArray : Decoder (List Json.Decode.Value)
jsonbArray =
    map (Json.Decode.decodeValue (Json.Decode.list Json.Decode.value) >> Result.withDefault []) jsonb


nullableString : Decoder (Maybe String)
nullableString =
    nullableWithLength Bytes.string


{-| Decodes an array column. Returns empty list if the column is null (column length is -1)
-}
arrayColumn : Decoder a -> Decoder (List a)
arrayColumn dec =
    signedInt32 BE
        |> andThen
            (\len ->
                if len > -1 then
                    array1 dec

                else
                    succeed []
            )


{-| Decodes a column with a two-dimensional array. Returns empty list if the column is null.
-}
array2Column : Decoder a -> Decoder (List (List a))
array2Column dec =
    signedInt32 BE
        |> andThen
            (\len ->
                if len > -1 then
                    array2 dec

                else
                    succeed [ [] ]
            )


{-| Decode a one-dimensional array as a list. If parsing a result set, use `arrayColumn` to take into account column length.

    int32 - 1
    int32 - flags ("has nulls" seems to be the only flag)
    int32 - element type oid
    int32 --length (which corresponds to upper bound index when indexing in sql, but we don't care about that)
    int32 --lower bound index in sql that we don't care about

list of items as in a row (len is -1 if null)

    length * int32 value

-}
array1 : Decoder a -> Decoder (List a)
array1 dec =
    unsignedInt32 BE
        |> skip (bytes 8)
        |> andThen
            (\dims ->
                case dims of
                    0 ->
                        succeed []

                    1 ->
                        unsignedInt32 BE
                            |> skip (bytes 4)
                            |> andThen (\u -> list u dec)

                    _ ->
                        fail
            )


{-| Decode a two-dimensional array as a list of lists.

If parsing a resultset, use `array2Column` to take into account column length.

-}
array2 : Decoder a -> Decoder (List (List a))
array2 dec =
    unsignedInt32 BE
        |> skip (bytes 8)
        |> andThen
            (\dims ->
                case dims of
                    0 ->
                        succeed [ [] ]

                    2 ->
                        succeed Tuple.pair
                            |> read (unsignedInt32 BE)
                            |> skip (bytes 4)
                            |> read (unsignedInt32 BE)
                            |> skip (bytes 4)
                            |> andThen
                                (\( l1, l2 ) ->
                                    list l1 (list l2 dec)
                                )

                    _ ->
                        fail
            )


{-| Flattens an n-dimensional array into a list. If parsing a resultset, use `arrayColumn` to take into account column length and nulls.

    00000002 00000000 00000019 00000001 00000001 00000002 00000001 0000000f 494150484c20436f6d6d756e697479 00000006 2f24726f6f74
    int32 - number of dimensions
    int32 - flags ("has nulls" seems to be the only flag)
    int32 - element type oid

for each dimension:
int32 -- length (this is also the upper bound index in sql)
int32 -- lower bound index is only important for sql, not for elm

list of items as in a row (len is -1 if null)

    (len(int32) value) *

-}
arrayN : Decoder a -> Decoder (List a)
arrayN dec =
    let
        countDimensions : Int -> Decoder Int
        countDimensions ndims =
            list ndims
                (unsignedInt32 BE
                    |> skip (bytes 4)
                )
                |> map List.product
    in
    unsignedInt32 BE
        |> skip (bytes 8)
        |> andThen countDimensions
        |> andThen (\dims -> list dims dec)


cstringList : Decoder (List String)
cstringList =
    let
        step l =
            cstring
                |> andThen
                    (\str ->
                        succeed <|
                            if str == "" then
                                Done (List.reverse l)

                            else
                                Loop (str :: l)
                    )
    in
    loop [] step


cstring : Decoder String
cstring =
    let
        step str =
            Bytes.string 1
                |> andThen
                    (\char ->
                        succeed <|
                            if char /= "\u{0000}" then
                                Loop (char :: str)

                            else
                                Done (List.reverse str |> String.join "")
                    )
    in
    loop [] step



-- Column Value Decoders


{-| Decodes a binary integer where each bit is a flag and applies the function that converts
the integer to successive applications of Bool on the partially applied record constructor
we're decoding into.

For example:
select text, flag from table;

    type alias Rec =
        { name : String
        , enableNotifications : Bool
        , textOnly : Bool
        }

    d : Decoder Rec
    d =
        succeed Rec
            |> read string
            -- After applying the string to the Rec constructor, we have a partial constructor: Bool -> Bool -> Rec at this point.
            -- Expand flags takes the function that expects a function that takes such partially applied constructor applies
            -- the flag values to it in order
            |> expandFlags (\fn i -> fn (isFlagSet i 1) (isFlagSet i 2))

NOTE: When chaining decoders, we must use andThen to ensure the decoding of
previous columns already happened. Otherwise the decoding happens immediately
before the others had the chance to consume bytes in order.

-}
expandFlags : (a -> Int -> b) -> Decoder a -> Decoder b
expandFlags f prev =
    prev |> andThen (\p -> map (f p) int)


isFlagSet : Int -> Int -> Bool
isFlagSet flags pos =
    Bitwise.and flags pos > 0


trueIfNotZero : Int -> Bool
trueIfNotZero v =
    v > 0
