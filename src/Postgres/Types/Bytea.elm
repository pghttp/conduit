module Postgres.Types.Bytea exposing (Bytea, decoder, encoder, length, toHex)

import Bytes exposing (Bytes)
import Bytes.Decode as Decode exposing (Decoder, bytes)
import Bytes.Encode as Encode exposing (Encoder)
import Hex.Convert


type Bytea
    = Bytea Bytes


decoder : Int -> Decoder Bytea
decoder len =
    Decode.map Bytea (bytes len)


toHex : Bytea -> String
toHex (Bytea b) =
    Hex.Convert.toString b


encoder : Bytea -> Encoder
encoder (Bytea b) =
    Encode.bytes b


length : Bytea -> Int
length (Bytea b) =
    Bytes.width b
