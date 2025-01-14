port module InteropPorts exposing
    ( addHoverToCardEditButtons
    , closeView
    , decodeFlags
    , deleteTask
    , displayTaskMarkdown
    , elmInitialized
    , openTaskSourceFile
    , requestFilterCandidates
    , rewriteTasks
    , toElm
    , updateSettings
    )

import Card exposing (Card)
import DataviewTaskCompletion exposing (DataviewTaskCompletion)
import GlobalSettings exposing (TaskCompletionFormat)
import InteropDefinitions
import Json.Decode
import Json.Encode
import Settings exposing (Settings)
import TaskItem exposing (TaskItem)
import TimeWithZone exposing (TimeWithZone)
import TsJson.Decode as TsDecode
import TsJson.Encode as TsEncode


toElm : Sub (Result Json.Decode.Error InteropDefinitions.ToElm)
toElm =
    (InteropDefinitions.interop.toElm |> TsDecode.decoder)
        |> Json.Decode.decodeValue
        |> interopToElm



-- COMMANDS


addHoverToCardEditButtons : List Card -> Cmd msg
addHoverToCardEditButtons cards =
    cards
        |> List.map (\c -> { filePath = Card.filePath c, id = Card.editButtonId c })
        |> encodeVariant "addFilePreviewHovers" InteropDefinitions.addFilePreviewHoversEncoder
        |> interopFromElm


closeView : Cmd msg
closeView =
    encodeVariant "closeView" (TsEncode.object []) ()
        |> interopFromElm


elmInitialized : Cmd msg
elmInitialized =
    encodeVariant "elmInitialized" (TsEncode.object []) ()
        |> interopFromElm


deleteTask : { a | filePath : String, lineNumber : Int, originalText : String } -> Cmd msg
deleteTask info =
    info
        |> encodeVariant "deleteTask" InteropDefinitions.deleteTaskEncoder
        |> interopFromElm


displayTaskMarkdown : List Card -> Cmd msg
displayTaskMarkdown cards =
    cards
        |> List.map (\c -> { filePath = Card.filePath c, taskMarkdown = Card.markdownWithIds c })
        |> encodeVariant "displayTaskMarkdown" InteropDefinitions.displayTaskMarkdownEncoder
        |> interopFromElm


openTaskSourceFile : { a | filePath : String, lineNumber : Int, originalText : String } -> Cmd msg
openTaskSourceFile info =
    info
        |> encodeVariant "openTaskSourceFile" InteropDefinitions.openTaskSourceFileEncoder
        |> interopFromElm


requestFilterCandidates : Cmd msg
requestFilterCandidates =
    encodeVariant "requestFilterCandidates" (TsEncode.object []) ()
        |> interopFromElm


rewriteTasks : DataviewTaskCompletion -> TaskCompletionFormat -> TimeWithZone -> String -> List TaskItem -> Cmd msg
rewriteTasks dataviewTaskCompletion taskCompletionFormat timeWithZone filePath taskItems =
    let
        rewriteDetails : TaskItem -> { lineNumber : Int, originalText : String, newText : String }
        rewriteDetails taskItem =
            { lineNumber = TaskItem.lineNumber taskItem
            , originalText = TaskItem.originalText taskItem
            , newText = TaskItem.toToggledString dataviewTaskCompletion taskCompletionFormat timeWithZone taskItem
            }
    in
    { filePath = filePath, tasks = List.map rewriteDetails taskItems }
        |> encodeVariant "updateTasks" InteropDefinitions.updateTasksEncoder
        |> interopFromElm


updateSettings : Settings -> Cmd msg
updateSettings settings =
    { settings | version = Settings.currentVersion }
        |> encodeVariant "updateSettings" Settings.encoder
        |> interopFromElm



-- HELPERS


encodeVariant : String -> TsEncode.Encoder arg1 -> arg1 -> Json.Encode.Value
encodeVariant variantName encoder_ arg1 =
    arg1
        |> (TsEncode.object
                [ TsEncode.required "tag" identity (TsEncode.literal (Json.Encode.string variantName))
                , TsEncode.required "data" identity encoder_
                ]
                |> TsEncode.encoder
           )


decodeFlags : Json.Decode.Value -> Result Json.Decode.Error InteropDefinitions.Flags
decodeFlags flags =
    Json.Decode.decodeValue
        (InteropDefinitions.interop.flags |> TsDecode.decoder)
        flags



-- PORTS


port interopFromElm : Json.Encode.Value -> Cmd msg


port interopToElm : (Json.Decode.Value -> msg) -> Sub msg
