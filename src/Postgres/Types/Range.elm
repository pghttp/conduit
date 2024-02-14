module Postgres.Types.Range exposing (Range, range, rangeColumn, toTuple)

import Bytes exposing (Endianness(..))
import Bytes.Decode as Decode exposing (Decoder, andThen, map, map2, unsignedInt32, unsignedInt8)


toTuple : Range a -> ( Maybe a, Maybe a )
toTuple r =
    case r of
        SingleLower (Exclusive l) ->
            ( Just l, Nothing )

        SingleLower (Inclusive l) ->
            ( Just l, Nothing )

        SingleUpper (Exclusive u) ->
            ( Nothing, Just u )

        SingleUpper (Inclusive u) ->
            ( Nothing, Just u )

        Range (Exclusive l) (Exclusive u) ->
            ( Just l, Just u )

        Range (Inclusive l) (Exclusive u) ->
            ( Just l, Just u )

        Range (Exclusive l) (Inclusive u) ->
            ( Just l, Just u )

        Range (Inclusive l) (Inclusive u) ->
            ( Just l, Just u )

        _ ->
            ( Nothing, Nothing )



{-

   A full range consists of a header byte, followed by 2 timestamps, each having a length prefix 4 bytes and then 8 bytes of value.

         06 00000008 0002A66254046000 00000008 0002A66254046000

   An empty range only has a header byte:

         01 -- empty range that has equal bottom and top value
         18 -- range with both elements null/infinite

   A range can also have only one entry, the other being infinite/null:

         12 00000008 0002A66254046000

   Flags (from postgres source, rangetypes.h):

         /* A range's flags byte contains these bits: */
         #define RANGE_EMPTY         0x01    /* range is empty */
         #define RANGE_LB_INC        0x02    /* lower bound is inclusive */
         #define RANGE_UB_INC        0x04    /* upper bound is inclusive */
         #define RANGE_LB_INF        0x08    /* lower bound is -infinity */
         #define RANGE_UB_INF        0x10    /* upper bound is +infinity */

   Possible flag values in decimal:

    0 - both values exclusive (2 values)
    1 - empty range (no values)
    2 - both values, lower bound inclusive (2 values)
    4 - both values, upper bound inclusive (2 values)
    6 - both values inclusive (2 values)
    8 - lower bound infinite, upper bound exclusive (1 value)
   12 - lower bound infinite, upper bound inclusive (1 value)
   16 - lower bound exclusive, upper bound infinite (1 value)
   18 - lower bound inclusive, upper bound infinite (1 value)
   24 - both bounds infinite (no values)

-}


type RangeBoundary a
    = Infinite
    | Inclusive a
    | Exclusive a


type Range a
    = EmptyRange
    | SingleLower (RangeBoundary a)
    | SingleUpper (RangeBoundary a)
    | Range (RangeBoundary a) (RangeBoundary a)


range : Decoder a -> Decoder (Range a)
range decoder =
    unsignedInt8
        |> andThen
            (\f ->
                case f of
                    -- Match all cases of possible flag values in decimal and return a tuple decoder:
                    0 ->
                        map2 (\l u -> Range (Exclusive l) (Exclusive u)) decoder decoder

                    1 ->
                        Decode.succeed EmptyRange

                    2 ->
                        map2 (\l u -> Range (Inclusive l) (Exclusive u)) decoder decoder

                    4 ->
                        map2 (\l u -> Range (Exclusive l) (Inclusive u)) decoder decoder

                    6 ->
                        map2 (\l u -> Range (Inclusive l) (Inclusive u)) decoder decoder

                    8 ->
                        map (\u -> SingleUpper (Exclusive u)) decoder

                    12 ->
                        map (\u -> SingleUpper (Inclusive u)) decoder

                    16 ->
                        map (\l -> SingleLower (Exclusive l)) decoder

                    18 ->
                        map (\l -> SingleLower (Inclusive l)) decoder

                    24 ->
                        Decode.succeed EmptyRange

                    _ ->
                        -- Decode.fail
                        Decode.succeed EmptyRange
            )


rangeColumn : Decoder a -> Decoder (Range a)
rangeColumn decoder =
    Decode.andThen
        (\len ->
            if len == -1 then
                Decode.succeed EmptyRange

            else
                range decoder
        )
        (unsignedInt32 BE)
