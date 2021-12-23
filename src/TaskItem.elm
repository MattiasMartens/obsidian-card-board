module TaskItem exposing
    ( AutoCompletion(..)
    , Completion(..)
    , TaskItem
    , TaskItemFields
    , autoComplete
    , completedPosix
    , completion
    , containsId
    , due
    , dueRataDie
    , dummy
    , fields
    , filePath
    , hasNotes
    , hasOneOfTheTags
    , hasSubtasks
    , hasTag
    , hasTags
    , id
    , isCompleted
    , isDated
    , isFromFile
    , lineNumber
    , notes
    , originalText
    , parser
    , subtasks
    , tags
    , tasksToToggle
    , title
    , toString
    , toggleCompletion
    , updateFilePath
    )

import Date exposing (Date)
import FNV1a
import Iso8601
import List.Extra as LE
import Maybe.Extra as ME
import Parser as P exposing ((|.), (|=), Parser)
import ParserHelper exposing (isSpaceOrTab, lineEndOrEnd)
import TaskPaperTag
import Time



-- TYPES


type alias TaskItemFields =
    { autoComplete : AutoCompletion
    , completion : Completion
    , dueFile : Maybe Date
    , dueTag : Maybe Date
    , filePath : String
    , frontMatterTags : List String
    , lineNumber : Int
    , notes : String
    , originalText : String
    , tags : List String
    , title : String
    }


dummy : TaskItem
dummy =
    TaskItem
        { autoComplete = NotSpecifed
        , completion = Incomplete
        , dueFile = Nothing
        , dueTag = Nothing
        , filePath = ""
        , frontMatterTags = []
        , lineNumber = 0
        , notes = ""
        , originalText = ""
        , tags = []
        , title = ""
        }
        []


type TaskItem
    = TaskItem TaskItemFields (List TaskItemFields)


type AutoCompletion
    = NotSpecifed
    | FalseSpecified
    | TrueSpecified


type Completion
    = Incomplete
    | Completed
    | CompletedAt Time.Posix


type Content
    = AutoCompleteTag Bool
    | CompletedTag Time.Posix
    | DueTag Date
    | ObsidianTag String
    | Word String


type IndentedItem
    = Subtask TaskItemFields
    | Note String



-- INFO


autoComplete : TaskItem -> AutoCompletion
autoComplete =
    fields >> .autoComplete


completedPosix : TaskItem -> Int
completedPosix taskItem =
    case completion taskItem of
        CompletedAt time_ ->
            Time.posixToMillis time_

        _ ->
            0


completion : TaskItem -> Completion
completion =
    fields >> .completion


containsId : String -> TaskItem -> Bool
containsId targetId taskItem =
    (id taskItem :: List.map id (subtasks taskItem))
        |> List.member targetId


due : TaskItem -> Maybe Date
due (TaskItem fields_ _) =
    case fields_.dueTag of
        Just _ ->
            fields_.dueTag

        Nothing ->
            fields_.dueFile


dueRataDie : TaskItem -> Int
dueRataDie taskItem =
    case due taskItem of
        Just dueDate ->
            Date.toRataDie dueDate

        Nothing ->
            0


fields : TaskItem -> TaskItemFields
fields (TaskItem f _) =
    f


filePath : TaskItem -> String
filePath =
    fields >> .filePath


hasNotes : TaskItem -> Bool
hasNotes =
    fields >> .notes >> String.isEmpty >> not


hasTags : TaskItem -> Bool
hasTags taskItem =
    not <| List.isEmpty <| tags taskItem


hasOneOfTheTags : List String -> TaskItem -> Bool
hasOneOfTheTags tagsToMatch taskItem =
    List.any (\t -> hasTag t taskItem) tagsToMatch


hasTag : String -> TaskItem -> Bool
hasTag tagToMatch taskItem =
    let
        matches : String -> Bool
        matches itemTag =
            if String.endsWith "/" tagToMatch then
                String.startsWith (String.toLower tagToMatch) (String.toLower itemTag)
                    || (String.toLower itemTag == String.dropRight 1 (String.toLower tagToMatch))

            else
                String.toLower itemTag == String.toLower tagToMatch
    in
    List.any matches <| tags taskItem


hasSubtasks : TaskItem -> Bool
hasSubtasks (TaskItem _ subtasks_) =
    not <| List.isEmpty subtasks_


id : TaskItem -> String
id (TaskItem fields_ _) =
    String.fromInt (FNV1a.hash fields_.filePath) ++ ":" ++ String.fromInt fields_.lineNumber


isDated : TaskItem -> Bool
isDated taskItem =
    taskItem
        |> due
        |> ME.isJust


isCompleted : TaskItem -> Bool
isCompleted (TaskItem fields_ _) =
    case fields_.completion of
        Incomplete ->
            False

        _ ->
            True


isFromFile : String -> TaskItem -> Bool
isFromFile pathToFile =
    fields >> .filePath >> (==) pathToFile


lineNumber : TaskItem -> Int
lineNumber =
    fields >> .lineNumber


notes : TaskItem -> String
notes =
    fields >> .notes


originalText : TaskItem -> String
originalText =
    fields >> .originalText


subtasks : TaskItem -> List TaskItem
subtasks (TaskItem _ subtasks_) =
    List.map (\s -> TaskItem s []) subtasks_


tags : TaskItem -> List String
tags ((TaskItem fields_ _) as taskItem) =
    subtasks taskItem
        |> List.concatMap (\(TaskItem fs _) -> fs.tags)
        |> List.append fields_.tags
        |> List.append fields_.frontMatterTags
        |> LE.unique


tasksToToggle : String -> { a | now : Time.Posix } -> TaskItem -> List TaskItem
tasksToToggle id_ timeWithZone taskItem =
    let
        idBelongsToSubtask =
            taskItem
                |> subtasks
                |> List.map id
                |> List.member id_

        resultIsAllSubtasksCompleted =
            subtasks taskItem
                |> List.map
                    (\t ->
                        if id t == id_ then
                            toggleCompletion timeWithZone t

                        else
                            t
                    )
                |> List.all isCompleted

        matchingTaskItem =
            (taskItem :: subtasks taskItem)
                |> List.filter (\t -> id t == id_)

        topLevelTaskIsNotAlreadyComplete =
            not <| isCompleted taskItem

        shouldAutoComplete =
            case autoComplete taskItem of
                TrueSpecified ->
                    True

                _ ->
                    False
    in
    if shouldAutoComplete && idBelongsToSubtask && resultIsAllSubtasksCompleted && topLevelTaskIsNotAlreadyComplete then
        taskItem :: matchingTaskItem

    else
        matchingTaskItem


title : TaskItem -> String
title =
    fields >> .title


toString : TaskItem -> String
toString (TaskItem fields_ _) =
    let
        leadingWhiteSpace =
            fields_.originalText
                |> String.toList
                |> LE.takeWhile ParserHelper.isSpaceOrTab
                |> String.fromList

        checkbox =
            case fields_.completion of
                Incomplete ->
                    "- [ ] "

                _ ->
                    "- [x] "

        fieldTags =
            if List.length fields_.tags > 0 then
                fields_.tags
                    |> List.map (String.append "#")
                    |> String.join " "
                    |> String.append " "

            else
                ""

        dueTag =
            case fields_.dueTag of
                Just date ->
                    " @due(" ++ Date.toIsoString date ++ ")"

                _ ->
                    ""

        completionTag =
            case fields_.completion of
                CompletedAt completionTime ->
                    let
                        completionString =
                            completionTime
                                |> Iso8601.fromTime
                                |> String.left 19
                    in
                    " @completed(" ++ completionString ++ ")"

                _ ->
                    ""

        autoCompleteTag =
            case fields_.autoComplete of
                NotSpecifed ->
                    ""

                FalseSpecified ->
                    " @autocomplete(false)"

                TrueSpecified ->
                    " @autocomplete(true)"
    in
    leadingWhiteSpace ++ checkbox ++ String.trim fields_.title ++ fieldTags ++ dueTag ++ autoCompleteTag ++ completionTag



-- MODIFICATION


toggleCompletion : { a | now : Time.Posix } -> TaskItem -> TaskItem
toggleCompletion timeWithZone (TaskItem fields_ subtasks_) =
    case fields_.completion of
        Completed ->
            TaskItem { fields_ | completion = Incomplete } subtasks_

        CompletedAt _ ->
            TaskItem { fields_ | completion = Incomplete } subtasks_

        Incomplete ->
            TaskItem { fields_ | completion = CompletedAt timeWithZone.now } subtasks_


updateFilePath : String -> String -> TaskItem -> TaskItem
updateFilePath oldPath newPath ((TaskItem fields_ subtasks_) as taskItem) =
    if fields_.filePath == oldPath then
        TaskItem { fields_ | filePath = newPath } subtasks_

    else
        taskItem



-- SERIALIZATION


parser : String -> Maybe String -> List String -> Int -> Parser TaskItem
parser pathToFile fileDate frontMatterTags bodyOffset =
    (P.succeed taskItemFieldsBuilder
        |= P.getOffset
        |= P.getCol
        |= P.succeed pathToFile
        |= P.succeed frontMatterTags
        |= P.succeed bodyOffset
        |= P.getRow
        |= prefixParser
        |. P.chompWhile isSpaceOrTab
        |= fileDateParser fileDate
        |= contentParser
        |= P.getOffset
        |. lineEndOrEnd
        |= P.getSource
    )
        |> P.andThen rejectIfNoTitle
        |> P.andThen (addAnySubtasksAndNotes pathToFile fileDate frontMatterTags bodyOffset)


taskItemFieldsBuilder : Int -> Int -> String -> List String -> Int -> Int -> Completion -> Maybe Date -> List Content -> Int -> String -> TaskItemFields
taskItemFieldsBuilder startOffset startColumn path frontMatterTags bodyOffset row completion_ dueFromFile contents endOffset source =
    let
        sourceText : String
        sourceText =
            String.slice (startOffset - (startColumn - 1)) endOffset source

        extractWords : Content -> List String -> List String
        extractWords content words =
            case content of
                Word word ->
                    word :: words

                _ ->
                    words

        tagDueDate : Maybe Date
        tagDueDate =
            contents
                |> List.foldr extractDueDate Nothing

        obsidianTags : List String
        obsidianTags =
            contents
                |> List.foldr extractTag []

        extractTag : Content -> List String -> List String
        extractTag content ts =
            case content of
                ObsidianTag t ->
                    t :: ts

                _ ->
                    ts

        extractDueDate : Content -> Maybe Date -> Maybe Date
        extractDueDate content date =
            case content of
                DueTag tagDate ->
                    Just tagDate

                _ ->
                    date

        extractCompletionTime : Content -> Maybe Time.Posix -> Maybe Time.Posix
        extractCompletionTime content time =
            case content of
                CompletedTag completionTime ->
                    Just completionTime

                _ ->
                    time

        extractAutoComplete : Content -> AutoCompletion -> AutoCompletion
        extractAutoComplete content autoComplete_ =
            case content of
                AutoCompleteTag False ->
                    FalseSpecified

                AutoCompleteTag True ->
                    TrueSpecified

                _ ->
                    autoComplete_

        autoCompletefromTag : AutoCompletion
        autoCompletefromTag =
            List.foldr extractAutoComplete NotSpecifed contents

        addCompletionTime : TaskItemFields -> TaskItemFields
        addCompletionTime fields_ =
            if isCompleted (TaskItem fields_ []) then
                contents
                    |> List.foldr extractCompletionTime Nothing
                    |> Maybe.map (\completionDate_ -> { fields_ | completion = CompletedAt completionDate_ })
                    |> Maybe.withDefault fields_

            else
                fields_

        parsedTitle : String
        parsedTitle =
            let
                wordsWithoutBlockLink : List Content
                wordsWithoutBlockLink =
                    case List.reverse contents of
                        (Word endWord) :: cs ->
                            if String.startsWith "^" endWord then
                                List.reverse cs

                            else
                                contents

                        _ ->
                            contents
            in
            wordsWithoutBlockLink
                |> List.foldr extractWords []
                |> String.join " "
    in
    { autoComplete = autoCompletefromTag
    , completion = completion_
    , dueFile = dueFromFile
    , dueTag = tagDueDate
    , filePath = path
    , frontMatterTags = frontMatterTags
    , lineNumber = bodyOffset + row
    , notes = ""
    , originalText = sourceText
    , tags = obsidianTags
    , title = parsedTitle
    }
        |> addCompletionTime


contentParser : Parser (List Content)
contentParser =
    P.loop [] contentHelp


contentHelp : List Content -> Parser (P.Step (List Content) (List Content))
contentHelp revContents =
    P.oneOf
        [ P.succeed (\content -> P.Loop (content :: revContents))
            |= tokenParser
            |. P.chompWhile isSpaceOrTab
        , P.succeed ()
            |> P.map (\_ -> P.Done (List.reverse revContents))
        ]


tokenParser : Parser Content
tokenParser =
    P.oneOf
        [ P.backtrackable <| TaskPaperTag.completedTagParser CompletedTag
        , P.backtrackable <| TaskPaperTag.dueTagParser DueTag
        , P.backtrackable <| TaskPaperTag.autocompleteTagParser AutoCompleteTag
        , P.backtrackable <| obsidianTagParser
        , P.succeed Word
            |= ParserHelper.wordParser
        ]


obsidianTagParser : Parser Content
obsidianTagParser =
    P.succeed ObsidianTag
        |. P.token "#"
        |= ParserHelper.wordParser


prefixParser : Parser Completion
prefixParser =
    P.oneOf
        [ P.succeed Incomplete
            |. P.token "- [ ] "
        , P.succeed Completed
            |. P.token "- [x] "
        , P.succeed Completed
            |. P.token "- [X] "
        ]


fileDateParser : Maybe String -> Parser (Maybe Date)
fileDateParser fileDate =
    fileDate
        |> Maybe.map Date.fromIsoString
        |> Maybe.map Result.toMaybe
        |> ME.join
        |> P.succeed


addAnySubtasksAndNotes : String -> Maybe String -> List String -> Int -> TaskItemFields -> Parser TaskItem
addAnySubtasksAndNotes pathToFile fileDate frontMatterTags bodyOffset fields_ =
    let
        buildTaskItem : List IndentedItem -> Parser TaskItem
        buildTaskItem indentedItems =
            P.succeed (TaskItem { fields_ | notes = parsedNotes indentedItems } <| parsedSubtasks indentedItems)

        parsedSubtasks : List IndentedItem -> List TaskItemFields
        parsedSubtasks indentedItems =
            indentedItems
                |> List.filterMap
                    (\i ->
                        case i of
                            Subtask taskItemFields ->
                                Just taskItemFields

                            _ ->
                                Nothing
                    )

        parsedNotes : List IndentedItem -> String
        parsedNotes indentedItems =
            indentedItems
                |> List.filterMap
                    (\i ->
                        case i of
                            Note notes_ ->
                                Just notes_

                            _ ->
                                Nothing
                    )
                |> String.join "\n"
    in
    P.succeed identity
        |= ParserHelper.indentParser (indentedItemParser pathToFile fileDate frontMatterTags bodyOffset)
        |> P.andThen buildTaskItem


indentedItemParser : String -> Maybe String -> List String -> Int -> Parser IndentedItem
indentedItemParser pathToFile fileDate frontMatterTags bodyOffset =
    P.oneOf
        [ subTaskParser pathToFile fileDate frontMatterTags bodyOffset
        , notesParser
        ]


notesParser : Parser IndentedItem
notesParser =
    P.succeed Note
        |= ParserHelper.anyLineParser


subTaskParser : String -> Maybe String -> List String -> Int -> Parser IndentedItem
subTaskParser pathToFile fileDate frontMatterTags bodyOffset =
    P.succeed taskItemFieldsBuilder
        |= P.getOffset
        |= P.getCol
        |= P.succeed pathToFile
        |= P.succeed frontMatterTags
        |= P.succeed bodyOffset
        |= P.getRow
        |= prefixParser
        |. P.chompWhile isSpaceOrTab
        |= fileDateParser fileDate
        |= contentParser
        |= P.getOffset
        |. lineEndOrEnd
        |= P.getSource
        |> P.andThen (\f -> P.succeed (Subtask f))


rejectIfNoTitle : TaskItemFields -> Parser TaskItemFields
rejectIfNoTitle fields_ =
    if String.length fields_.title == 0 then
        P.problem "Task has no title"

    else
        P.succeed fields_
