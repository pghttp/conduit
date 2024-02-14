module Postgres.Http exposing
    ( Endpoint
    , LoginToken
    , PgError(..)
    , authenticateQuery
    , dbHeader
    , expectPostgresRows
    , mQuery
    , mQuery1
    , mVoidQuery
    , pgErrorToString
    )

import Bytes exposing (Bytes, Endianness(..))
import Bytes.Decode as Bytes exposing (Decoder, Step(..), andThen, fail, loop, map, map2, map3, string, succeed, unsignedInt16, unsignedInt32)
import Bytes.Encode as E exposing (encode)
import Http exposing (bytesBody)
import Postgres.Encode exposing (Param, encodeParams)
import Postgres.Http.Error exposing (ErrorMessage, decodeError)


type PgError
    = ConnectionError String
    | Unauthorized ErrorMessage
    | BadUrl String
    | BadRequest ErrorMessage
    | ServerError ErrorMessage
    | BadDecode (List (List ( Int, Maybe String )))
    | NoData


type alias LoginToken =
    { cookie : String
    , date : String
    , sig : String
    }


type alias Endpoint =
    { url : String
    , token : Maybe LoginToken
    }


pgErrorToString : PgError -> String
pgErrorToString error =
    case error of
        ConnectionError err ->
            "Could not connect to the host: " ++ err

        BadUrl url ->
            "Invalid host url: " ++ url

        BadRequest e ->
            .severity e ++ ": " ++ .message e

        ServerError e ->
            .severity e ++ ": " ++ .message e

        Unauthorized e ->
            "Unauthorized: " ++ .message e

        NoData ->
            "Query returned no data"

        BadDecode l ->
            String.join "\n" (List.map badDecodeRowToString l)


badDecodeRowToString : List ( Int, Maybe String ) -> String
badDecodeRowToString l =
    List.indexedMap (\i ( len, h ) -> String.fromInt i ++ ":" ++ shorten len h) l
        |> String.join ", "
        |> (\r -> "[" ++ r ++ "]")


shorten : Int -> Maybe String -> String
shorten len s =
    case s of
        Nothing ->
            "NULL           "

        Just hex ->
            if String.length hex < len * 2 then
                hex

            else
                String.padLeft 5 ' ' (String.fromInt len) ++ ":" ++ String.left 4 hex ++ "..."



-- HTTP Helpers


loginHeaders : Maybe LoginToken -> List Http.Header
loginHeaders t =
    case t of
        Just tok ->
            [ Http.header "Authorization" ("Bearer " ++ tok.cookie ++ "|" ++ tok.date ++ "|" ++ tok.sig) ]

        Nothing ->
            []


queryVerb : String
queryVerb =
    --nodejs cannot handle custom verbs ("QUERY")
    "POST"


authenticateQuery : { c | endpointUrl : String, database : String, user : String } -> String -> (Result PgError Bool -> msg) -> Cmd msg
authenticateQuery conn authResponse toMsg =
    Http.riskyRequest
        { method = "AUTHENTICATE"
        , headers = authHeader authResponse ++ userHeader conn.user
        , url = conn.endpointUrl
        , body = Http.emptyBody
        , expect = expectYesOrNo toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


mVoidQuery : Endpoint -> String -> List Param -> (Result PgError Bool -> msg) -> Cmd msg
mVoidQuery { url, token } msgNum params toMsg =
    Http.riskyRequest
        { method = queryVerb
        , headers = Http.header "Accept" "postgres/rows" :: loginHeaders token
        , url = url
        , body = bytesBody "postgres/message" <| encodeMessage msgNum params
        , expect = expectYesOrNo toMsg
        , timeout = Nothing
        , tracker = Nothing
        }


mQuery : Endpoint -> String -> List Param -> (Result PgError (List a) -> msg) -> Decoder a -> Cmd msg
mQuery { url, token } msgNum params toMsg decoder =
    Http.riskyRequest
        { method = queryVerb
        , headers = Http.header "Accept" "postgres/rows" :: loginHeaders token
        , url = url
        , body = bytesBody "postgres/message" <| encodeMessage msgNum params
        , expect = expectPostgresRows toMsg decoder
        , timeout = Nothing
        , tracker = Nothing
        }


mQuery1 : Endpoint -> String -> List Param -> (Result PgError a -> msg) -> Decoder a -> Cmd msg
mQuery1 endpoint msgNum params toMsg decoder =
    mQuery endpoint msgNum params (getFirst >> toMsg) decoder


getFirst : Result PgError (List a) -> Result PgError a
getFirst r =
    case r of
        Ok l ->
            case List.head l of
                Just d ->
                    Ok d

                _ ->
                    Err <| NoData

        Err e ->
            Err e


expectPostgresRows : (Result PgError (List a) -> msg) -> Decoder a -> Http.Expect msg
expectPostgresRows toMsg rowDecoder =
    let
        bodyDecoder b =
            case Bytes.decode (decodeRows (Bytes.width b) rowDecoder) b of
                Just v ->
                    Ok v

                Nothing ->
                    Err (BadDecode [])
    in
    expectServerResponse toMsg bodyDecoder


expectYesOrNo : (Result PgError Bool -> msg) -> Http.Expect msg
expectYesOrNo toMsg =
    expectServerResponse toMsg (always <| Ok True)


expectServerResponse : (Result PgError a -> msg) -> (Bytes -> Result PgError a) -> Http.Expect msg
expectServerResponse toMsg decodingFn =
    Http.expectBytesResponse toMsg (decodePostgresResponse decodingFn)


decodePostgresResponse : (Bytes -> Result PgError a) -> Http.Response Bytes -> Result PgError a
decodePostgresResponse decodingFn response =
    case response of
        Http.BadUrl_ url ->
            Err <| BadUrl url

        Http.Timeout_ ->
            Err <| ConnectionError "Server unreachable (connection timed out)"

        Http.NetworkError_ ->
            Err <| ConnectionError "A network error occurred"

        Http.BadStatus_ metadata body ->
            Err <|
                case metadata.statusCode of
                    401 ->
                        Unauthorized <| Maybe.withDefault unknownError (decodeError body)

                    422 ->
                        BadRequest <| Maybe.withDefault unknownError (decodeError body)

                    _ ->
                        BadRequest unknownError

        Http.GoodStatus_ _ body ->
            decodingFn body


decodeRows : Int -> Decoder a -> Decoder (List a)
decodeRows w decoder =
    let
        step dec ( msgs, remain ) =
            if remain <= 0 then
                succeed (Done <| List.reverse msgs)

            else
                -- Read the tag and byte length, ignore column count as the decoder already knows how
                -- many columns it wants to read
                map3 (\tag l _ -> Tuple.pair tag l) (string 1) (unsignedInt32 BE) (unsignedInt16 BE)
                    |> andThen
                        (\( tag, len ) ->
                            case tag of
                                "D" ->
                                    -- Length includes self but does not include tag byte
                                    map (\msg -> Loop ( msg :: msgs, remain - len - 1 )) dec

                                _ ->
                                    fail
                        )
    in
    loop ( [], w ) (step decoder)


unknownError : ErrorMessage
unknownError =
    ErrorMessage "ERROR" "0" "Unknown error" []


dbHeader : String -> List Http.Header
dbHeader dbname =
    (List.singleton << Http.header "pg-database") dbname


userHeader : String -> List Http.Header
userHeader user =
    (List.singleton << Http.header "pg-user") user


authHeader : String -> List Http.Header
authHeader authResponse =
    (List.singleton << Http.header "Authorization") authResponse



-- Encode


encodeMessage : String -> List Param -> Bytes
encodeMessage funcNum params =
    let
        ( paramLen, encodedParams ) =
            encodeParams params
    in
    encode <|
        E.sequence
            [ E.string "M"
            , E.unsignedInt32 BE (22 + paramLen)
            , E.string funcNum
            , encodedParams
            ]
