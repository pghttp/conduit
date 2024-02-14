module Postgres.Types.Timestamp exposing (timestamp, tscolumn, tsrange, tsrangeColumn)

import Bytes exposing (Endianness(..))
import Bytes.Decode exposing (Decoder, andThen, bytes, map, map2, unsignedInt32)
import Postgres.Types.Range exposing (range, toTuple)
import Time exposing (Posix, millisToPosix)


tscolumn : Decoder Posix
tscolumn =
    unsignedInt32 BE
        |> andThen (always timestamp)


timestamp : Decoder Posix
timestamp =
    map2 (\h l -> h * 2 ^ 32 + l |> pgTsToPosix)
        (unsignedInt32 BE)
        (unsignedInt32 BE)


pgTsToPosix : Int -> Posix
pgTsToPosix ts =
    -- Integer division fails for large integers, so we convert to float first
    round (toFloat ts / 1000) + 946684800000 |> millisToPosix


tsrange : Decoder ( Maybe Posix, Maybe Posix )
tsrange =
    map toTuple (range tscolumn)


tsrangeColumn : Decoder ( Maybe Posix, Maybe Posix )
tsrangeColumn =
    bytes 4
        |> andThen (\_ -> tsrange)
