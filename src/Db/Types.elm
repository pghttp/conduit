module Db.Types exposing
    ( Article
    , ArticleAbstract
    , Author
    , AuthorProfile
    , PagingInfo
    , TagWithCount
    , articleAbstractDecoder
    , articleDecoder
    , authorProfileColumnDecoder
    , authorRecordDecoder
    , emptyPagingInfo
    , pagingInfoDecoder
    , tagWithCountDecoder
    )

import Bytes.Decode exposing (Decoder, bytes, succeed)
import Html exposing (s)
import Postgres.Decode exposing (arrayColumn, int, nullableString, read, skip, string)


type alias Author =
    { username : String
    , image : Maybe String
    }


authorRecordDecoder : Decoder Author
authorRecordDecoder =
    -- columns of type `record` have an extra type oid before each value,
    -- hence we skip 8+4 bytes before reading the first value, and 4 bytes before each subsequent value
    succeed Author
        |> skip (bytes 12)
        |> read string
        |> skip (bytes 4)
        |> read nullableString



-- slug            text,
-- title           text,
-- abstract        text,
-- tags            text[],
-- updated_at      timestamp,
-- favorites_count int,
-- author          record


type alias ArticleAbstract =
    { slug : String
    , title : String
    , abstract : String
    , tags : List String
    , lastUpdate : String
    , favorites : Int
    , author : Author
    }


articleAbstractDecoder : Decoder ArticleAbstract
articleAbstractDecoder =
    succeed ArticleAbstract
        |> read string
        |> read string
        |> read string
        |> read (arrayColumn string)
        |> read string
        |> read int
        |> read authorRecordDecoder



---


type alias PagingInfo =
    { itemCount : Int
    , pageSize : Int
    , pageCount : Int
    }


emptyPagingInfo : PagingInfo
emptyPagingInfo =
    PagingInfo 0 0 0


pagingInfoDecoder : Decoder PagingInfo
pagingInfoDecoder =
    succeed PagingInfo
        |> read int
        |> read int
        |> read int


type alias TagWithCount =
    { name : String
    , count : Int
    }


tagWithCountDecoder : Decoder TagWithCount
tagWithCountDecoder =
    succeed TagWithCount
        |> read string
        |> read int


type alias AuthorProfile =
    { username : String
    , bio : Maybe String
    , image : Maybe String
    , followedBy : Int
    }


authorProfileColumnDecoder : Decoder AuthorProfile
authorProfileColumnDecoder =
    succeed AuthorProfile
        -- custom types have an extra type oid before each value,
        -- hence we skip 8+4 bytes before reading the first value, and 4 bytes before each subsequent value
        |> skip (bytes 12)
        |> read string
        |> skip (bytes 4)
        |> read nullableString
        |> skip (bytes 4)
        |> read nullableString
        |> skip (bytes 4)
        |> read int


type alias Article =
    { slug : String
    , title : String
    , description : String
    , body : String
    , tags : List String
    , updatedAt : String
    , favoritesCount : Int
    , author : AuthorProfile
    }


articleDecoder : Decoder Article
articleDecoder =
    succeed Article
        |> read string
        |> read string
        |> read string
        |> read string
        |> read (arrayColumn string)
        |> read string
        |> read int
        |> read authorProfileColumnDecoder
