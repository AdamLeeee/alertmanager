module Views.SilenceForm.Types exposing
    ( Model
    , SilenceForm
    , SilenceFormFieldMsg(..)
    , SilenceFormMsg(..)
    , fromDateTimePicker
    , fromMatchersAndCommentAndTime
    , fromSilence
    , initSilenceForm
    , parseEndsAt
    , toSilence
    , validateForm
    )

import Browser.Navigation exposing (Key)
import Data.GettableAlert exposing (GettableAlert)
import Data.GettableSilence exposing (GettableSilence)
import Data.Matcher exposing (Matcher)
import Data.PostableSilence exposing (PostableSilence)
import DateTime
import Silences.Types exposing (nullSilence)
import Time exposing (Posix)
import Utils.Date exposing (addDuration, durationFormat, parseDuration, timeDifference, timeFromString, timeToString)
import Utils.DateTimePicker.Types exposing (DateTimePicker, initDateTimePicker, initFromStartAndEndTime)
import Utils.Filter
import Utils.FormValidation
    exposing
        ( ValidatedField
        , ValidationState(..)
        , initialField
        , stringNotEmpty
        , validate
        )
import Utils.Types exposing (ApiData(..), Duration)
import Views.FilterBar.Types as FilterBar


type alias Model =
    { form : SilenceForm
    , filterBar : FilterBar.Model
    , silenceId : ApiData String
    , alerts : ApiData (List GettableAlert)
    , activeAlertId : Maybe String
    , key : Key
    }


type alias SilenceForm =
    { id : Maybe String
    , createdBy : ValidatedField
    , comment : ValidatedField
    , startsAt : ValidatedField
    , endsAt : ValidatedField
    , duration : ValidatedField
    , dateTimePicker : DateTimePicker
    , viewDateTimePicker : Bool
    }


type SilenceFormMsg
    = UpdateField SilenceFormFieldMsg
    | CreateSilence
    | PreviewSilence
    | AlertGroupsPreview (ApiData (List GettableAlert))
    | SetActiveAlert (Maybe String)
    | FetchSilence String
    | NewSilenceFromMatchersAndComment String Utils.Filter.SilenceFormGetParams
    | NewSilenceFromMatchersAndCommentAndTime String (List Utils.Filter.Matcher) String Posix
    | SilenceFetch (ApiData GettableSilence)
    | SilenceCreate (ApiData String)
    | UpdateDateTimePicker Utils.DateTimePicker.Types.Msg
    | MsgForFilterBar FilterBar.Msg


type SilenceFormFieldMsg
    = UpdateStartsAt String
    | UpdateEndsAt String
    | UpdateDuration String
    | ValidateTime
    | UpdateCreatedBy String
    | ValidateCreatedBy
    | UpdateComment String
    | ValidateComment
    | UpdateTimesFromPicker
    | OpenDateTimePicker
    | CloseDateTimePicker


initSilenceForm : Key -> Model
initSilenceForm key =
    { form = empty
    , filterBar = FilterBar.initFilterBar Nothing []
    , silenceId = Utils.Types.Initial
    , alerts = Utils.Types.Initial
    , activeAlertId = Nothing
    , key = key
    }


toSilence : FilterBar.Model -> SilenceForm -> Maybe PostableSilence
toSilence filterBar { id, comment, createdBy, startsAt, endsAt } =
    Result.map4
        (\nonEmptyComment nonEmptyCreatedBy parsedStartsAt parsedEndsAt ->
            { nullSilence
                | id = id
                , comment = nonEmptyComment
                , matchers = List.map Utils.Filter.toApiMatcher filterBar.matchers
                , createdBy = nonEmptyCreatedBy
                , startsAt = parsedStartsAt
                , endsAt = parsedEndsAt
            }
        )
        (stringNotEmpty comment.value)
        (stringNotEmpty createdBy.value)
        (timeFromString startsAt.value)
        (parseEndsAt startsAt.value endsAt.value)
        |> Result.toMaybe


fromSilence : GettableSilence -> SilenceForm
fromSilence { id, createdBy, comment, startsAt, endsAt } =
    let
        startsPosix =
            Utils.Date.timeFromString (DateTime.toString startsAt)
                |> Result.toMaybe

        endsPosix =
            Utils.Date.timeFromString (DateTime.toString endsAt)
                |> Result.toMaybe
    in
    { id = Just id
    , createdBy = initialField createdBy
    , comment = initialField comment
    , startsAt = initialField (timeToString startsAt)
    , endsAt = initialField (timeToString endsAt)
    , duration = initialField (durationFormat (timeDifference startsAt endsAt) |> Maybe.withDefault "")
    , dateTimePicker = initFromStartAndEndTime startsPosix endsPosix
    , viewDateTimePicker = False
    }


validateForm : SilenceForm -> SilenceForm
validateForm { id, createdBy, comment, startsAt, endsAt, duration, dateTimePicker } =
    { id = id
    , createdBy = validate stringNotEmpty createdBy
    , comment = validate stringNotEmpty comment
    , startsAt = validate timeFromString startsAt
    , endsAt = validate (parseEndsAt startsAt.value) endsAt
    , duration = validate parseDuration duration
    , dateTimePicker = dateTimePicker
    , viewDateTimePicker = False
    }


parseEndsAt : String -> String -> Result String Posix
parseEndsAt startsAt endsAt =
    case ( timeFromString startsAt, timeFromString endsAt ) of
        ( Ok starts, Ok ends ) ->
            if Time.posixToMillis starts > Time.posixToMillis ends then
                Err "Can't be in the past"

            else
                Ok ends

        ( _, endsResult ) ->
            endsResult


empty : SilenceForm
empty =
    { id = Nothing
    , createdBy = initialField ""
    , comment = initialField ""
    , startsAt = initialField ""
    , endsAt = initialField ""
    , duration = initialField ""
    , dateTimePicker = initDateTimePicker
    , viewDateTimePicker = False
    }


defaultDuration : Float
defaultDuration =
    -- 2 hours
    2 * 60 * 60 * 1000


fromMatchersAndCommentAndTime : String -> String -> Posix -> SilenceForm
fromMatchersAndCommentAndTime defaultCreator comment now =
    { empty
        | startsAt = initialField (timeToString now)
        , endsAt = initialField (timeToString (addDuration defaultDuration now))
        , duration = initialField (durationFormat defaultDuration |> Maybe.withDefault "")
        , createdBy = initialField defaultCreator
        , comment = initialField comment
        , dateTimePicker = initFromStartAndEndTime (Just now) (Just (addDuration defaultDuration now))
        , viewDateTimePicker = False
    }


fromDateTimePicker : SilenceForm -> DateTimePicker -> SilenceForm
fromDateTimePicker { id, createdBy, comment, startsAt, endsAt, duration } newPicker =
    { id = id
    , createdBy = createdBy
    , comment = comment
    , startsAt = startsAt
    , endsAt = endsAt
    , duration = duration
    , dateTimePicker = newPicker
    , viewDateTimePicker = True
    }
