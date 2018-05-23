module View.Maps exposing (view)

import Html as H
import Html.Attributes as A
import Html.Events as E
import Time
import Date
import Dict
import Regex
import Model as Model exposing (Model, Msg(..))
import Model.Instance as Instance exposing (Instance)
import Model.Run as Run exposing (Run)
import Model.MapList as MapList
import View.Nav
import View.Setup
import View.History
import View.Home exposing (maskedText, viewHeader, viewParseError, viewProgress, viewInstance, viewDate, formatDuration, formatSideAreaType, viewSideAreaName)
import View.Util exposing (roundToPlaces)


-- import View.History as History

import View.Icon as Icon


view : String -> Model -> H.Html Msg
view search model =
    H.div []
        [ viewHeader
        , View.Nav.view <| Just model.route
        , View.Setup.view model
        , viewParseError model.parseError
        , viewBody search model
        ]


viewBody : String -> Model -> H.Html Msg
viewBody search model =
    case model.progress of
        Nothing ->
            -- waiting for file input, nothing to show yet
            H.div [] []

        Just p ->
            H.div [] <|
                (if Model.isProgressDone p then
                    -- all done!
                    [ viewMain search model ]
                 else
                    []
                )
                    ++ [ viewProgress p ]


viewSearch search =
    H.div [ A.class "search" ]
        [ Icon.fas "search"
        , H.input
            [ A.value search
            , A.placeholder "map name..."
            , A.tabindex 1
            , E.onInput MapsSearch
            ]
            []
        ]


viewMain : String -> Model -> H.Html Msg
viewMain search model =
    H.div []
        [ viewSearch search
        , MapList.mapList
            |> List.filter (.name >> Regex.contains (Regex.regex search |> Regex.caseInsensitive))
            |> Run.groupMapNames model.runs
            |> List.reverse
            |> List.map (uncurry viewMap)
            |> \rows -> H.table [ A.class "by-map" ] [ H.body [] rows ]
        ]


viewMap : MapList.Map -> List Run -> H.Html msg
viewMap map runs =
    let
        durs =
            Run.meanDurationSet runs

        num =
            List.length runs
    in
        H.tr []
            ([ H.td [ A.class "zone" ] [ viewMapName map ]
             , H.td [] [ H.text <| "(T" ++ toString map.tier ++ ")" ]
             , H.td [] [ H.text <| formatDuration durs.start ++ " in map" ]
             , H.td [] [ H.text <| toString (roundToPlaces 2 durs.portals) ++ " portals" ]
             , H.td [] [ H.text <| "×" ++ toString num ]
             ]
             -- ++ (View.History.viewDurationSet <| )
            )


viewMapName : MapList.Map -> H.Html msg
viewMapName map =
    H.span [] [ Icon.mapOrBlank map.name, H.text map.name ]
