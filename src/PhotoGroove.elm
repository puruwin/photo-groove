module PhotoGroove exposing (main)       -- Declara un nuevo modulo

import Html exposing (..)                -- Importa otros modulos
import Html.Attributes as Attr exposing (class, id, src, title, classList, type_, name, max)
import Html.Events exposing (onClick)
import Browser
import Array exposing (Array)
import Http
import Json.Decode exposing (Decoder, int, list, string, succeed)
import Json.Decode.Pipeline exposing (optional, required)
import Json.Encode as Encode
import Random

urlPrefix : String
urlPrefix =
    "http://elm-in-action.com/"

initialCmd : Cmd Msg
initialCmd =
    Http.get
        { url = "http://elm-in-action.com/photos/list.json"
        , expect = Http.expectJson GotPhotos (list photoDecoder)
        }

photoDecoder : Decoder Photo
photoDecoder =
    succeed Photo
        |> required "url" string
        |> required "size" int
        |> optional "title" string "(untitled)"

type Msg 
    = ClickedPhoto String
    | GotRandomPhoto Photo
    | ClickedSize ThumbnailSize
    | ClickedSupriseMe
    | GotPhotos (Result Http.Error (List Photo))

view : Model -> Html Msg
view model =
    div [ class "content" ] <|
        case model.status of
            Loaded photos selectedUrl ->
                viewLoaded photos selectedUrl model.chosenSize
            Loading ->
                []
            Errored errorMessage ->
                [ text ("Error: " ++ errorMessage) ]

viewFilter : String -> Int -> Html Msg
viewFilter name magnitude =
    div [ class "filter-slider" ]
        [ label [] [ text name ]
        , rangeSlider
            [ Attr.max "11"
            , Attr.property "val" (Encode.int magnitude)
            ]
            []
        , label [] [ text (String.fromInt magnitude) ]
        ]

viewLoaded : List Photo -> String -> ThumbnailSize -> List (Html Msg)
viewLoaded photos selectedUrl chosenSize =
    [ h1 [] [ text "Photo Groove" ]
        , button
            [ onClick ClickedSupriseMe ]
            [ text "Surprise Me!" ]
        , div [ class "filters" ]
            [ viewFilter "Hue" 0
            , viewFilter "Ripple" 0
            , viewFilter "Noise" 0
            ]
        , h3 [] [ text "Thumbnail Size:" ]
        , div [ id "choose-size" ]
            (List.map viewSizeChooser [ Small, Medium, Large ])
        , div [ id "thumbnails", class (sizeToString chosenSize) ] 
            (List.map 
                (viewThumbnail selectedUrl)
                photos
            )
        , img
            [ class "large"
            , src (urlPrefix ++ "large/" ++ selectedUrl)
            ]
            []
        ]

viewThumbnail : String -> Photo -> Html Msg
viewThumbnail selectedUrl thumb =
    img
        [ src (urlPrefix ++ thumb.url)
        , title (thumb.title ++ " [" ++ String.fromInt thumb.size ++ " KB]")
        , classList [ ( "selected", selectedUrl == thumb.url) ]
        , onClick (ClickedPhoto thumb.url)
        ]
        []

viewSizeChooser : ThumbnailSize -> Html Msg
viewSizeChooser size =
    label []
        [ input [ type_ "radio", name "size", onClick (ClickedSize size) ] []
        , text (sizeToString size)
        ]

sizeToString : ThumbnailSize -> String
sizeToString size =
    case size of
        Small ->
            "small"
        Medium ->
            "med"
        Large ->
            "large"

type ThumbnailSize
    = Small
    | Medium
    | Large

type alias Photo =
    { url : String
    , size : Int
    , title : String
    }

type Status
    = Loading
    | Loaded (List Photo) String
    | Errored String

type alias Model =
    { status : Status
    , chosenSize : ThumbnailSize
    }

initialModel : Model
initialModel =
    { status = Loading
    , chosenSize = Medium
    }

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotRandomPhoto photo ->
            ( { model | status = selectUrl photo.url model.status }
            , Cmd.none
            )
        ClickedPhoto url ->
            ( { model | status = selectUrl url model.status }, Cmd.none )
        ClickedSize size ->
            ( { model | chosenSize = size }, Cmd.none )
        ClickedSupriseMe ->
            case model.status of
                Loaded (firstPhoto :: otherPhotos) _ ->
                    Random.uniform firstPhoto otherPhotos
                        |> Random.generate GotRandomPhoto
                        |> Tuple.pair model
                Loaded [] _ ->
                    ( model, Cmd.none )
                Loading ->
                    ( model, Cmd.none )
                Errored errorMessage ->
                    ( model, Cmd.none )
        GotPhotos (Ok photos) ->
            case photos of
                first :: rest ->
                    ( { model | status = Loaded photos first.url }, Cmd.none )
                [] ->
                    ( { model | status = Errored "0 photos found" }, Cmd.none )
        GotPhotos (Err _) ->
            ( model, Cmd.none )

selectUrl : String -> Status -> Status
selectUrl url status =
    case status of
        Loaded photos _ ->
            Loaded photos url
        Loading ->
            status
        Errored _ ->
            status

main : Program () Model Msg
main =
    Browser.element
        { init = \_ -> ( initialModel, initialCmd )
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }

rangeSlider : List (Attribute msg) -> List (Html msg) -> Html msg
rangeSlider attributes children =
    node "range-slider" attributes children
