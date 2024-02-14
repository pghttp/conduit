module Main exposing (main)

import Browser
import Browser.Navigation
import Db.Data as Data exposing (Data(..), errorToString)
import Db.Public.Home as Db
import Db.Types exposing (Article, ArticleAbstract, PagingInfo, TagWithCount)
import Html exposing (Html, a, div, footer, h3, header, li, main_, p, text)
import Html.Attributes exposing (class, href, style)
import Html.Events exposing (onClick)
import Url exposing (Url)


type alias Model =
    { page : Page
    , articles : List ArticleAbstract
    , pagingInfo : Data PagingInfo
    , error : Maybe String
    , currentPage : Int
    , listMode : ListMode
    , tags : List TagWithCount
    }


type Msg
    = UrlChanged Url
    | LinkClicked Browser.UrlRequest
    | GotArticles (Data (List ArticleAbstract))
    | GotArticlesPagingInfo (Data PagingInfo)
    | GotTagsWithCounts (Data (List TagWithCount))
    | PageRequested Int
    | ArticleSelected String
    | GotArticle (Data Article)
    | NavigatedToHome
    | TagSelected String
    | TagCleared


type ListMode
    = ByTime
    | ByTags (List String)
    | ByAuthor String


type Page
    = Home
    | Article Article


init : () -> Url.Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init _ _ _ =
    let
        listMode =
            ByTime
    in
    ( { page = Home
      , articles = []
      , error = Nothing
      , pagingInfo = Loading
      , currentPage = 1
      , listMode = listMode
      , tags = []
      }
    , Cmd.batch
        [ pagingByMode listMode
        , listByMode listMode 1
        , Db.tagsWithCounts GotTagsWithCounts
        ]
    )


listByMode : ListMode -> Int -> Cmd Msg
listByMode listMode page =
    case listMode of
        ByTime ->
            Db.articlesByTime GotArticles { page = page }

        ByTags tags ->
            Db.articlesByTagsAll GotArticles { tags = tags, page = page }

        ByAuthor username ->
            Db.articlesByAuthor GotArticles { username = username, page = page }


pagingByMode : ListMode -> Cmd Msg
pagingByMode listMode =
    case listMode of
        ByTime ->
            Db.articlesByTimePagingInfo GotArticlesPagingInfo

        ByTags tags ->
            Db.articlesByTagsAllPagingInfo GotArticlesPagingInfo { tags = tags }

        ByAuthor username ->
            Db.articlesByAuthorPagingInfo GotArticlesPagingInfo { username = username }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        noop =
            ( model, Cmd.none )
    in
    case msg of
        UrlChanged _ ->
            noop

        LinkClicked _ ->
            noop

        GotArticles data ->
            case data of
                Data.Success articles ->
                    ( { model | articles = articles }
                    , Cmd.none
                    )

                Data.Failure error ->
                    ( { model | error = Just <| "Oh no! There was an error: " ++ errorToString error }
                    , Cmd.none
                    )

                Data.Loading ->
                    noop

        GotArticlesPagingInfo pi ->
            ( { model | pagingInfo = pi }
            , Cmd.none
            )

        GotTagsWithCounts data ->
            case data of
                Data.Success tagsWithCounts ->
                    ( { model | tags = tagsWithCounts }, Cmd.none )

                Data.Failure error ->
                    ( { model | error = Just <| "Oh no! There was an error: " ++ errorToString error }
                    , Cmd.none
                    )

                Data.Loading ->
                    noop

        PageRequested page ->
            ( { model | currentPage = page }
            , listByMode model.listMode page
            )

        ArticleSelected slug ->
            ( model, Db.showArticle GotArticle { slug = slug } )

        GotArticle data ->
            case data of
                Data.Success article ->
                    ( { model | page = Article article }
                    , Cmd.none
                    )

                Data.Failure error ->
                    ( { model | error = Just <| "Oh no! There was an error: " ++ errorToString error }
                    , Cmd.none
                    )

                Data.Loading ->
                    noop

        NavigatedToHome ->
            ( { model | page = Home }
            , Cmd.none
            )

        TagSelected tag ->
            ( { model | listMode = ByTags [ tag ] }
            , listByMode (ByTags [ tag ]) 1
            )

        TagCleared ->
            ( { model | listMode = ByTime }
            , listByMode ByTime 1
            )


view : Model -> Browser.Document Msg
view model =
    { title = "Hello World"
    , body =
        [ main_ [ class "container" ]
            (case model.page of
                Home ->
                    [ homeView model
                    ]

                Article a ->
                    [ articlePage a
                    ]
            )
        , footer [] [ text "Pg Vox is a sample app demonstrating the use of elm-pghttp." ]
        ]
    }


homeView : Model -> Html Msg
homeView model =
    case model.articles of
        [] ->
            case model.error of
                Just error ->
                    text error

                Nothing ->
                    text "Loading..."

        _ ->
            div []
                [ header [] [ tagBar model.tags model.listMode ]
                , articleList model.articles
                , pager model.pagingInfo model.currentPage
                ]


articleList : List ArticleAbstract -> Html Msg
articleList articles =
    List.map articleAbstract articles
        |> Html.section []


articleAbstract : ArticleAbstract -> Html Msg
articleAbstract article =
    Html.article []
        [ h3 [] [ a [ href "#", onClick (ArticleSelected article.slug) ] [ text article.title ] ]
        , p [] [ text article.abstract ]
        , p [] [ text <| "By " ++ article.author.username ]
        ]


pager : Data PagingInfo -> Int -> Html Msg
pager pagingInfo currentPage =
    case pagingInfo of
        Loading ->
            text "Loading..."

        Data.Success pi ->
            pagerView pi currentPage

        Data.Failure error ->
            text <| "Oh no! There was an error: " ++ errorToString error


pagerView : PagingInfo -> Int -> Html Msg
pagerView pagingInfo currentPage =
    List.range 1 pagingInfo.pageCount
        |> List.map
            (\i ->
                if i == currentPage then
                    a [] [ text <| String.fromInt i ]

                else
                    a [ href "#", onClick (PageRequested i) ] [ text <| String.fromInt i ]
            )
        |> Html.div [ class "horizontal" ]


tagBar : List TagWithCount -> ListMode -> Html Msg
tagBar tags lm =
    -- If we're in ByTags mode, we want to show a "clear" button next to the active tag
    -- We need to extract the active tag, and then compare against each tag as we map
    let
        activeTag =
            case lm of
                ByTags [ t ] ->
                    Just t

                _ ->
                    Nothing

        st tag =
            a [ href "#", onClick (TagSelected tag.name) ] [ text <| tag.name ++ " (" ++ String.fromInt tag.count ++ ")" ]

        selectableTag tag =
            case activeTag of
                Just active ->
                    if active == tag.name then
                        a [ href "#", onClick TagCleared ] [ text <| tag.name ++ " (" ++ String.fromInt tag.count ++ ") ⓧ" ]

                    else
                        st tag

                Nothing ->
                    st tag
    in
    List.map
        (\tag ->
            div [] [ selectableTag tag ]
        )
        tags
        |> div [ class "tag-bar horizontal" ]


articlePage : Article -> Html Msg
articlePage article =
    div []
        [ header [] [ div [ class "horizontal" ] [ a [ href "#", onClick NavigatedToHome ] [ text "< Back" ] ] ]
        , h3 [] [ text article.title ]
        , p [] [ text article.description ]
        , p [] [ text <| "By " ++ article.author.username ]
        , div [ style "white-space" "pre-wrap" ] [ text article.body ]
        ]


main : Program () Model Msg
main =
    Browser.application
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
