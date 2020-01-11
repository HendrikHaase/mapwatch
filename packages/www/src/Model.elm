module Model exposing
    ( Model
    , Msg(..)
    , OkModel
    , Progress
    , init
    , subscriptions
    , update
    )

import Browser
import Browser.Navigation as Nav
import Json.Decode as D
import Mapwatch
import Mapwatch.Datamine as Datamine exposing (Datamine)
import Mapwatch.Instance as Instance
import Mapwatch.LogLine as LogLine
import Mapwatch.Run as Run
import Mapwatch.Visit as Visit
import Maybe.Extra
import Ports
import Route exposing (Route)
import Set
import Task
import Time
import Url exposing (Url)


type alias Flags =
    { loadedAt : Int
    , tickOffset : Int
    , isBrowserSupported : Bool
    , platform : String
    , changelog : String
    , version : String
    , datamine : D.Value
    }


type alias Progress =
    Ports.Progress


type alias Config =
    { maxSize : Int }


type alias Model =
    Result String OkModel


type alias OkModel =
    { nav : Nav.Key
    , mapwatch : Mapwatch.OkModel
    , config : Config
    , flags : Flags
    , loadedAt : Time.Posix
    , route : Route
    , now : Time.Posix
    , tz : Time.Zone
    , lines : List String
    , volume : Int
    }


type Msg
    = M Mapwatch.Msg
    | Tick Time.Posix
    | SetTimezone Time.Zone
    | InputClientLogWithId String
    | InputMaxSize String
    | NavRequest Browser.UrlRequest
    | NavLocation Url
    | RouteTo Route
    | MapsSearch Route.MapsParams
    | HistorySearch Route.HistoryParams
    | InputVolume String


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url nav =
    let
        loadedAt =
            Time.millisToPosix flags.loadedAt

        createModel : Mapwatch.OkModel -> OkModel
        createModel mapwatch =
            { nav = nav
            , mapwatch = mapwatch
            , config = { maxSize = 20 }
            , flags = flags
            , loadedAt = loadedAt
            , route = Route.parse url
            , now = loadedAt
            , tz = Time.utc
            , lines = []
            , volume = 50
            }

        model : Model
        model =
            Result.map createModel
                (Mapwatch.initModel flags.datamine)
    in
    ( model
    , Cmd.batch
        [ Task.perform SetTimezone Time.here
        , model |> Result.map sendVolume |> Result.withDefault Cmd.none
        ]
    )


sendVolume : OkModel -> Cmd msg
sendVolume model =
    Ports.sendVolume (Route.isSpeechEnabled model.route) model.volume


updateRawLine : { date : Int, line : String } -> OkModel -> OkModel
updateRawLine raw model =
    -- *Only when debugging*, save all raw loglines.
    case model.route of
        Route.DebugDumpLines ->
            case LogLine.parse (Time.millisToPosix raw.date) raw.line of
                Ok _ ->
                    { model | lines = raw.line :: model.lines }

                Err _ ->
                    model

        _ ->
            model


applyTimeOffset : OkModel -> Time.Posix -> Time.Posix
applyTimeOffset model t0 =
    (Time.posixToMillis t0 - model.flags.tickOffset)
        |> Time.millisToPosix


tick : Time.Posix -> OkModel -> OkModel
tick t0 model =
    let
        t =
            applyTimeOffset model t0
    in
    { model | mapwatch = Mapwatch.tick t model.mapwatch, now = t }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg rmodel =
    case rmodel of
        Err err ->
            ( rmodel, Cmd.none )

        Ok model ->
            updateOk msg model |> Tuple.mapFirst Ok


updateOk : Msg -> OkModel -> ( OkModel, Cmd Msg )
updateOk msg ({ config } as model) =
    case msg of
        Tick t ->
            if Maybe.Extra.unwrap False Mapwatch.isProgressDone model.mapwatch.progress then
                ( tick t model, Cmd.none )

            else
                ( { model | now = applyTimeOffset model t }, Cmd.none )

        SetTimezone tz ->
            ( { model | tz = tz }, Cmd.none )

        NavLocation url ->
            let
                newModel =
                    { model | route = Route.parse url }
            in
            ( newModel, sendVolume newModel )

        NavRequest (Browser.Internal url) ->
            ( model, url |> Url.toString |> Nav.pushUrl model.nav )

        NavRequest (Browser.External urlstr) ->
            ( model, urlstr |> Nav.load )

        InputClientLogWithId id ->
            ( model, Ports.inputClientLogWithId { id = id, maxSize = config.maxSize } )

        InputMaxSize s ->
            case String.toInt s of
                Just s_ ->
                    ( { model | config = { config | maxSize = s_ } }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        MapsSearch ps ->
            ( model
            , Route.Maps ps
                |> Route.stringify
                -- |> Debug.log "maps-search"
                |> Nav.replaceUrl model.nav
            )

        HistorySearch ps ->
            ( model
            , Route.History ps
                |> Route.stringify
                -- |> Debug.log "history-search"
                |> Nav.replaceUrl model.nav
            )

        RouteTo route ->
            ( model
            , route
                |> Route.stringify
                -- |> Debug.log "route-to"
                |> Nav.replaceUrl model.nav
            )

        InputVolume str ->
            case str |> String.toInt of
                Nothing ->
                    ( model, Cmd.none )

                Just volume ->
                    let
                        newModel =
                            { model | volume = volume }
                    in
                    ( newModel, sendVolume newModel )

        M msg_ ->
            case msg_ of
                Mapwatch.RecvLogLine raw ->
                    updateMapwatch msg_ model
                        |> Tuple.mapFirst (updateRawLine raw)

                Mapwatch.RecvProgress p ->
                    updateMapwatch (Mapwatch.RecvProgress { p | updatedAt = p.updatedAt |> Time.millisToPosix |> applyTimeOffset model |> Time.posixToMillis }) model


updateMapwatch : Mapwatch.Msg -> OkModel -> ( OkModel, Cmd Msg )
updateMapwatch msg model =
    let
        ( mapwatch, cmd ) =
            Mapwatch.updateOk msg model.mapwatch
    in
    ( { model | mapwatch = mapwatch }, Cmd.map M cmd )


subscriptions : Model -> Sub Msg
subscriptions rmodel =
    case rmodel of
        Err err ->
            Sub.none

        Ok model ->
            Sub.batch
                [ Mapwatch.subscriptions (Ok model.mapwatch) |> Sub.map M

                -- Slow down animation, deliberately - don't eat poe's cpu
                --, Browser.Events.onAnimationFrame Tick
                , Time.every 1000 Tick
                ]
