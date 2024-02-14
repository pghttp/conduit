module Db.Data exposing
    ( Data(..)
    , Error(..)
    , errorToString
    , toDbData
    )

import Postgres.Http exposing (PgError, pgErrorToString)


type Data a
    = Loading
    | Failure Error
    | Success a


type Error
    = Error String
    | DataError (List (List ( Int, Maybe String )))
    | NoData
    | Unauthorized


errorToString : Error -> String
errorToString e =
    case e of
        Error s ->
            s

        DataError _ ->
            "Failed to decode one or more rows"

        NoData ->
            "No data"

        Unauthorized ->
            "Unauthorized"


fromResult : Result Error a -> Data a
fromResult result =
    case result of
        Err e ->
            Failure e

        Ok x ->
            Success x


toDbData : Result PgError a -> Data a
toDbData =
    Result.mapError pgErrorToError >> fromResult


pgErrorToError : PgError -> Error
pgErrorToError e =
    case e of
        Postgres.Http.Unauthorized _ ->
            Unauthorized

        Postgres.Http.NoData ->
            NoData

        Postgres.Http.BadDecode l ->
            DataError l

        _ ->
            Error (pgErrorToString e)
