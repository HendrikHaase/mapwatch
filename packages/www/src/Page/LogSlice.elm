module Page.LogSlice exposing (view)

import Html as H exposing (..)
import Html.Attributes as A exposing (..)
import Html.Events as E exposing (..)
import Mapwatch
import Model exposing (Msg, OkModel)
import Page.History
import RemoteData exposing (RemoteData)
import Route exposing (Route)
import View.Home
import View.Nav
import View.Setup


view : Int -> Int -> OkModel -> Html Msg
view posStart posEnd model =
    div [ class "main", style "width" "100%" ]
        [ View.Home.viewHeader model
        , View.Nav.view model
        , View.Setup.view model
        , viewBody posStart posEnd model
        ]


viewBody : Int -> Int -> OkModel -> Html Msg
viewBody posStart posEnd model =
    case Mapwatch.ready model.mapwatch of
        Mapwatch.NotStarted ->
            div [] []

        Mapwatch.LoadingHistory p ->
            View.Home.viewProgress p

        Mapwatch.Ready _ ->
            case model.logSlicePage of
                RemoteData.NotAsked ->
                    div [] []

                RemoteData.Loading ->
                    div [] [ text "loading....." ]

                RemoteData.Failure err ->
                    pre [ style "color" "red" ] [ text err ]

                RemoteData.Success slice ->
                    div []
                        [ h3 [] [ text "Log Snippet" ]
                        , table [ class "timer history" ]
                            [ slice.model.runs
                                |> List.map (Page.History.viewHistoryRun model { showDate = True, loadedAt = model.loadedAt } (always Nothing))
                                |> List.concat
                                |> tbody []
                            ]
                        , div [] <|
                            if List.isEmpty slice.model.runs then
                                [ p [] [ text "This excerpt from your ", code [] [ text "client.txt" ], text " file generated no complete Mapwatch runs." ]
                                ]

                            else
                                [ p []
                                    [ text "The above was generated by this excerpt from your "
                                    , code [] [ text "client.txt" ]
                                    , text " file. "
                                    , br [] []
                                    , text "Anything uninteresting to Mapwatch has been removed, including chat and IP addresses."
                                    , br [] []
                                    , b [] [ text "You can copy and share this text with others." ]
                                    ]
                                ]
                        , textarea [ readonly True, style "min-height" "20em", style "width" "100%" ] [ text "TODO" ]
                        , details []
                            [ summary [] [ text "Click for the unfiltered log excerpt, including chat, whispers, and IP addresses." ]
                            , b [] [ text "Do not share this with others." ]
                            , textarea [ readonly True, style "min-height" "20em", style "width" "100%" ] [ text slice.log ]
                            ]
                        ]
