module View.Home exposing (formatBytes, formatDuration, formatSideAreaType, maskedText, selfUrl, viewDate, viewHeader, viewInstance, viewParseError, viewProgress, viewSideAreaName)

-- TODO: This used to be its own page. Now it's a graveyard of functions that get
-- called from other pages. I should really clean it up and find these a new home.

import Date
import Dict
import Html as H
import Html.Attributes as A
import Html.Events as E
import Mapwatch as Mapwatch exposing (Model, Msg(..))
import Mapwatch.Instance as Instance exposing (Instance)
import Mapwatch.LogLine as LogLine
import Mapwatch.Run as Run
import Mapwatch.Visit as Visit
import Mapwatch.Zone as Zone
import Route
import Time
import View.Icon as Icon
import View.Nav
import View.Setup


viewInstance : Route.HistoryParams -> Instance -> H.Html msg
viewInstance qs instance =
    case instance of
        Instance.Instance i ->
            if Zone.isMap i.zone then
                -- TODO preserve before/after
                H.a [ Route.href <| Route.History { qs | search = Just i.zone }, A.title i.addr ] [ Icon.mapOrBlank i.zone, H.text i.zone ]

            else
                H.span [ A.title i.addr ] [ H.text i.zone ]

        Instance.MainMenu ->
            H.span [] [ H.text "(none)" ]


formatDuration : Float -> String
formatDuration dur0 =
    let
        dur =
            floor dur0

        sign =
            if dur >= 0 then
                ""

            else
                "-"

        h =
            abs <| dur // truncate Time.hour

        m =
            abs <| rem dur (truncate Time.hour) // truncate Time.minute

        s =
            abs <| rem dur (truncate Time.minute) // truncate Time.second

        ms =
            abs <| rem dur (truncate Time.second)

        pad0 length num =
            num
                |> toString
                |> String.padLeft length '0'

        hpad =
            if h > 0 then
                [ pad0 2 h ]

            else
                []
    in
    -- String.join ":" <| [ pad0 2 h, pad0 2 m, pad0 2 s, pad0 4 ms ]
    sign ++ String.join ":" (hpad ++ [ pad0 2 m, pad0 2 s ])


viewParseError : Maybe LogLine.ParseError -> H.Html msg
viewParseError err =
    case err of
        Nothing ->
            H.div [] []

        Just err ->
            H.div [] [ H.text <| "Log parsing error: " ++ toString err ]


formatBytes : Int -> String
formatBytes b =
    let
        k =
            toFloat b / 1024

        m =
            k / 1024

        g =
            m / 1024

        t =
            g / 1024

        ( val, unit ) =
            if t >= 1 then
                ( t, " TB" )

            else if g >= 1 then
                ( g, " GB" )

            else if m >= 1 then
                ( m, " MB" )

            else if k >= 1 then
                ( k, " KB" )

            else
                ( toFloat b, " bytes" )

        places n val =
            toString <| (toFloat <| floor <| val * (10 ^ n)) / (10 ^ n)
    in
    places 2 val ++ unit


viewProgress : Mapwatch.Progress -> H.Html msg
viewProgress p =
    if Mapwatch.isProgressDone p then
        H.div [] [ H.br [] [], H.text <| "Processed " ++ formatBytes p.max ++ " in " ++ toString (Mapwatch.progressDuration p / 1000) ++ "s" ]

    else if p.max <= 0 then
        H.div [] [ Icon.fasPulse "spinner" ]

    else
        H.div []
            [ H.progress [ A.value (toString p.val), A.max (toString p.max) ] []
            , H.div []
                [ H.text <|
                    formatBytes p.val
                        ++ " / "
                        ++ formatBytes p.max
                        ++ ": "
                        ++ toString (floor <| Mapwatch.progressPercent p * 100)
                        ++ "%"

                -- ++ " in"
                -- ++ toString (Mapwatch.progressDuration p / 1000)
                -- ++ "s"
                ]
            ]


viewDate : Date.Date -> H.Html msg
viewDate d =
    H.span [ A.title (toString d) ]
        [ H.text <| toString (Date.day d) ++ " " ++ toString (Date.month d) ]


formatSideAreaType : Instance -> Maybe String
formatSideAreaType instance =
    case Zone.sideZoneType <| Instance.unwrap Nothing (Just << .zone) instance of
        Zone.OtherSideZone ->
            Nothing

        Zone.Mission master ->
            Just <| toString master ++ " mission"

        Zone.ElderGuardian guardian ->
            Just <| "Elder Guardian: The " ++ toString guardian


viewSideAreaName : Route.HistoryParams -> Instance -> H.Html msg
viewSideAreaName qs instance =
    case formatSideAreaType instance of
        Nothing ->
            viewInstance qs instance

        Just str ->
            H.span [] [ H.text <| str ++ " (", viewInstance qs instance, H.text ")" ]


maskedText : String -> H.Html msg
maskedText str =
    -- This text is hidden on the webpage, but can be copypasted. Useful for formatting shared text.
    H.span [ A.style [ ( "opacity", "0" ), ( "font-size", "0" ), ( "white-space", "pre" ) ] ] [ H.text str ]


selfUrl =
    "https://mapwatch.github.io"


viewHeader : H.Html msg
viewHeader =
    H.div []
        [ H.h1 [ A.class "title" ]
            [ maskedText "["

            -- , H.a [ A.href "./" ] [ Icon.fas "tachometer-alt", H.text " Mapwatch" ]
            , H.a [ A.href "#/" ] [ H.text " Mapwatch" ]
            , maskedText <| "](" ++ selfUrl ++ ")"
            ]
        , H.small []
            [ H.text " - automatically time your Path of Exile map clears" ]
        ]
