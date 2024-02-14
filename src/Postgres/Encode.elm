module Postgres.Encode exposing
    ( Param
    , Uuid
    , asBigint
    , asBool
    , asBytea
    , asInt
    , asInt32
    , asNullableText
    , asText
    , asTextArray
    , describe
    , describeStatementEncoder
    , encodeParams
    , exec
    , query
    , queryStringEncoder
    , uuid
    )

import Bytes exposing (Bytes, Endianness(..))
import Bytes.Encode exposing (Encoder, encode, getStringWidth, sequence, signedInt32, string, unsignedInt16, unsignedInt32, unsignedInt8)
import Postgres.Types.Bigint as Bigint exposing (Bigint)
import Postgres.Types.Bytea as Bytea exposing (Bytea)



-- Public API


exec : String -> Int -> List Param -> List Int -> Bytes
exec q numcols params columnFormats =
    encode (execEncoder q numcols params columnFormats)


describe : String -> Bytes
describe q =
    encode (describeStatementEncoder q)


query : String -> Bytes
query q =
    encode (queryStringEncoder q)


type Param
    = Text String
    | IntAsText Int
    | TextArray (List String)
    | NullableText (Maybe String)
    | Boolean Bool
    | Bigint Bigint
    | Bytea Bytea
    | Int Int


type alias Uuid =
    String


asText : String -> Param
asText s =
    Text s


uuid : Uuid -> Param
uuid id =
    Text id


asNullableText : Maybe String -> Param
asNullableText s =
    NullableText s


asInt32 : Int -> Param
asInt32 i =
    IntAsText i


asTextArray : List String -> Param
asTextArray l =
    TextArray l


asBool : Bool -> Param
asBool b =
    Boolean b


asBigint : Bigint -> Param
asBigint b =
    Bigint b


asBytea : Bytea -> Param
asBytea b =
    Bytea b


asInt : Int -> Param
asInt i =
    Int i



-- Test API


queryStringEncoder : String -> Encoder
queryStringEncoder s =
    sequence [ string "Q", unsignedInt32 BE (getStringWidth s + 5), string s, unsignedInt8 0 ]



-- Private


execEncoder : String -> Int -> List Param -> List Int -> Encoder
execEncoder s numcols params columnFormats =
    sequence <|
        [ msgParse s Nothing
        , msgBind numcols params columnFormats
        , msgExec 0
        , msgSync
        ]


msgParse : String -> Maybe String -> Encoder
msgParse q statementName =
    let
        ( encodedName, nameLen ) =
            encodeStatementName statementName
    in
    sequence
        [ string "P"
        , unsignedInt32 BE (getStringWidth q + nameLen + 8)
        , encodedName
        , string q
        , unsignedInt8 0
        , unsignedInt16 BE 0
        ]


encodeStatementName : Maybe String -> ( Encoder, Int )
encodeStatementName statementName =
    case statementName of
        Just n ->
            ( sequence [ string n, unsignedInt8 0 ], getStringWidth n )

        Nothing ->
            ( unsignedInt8 0, 0 )


msgBind : Int -> List Param -> List Int -> Encoder
msgBind numcols params formats =
    let
        ( paramLen, encodedParams ) =
            encodeParams params
    in
    sequence
        [ string "B"
        , unsignedInt32 BE (12 + paramLen + numcols * 2)

        -- portal name
        , unsignedInt8 0

        -- statement name
        , unsignedInt8 0

        -- num parameter formats
        , unsignedInt16 BE 0

        -- params
        , encodedParams

        -- numresults
        , unsignedInt16 BE numcols
        , outputColumnFormats formats numcols
        ]


encodeParams : List Param -> ( Int, Encoder )
encodeParams paramList =
    -- map each param into an encoder
    let
        paramsCount =
            unsignedInt16 BE (List.length paramList)

        encodeString s =
            ( 4 + getStringWidth s, sequence [ unsignedInt32 BE (getStringWidth s), string s ] )

        encodeNull =
            ( 4, sequence [ unsignedInt32 BE -1 ] )

        zeroIfNotTrue b =
            if b then
                1

            else
                0

        pe param =
            case param of
                Text s ->
                    encodeString s

                NullableText ns ->
                    case ns of
                        Nothing ->
                            encodeNull

                        Just s ->
                            encodeString s

                IntAsText p ->
                    String.fromInt p |> encodeString

                TextArray l ->
                    encodeAsArray l

                Boolean b ->
                    ( 5, sequence [ unsignedInt32 BE 1, unsignedInt8 (zeroIfNotTrue b) ] )

                Bigint b ->
                    ( 12, sequence [ unsignedInt32 BE 8, Bigint.encoder b ] )

                Bytea b ->
                    ( 4 + Bytea.length b, sequence [ unsignedInt32 BE (Bytea.length b), Bytea.encoder b ] )

                Int i ->
                    ( 8, sequence [ unsignedInt32 BE 4, signedInt32 BE i ] )
    in
    -- An M message is: 'M'..in32(length including self)..{16-byte opaque msg_id}..int16(num_params)..({ int32(param_len)..{param_val}, ...} x num_params)
    -- This gets converted into a P/B/E/S message on http_proxy side. Important to note that parameter format (text or binary)
    -- is determined in the M-message database (api.operations table) and not here during encoding.
    List.map pe paramList |> List.unzip |> Tuple.mapBoth List.sum (\l -> sequence (paramsCount :: l))


{-| Encode a list of strings as a one-dimensional array

    int32 - 1
    int32 - flags ("has nulls" seems to be the only flag)
    int32 - element type oid
    int32 --upper bound
    int32 --lower bound

list of items as in a row (len is -1 if null)

    (ub - lb + 1) * ( int32 value, payload )

-}
encodeAsArray : List String -> ( Int, Encoder )
encodeAsArray params =
    let
        len =
            List.map (\p -> 4 + getStringWidth p) params |> List.sum |> (+) 20
    in
    ( len + 4
    , sequence
        -- Since an M message is int32(param_len) | param_val we encode the length as part of the sequence
        [ unsignedInt32 BE len
        , unsignedInt32 BE 1
        , unsignedInt32 BE 0
        , unsignedInt32 BE 25 --(typeToOid Text)
        , unsignedInt32 BE (List.length params)
        , unsignedInt32 BE 1
        , sequence (List.map (\p -> sequence [ unsignedInt32 BE (getStringWidth p), string p ]) params)
        ]
    )


msgExec : Int -> Encoder
msgExec numrows =
    sequence
        [ string "E"
        , unsignedInt32 BE 9
        , unsignedInt8 0
        , unsignedInt32 BE numrows
        ]


msgSync : Encoder
msgSync =
    sequence [ string "S", unsignedInt32 BE 4 ]


msgDescribe : Maybe String -> Encoder
msgDescribe statementName =
    let
        ( encodedName, nameLen ) =
            encodeStatementName statementName
    in
    sequence
        [ string "D", unsignedInt32 BE (nameLen + 6), string "S", encodedName ]


outputColumnFormats : List Int -> Int -> Encoder
outputColumnFormats outputFormats numcols =
    let
        fmts =
            List.length outputFormats

        fmtlist =
            if fmts < numcols then
                outputFormats ++ List.repeat (numcols - fmts) 0

            else if fmts == numcols then
                outputFormats

            else
                List.take numcols outputFormats
    in
    sequence <| List.map (unsignedInt16 BE) fmtlist


describeStatementEncoder : String -> Encoder
describeStatementEncoder q =
    sequence
        [ msgParse q Nothing
        , msgDescribe Nothing
        , msgSync
        ]
