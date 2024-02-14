module Postgres.Types.Bigint exposing (Bigint, decoder, encoder, fromInt, toInt, toIntWithDefault, toString)

import Bytes exposing (Bytes, Endianness(..))
import Bytes.Decode as Decode exposing (Decoder, bytes, map2, unsignedInt32)
import Bytes.Encode as Encode exposing (Encoder)


type Bigint
    = Bigint Bytes


toInt : Bigint -> Maybe Int
toInt (Bigint b) =
    Decode.decode decodeInt b


decodeInt : Decoder Int
decodeInt =
    map2 (\h l -> h * 2 ^ 32 + l)
        (unsignedInt32 BE)
        (unsignedInt32 BE)


toIntWithDefault : Int -> Bigint -> Int
toIntWithDefault default b =
    Maybe.withDefault default (toInt b)


toString : Bigint -> String
toString b =
    String.fromInt (toIntWithDefault 0 b)


decoder : Decoder Bigint
decoder =
    Decode.map Bigint (bytes 8)


encoder : Bigint -> Encoder
encoder (Bigint b) =
    Encode.bytes b


fromInt : Int -> Bigint
fromInt i =
    Bigint (Encode.encode (Encode.sequence [ Encode.unsignedInt32 BE 0, Encode.unsignedInt32 BE i ]))
