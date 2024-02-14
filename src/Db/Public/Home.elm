module Db.Public.Home exposing
    ( articlesByAuthor
    , articlesByAuthorPagingInfo
    , articlesByTagsAll
    , articlesByTagsAllPagingInfo
    , articlesByTime
    , articlesByTimePagingInfo
    , showArticle
    , tagsWithCounts
    )

import Db.Data exposing (Data(..), toDbData)
import Db.Endpoint
import Db.Types exposing (Article, ArticleAbstract, PagingInfo, TagWithCount, articleAbstractDecoder, articleDecoder, pagingInfoDecoder, tagWithCountDecoder)
import Postgres.Encode exposing (asInt, asText, asTextArray)
import Postgres.Http exposing (mQuery, mQuery1)


articlesByTime : (Data (List ArticleAbstract) -> a) -> { page : Int } -> Cmd a
articlesByTime toMsg { page } =
    mQuery
        Db.Endpoint.public
        "[l?k(caUA=h6n !E"
        [ asInt page ]
        (toDbData >> toMsg)
        articleAbstractDecoder


articlesByTimePagingInfo : (Data PagingInfo -> a) -> Cmd a
articlesByTimePagingInfo toMsg =
    mQuery1
        Db.Endpoint.public
        "@1@&#vMd0.OYYf^n"
        []
        (toDbData >> toMsg)
        pagingInfoDecoder


articlesByAuthor : (Data (List ArticleAbstract) -> a) -> { username : String, page : Int } -> Cmd a
articlesByAuthor toMsg { username, page } =
    mQuery
        Db.Endpoint.public
        "nth?n?aPrmBR&)<j"
        [ asText username, asInt page ]
        (toDbData >> toMsg)
        articleAbstractDecoder


articlesByAuthorPagingInfo : (Data PagingInfo -> a) -> { username : String } -> Cmd a
articlesByAuthorPagingInfo toMsg { username } =
    mQuery1
        Db.Endpoint.public
        "$$gpk-UZE]C`)z=8"
        [ asText username ]
        (toDbData >> toMsg)
        pagingInfoDecoder


articlesByTagsAll : (Data (List ArticleAbstract) -> a) -> { tags : List String, page : Int } -> Cmd a
articlesByTagsAll toMsg { tags, page } =
    mQuery
        Db.Endpoint.public
        "^O.Y!4>8.f%YYdv3"
        [ asTextArray tags, asInt page ]
        (toDbData >> toMsg)
        articleAbstractDecoder


articlesByTagsAllPagingInfo : (Data PagingInfo -> a) -> { tags : List String } -> Cmd a
articlesByTagsAllPagingInfo toMsg { tags } =
    mQuery1
        Db.Endpoint.public
        "[@o-za2On$ &ZH3L"
        [ asTextArray tags ]
        (toDbData >> toMsg)
        pagingInfoDecoder


tagsWithCounts : (Data (List TagWithCount) -> a) -> Cmd a
tagsWithCounts toMsg =
    mQuery
        Db.Endpoint.public
        "_S%MPr`>Y`iv[[zq"
        []
        (toDbData >> toMsg)
        tagWithCountDecoder


showArticle : (Data Article -> a) -> { slug : String } -> Cmd a
showArticle toMsg { slug } =
    mQuery1
        Db.Endpoint.public
        "@z=CFZkkDZdvWPwr"
        [ asText slug ]
        (toDbData >> toMsg)
        articleDecoder
