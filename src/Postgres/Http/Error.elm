module Postgres.Http.Error exposing (decodeError, ErrorMessage)

import Bytes exposing (Bytes, Endianness(..))
import Bytes.Decode as Bytes exposing (Decoder, map3, unsignedInt32)
import Postgres.Decode exposing (cstringList)




type alias ErrorMessage =
    { severity : String
    , code : String
    , message : String
    , details : List ( String, String )
    }

-- Error packet

decodeError : Bytes -> Maybe ErrorMessage
decodeError b =
    Bytes.decode errorDecoder b |> Maybe.map makeError


errorDecoder : Decoder (List String)
errorDecoder =
    map3 (\_ _ msgs -> msgs) (Bytes.string 1) (unsignedInt32 BE) cstringList


makeError : List String -> ErrorMessage
makeError =
    List.map (\s -> ( String.left 1 s, String.dropLeft 1 s ))
        >> List.partition (\( t, _ ) -> t == "S" || t == "V")
        >> Tuple.mapBoth nonLocalizedSeverity (List.partition (\( t, _ ) -> t == "C" || t == "M"))
        >> (\( severity, ( cm, details ) ) -> ErrorMessage severity (tagValue "C" cm) (tagValue "M" cm) (List.map (Tuple.mapFirst errorLabel) details))


nonLocalizedSeverity : List ( String, String ) -> String
nonLocalizedSeverity l =
    List.foldl
        (\( t, s ) sev ->
            if sev == "" then
                s

            else if t == "V" then
                s

            else
                sev
        )
        ""
        l


tagValue : String -> List ( String, String ) -> String
tagValue tag =
    List.foldl
        (\( t, s ) acc ->
            if t == tag then
                s

            else
                acc
        )
        ""


errorLabel : String -> String
errorLabel tag =
    case tag of
        "S" ->
            "Severity"

        "V" ->
            "Severity"

        "C" ->
            "Code"

        "M" ->
            "Message"

        "D" ->
            "Detail"

        "H" ->
            "Hint"

        "P" ->
            "Position"

        "p" ->
            "Internal position"

        "q" ->
            "Internal query"

        "W" ->
            "Where"

        "s" ->
            "Schema"

        "t" ->
            "Table"

        "c" ->
            "Column"

        "d" ->
            "Data type name"

        "n" ->
            "Constraint"

        "F" ->
            "File"

        "L" ->
            "Line"

        "R" ->
            "Routine"

        _ ->
            "Text"
