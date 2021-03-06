port module Ports exposing
    ( Progress
    , changelog
    , inputClientLogWithId
    , logline
    , progress
    , progressComplete
    , sendJoinInstance
    )

import Date as Date exposing (Date)
import Json.Decode as Decode
import Json.Encode as Encode
import Mapwatch.Instance as Instance exposing (Instance)
import Mapwatch.Run as Run exposing (Run)
import Mapwatch.Visit as Visit exposing (Visit)
import Maybe.Extra
import Speech
import Time as Time exposing (Time)


port inputClientLogWithId : { id : String, maxSize : Int } -> Cmd msg


port changelog : (String -> msg) -> Sub msg


port logline : (String -> msg) -> Sub msg


type alias Progress =
    { val : Int, max : Int, startedAt : Time, updatedAt : Time, name : String }


port progress : (Progress -> msg) -> Sub msg


type alias InstanceEvent =
    Maybe Instance.Address


type alias VisitEvent =
    { instance : InstanceEvent, joinedAt : Time, leftAt : Time }


type alias RunEvent =
    { instance : Instance.Address, joinedAt : Time, leftAt : Time }



-- not used internally; these are for callers and analytics.
-- These really should be two separate ports, but using the same outgoing port guarantees order, and that's important.


port events : Encode.Value -> Cmd msg


progressComplete : { name : String } -> Cmd msg
progressComplete e =
    events <|
        Encode.object
            [ ( "type", Encode.string "progressComplete" )
            , ( "name", Encode.string e.name )
            ]


sendJoinInstance : Date -> Instance -> Maybe Visit -> Run.State -> Maybe Run -> Cmd msg
sendJoinInstance date instance visit runState lastRun =
    events <|
        Encode.object
            [ ( "type", Encode.string "joinInstance" )
            , ( "joinedAt", encodeDate date )
            , ( "instance", encodeInstance instance )
            , ( "lastVisit", visit |> Maybe.Extra.unwrap Encode.null encodeVisit )
            , ( "lastMapRun", lastRun |> Maybe.Extra.unwrap Encode.null encodeMapRun )
            , ( "say", Speech.joinInstance runState lastRun instance |> Maybe.Extra.unwrap Encode.null Encode.string )
            ]


encodeAddress : Instance.Address -> Encode.Value
encodeAddress i =
    Encode.object [ ( "zone", Encode.string i.zone ), ( "addr", Encode.string i.addr ) ]


encodeInstance : Instance -> Encode.Value
encodeInstance =
    Instance.unwrap Encode.null encodeAddress


encodeVisit : Visit -> Encode.Value
encodeVisit v =
    Encode.object
        [ ( "instance", encodeInstance v.instance )
        , ( "joinedAt", encodeDate v.joinedAt )
        , ( "leftAt", encodeDate v.leftAt )
        ]


encodeMapRun : Run -> Encode.Value
encodeMapRun r =
    Encode.object
        [ ( "instance", encodeAddress <| Run.instance r )
        , ( "joinedAt", encodeDate r.first.joinedAt )
        , ( "leftAt", encodeDate r.last.leftAt )
        ]


encodeDate : Date -> Encode.Value
encodeDate =
    Date.toTime >> Encode.float
