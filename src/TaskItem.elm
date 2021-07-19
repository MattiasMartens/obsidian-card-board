module TaskItem exposing
    ( Completion(..)
    , Dated(..)
    , TaskItem
    , completion
    , due
    , filePath
    , id
    , isCompleted
    , isDated
    , isFromFile
    , lineNumber
    , parser
    , title
    , toString
    , toggleCompletion
    )

import Date exposing (Date)
import Maybe.Extra as ME
import Parser exposing (..)
import ParserHelper exposing (isSpaceOrTab, lineEndOrEnd, nonEmptyStringParser)



-- TYPES


type TaskItem
    = TaskItem String Int Completion Dated String


type Completion
    = Incomplete
    | Completed
    | CompletedOn Date


type Dated
    = Undated
    | Due Date


type Content
    = Word String
    | DoneTag Date



-- INFO


title : TaskItem -> String
title (TaskItem _ _ _ _ t) =
    t


completion : TaskItem -> Completion
completion (TaskItem _ _ c _ _) =
    c


due : TaskItem -> Maybe Date
due (TaskItem _ _ _ d _) =
    case d of
        Undated ->
            Nothing

        Due date ->
            Just date


filePath : TaskItem -> String
filePath (TaskItem p _ _ _ _) =
    p


id : TaskItem -> String
id (TaskItem p l _ _ _) =
    p ++ ":" ++ String.fromInt l


isDated : TaskItem -> Bool
isDated taskItem =
    taskItem
        |> due
        |> ME.isJust


isCompleted : TaskItem -> Bool
isCompleted (TaskItem _ _ c _ _) =
    case c of
        Incomplete ->
            False

        Completed ->
            True

        CompletedOn _ ->
            True


isFromFile : String -> TaskItem -> Bool
isFromFile pathToFile (TaskItem p _ _ _ _) =
    p == pathToFile


lineNumber : TaskItem -> Int
lineNumber (TaskItem _ l _ _ _) =
    l


toString : TaskItem -> String
toString (TaskItem _ _ c _ t) =
    case c of
        Incomplete ->
            "- [ ] " ++ String.trim t

        Completed ->
            "- [x] " ++ String.trim t

        CompletedOn _ ->
            "- [x] " ++ String.trim t



-- MODIFICATION


toggleCompletion : TaskItem -> TaskItem
toggleCompletion (TaskItem p l c d t) =
    case c of
        Completed ->
            TaskItem p l Incomplete d t

        CompletedOn _ ->
            TaskItem p l Incomplete d t

        Incomplete ->
            TaskItem p l Completed d t


markCompleted : TaskItem -> Date -> TaskItem
markCompleted (TaskItem p l c d t) completionDate =
    TaskItem p l (CompletedOn completionDate) d t



-- SERIALIZATION


parser : String -> Maybe String -> Parser TaskItem
parser pathToFile fileDate =
    (succeed taskItemBuilder
        |= succeed pathToFile
        |= Parser.getRow
        |= prefixParser
        |. chompWhile isSpaceOrTab
        |= fileDateParser fileDate
        |= contentParser
        |. lineEndOrEnd
    )
        |> andThen rejectIfNoTitle


taskItemBuilder : String -> Int -> Completion -> Dated -> List Content -> TaskItem
taskItemBuilder path row c dated contents =
    let
        extractWords : Content -> List String -> List String
        extractWords content words =
            case content of
                Word word ->
                    word :: words

                DoneTag _ ->
                    words

        extractCompletionDate : Content -> Maybe Date -> Maybe Date
        extractCompletionDate content date =
            case content of
                Word word ->
                    date

                DoneTag completionDate ->
                    Just completionDate

        addCompletionDate : TaskItem -> TaskItem
        addCompletionDate item =
            if isCompleted item then
                contents
                    |> List.foldr extractCompletionDate Nothing
                    |> Maybe.map (markCompleted item)
                    |> Maybe.withDefault item

            else
                item
    in
    contents
        |> List.foldr extractWords []
        |> String.join " "
        |> TaskItem path row c dated
        |> addCompletionDate


contentParser : Parser (List Content)
contentParser =
    loop [] contentHelp


contentHelp : List Content -> Parser (Step (List Content) (List Content))
contentHelp revContents =
    oneOf
        [ succeed (\content -> Loop (content :: revContents))
            |= wordOrDoneTagParser
            |. chompWhile isSpaceOrTab
        , succeed ()
            |> map (\_ -> Done (List.reverse revContents))
        ]


wordOrDoneTagParser : Parser Content
wordOrDoneTagParser =
    oneOf
        [ backtrackable
            doneTagParser
        , succeed Word
            |= ParserHelper.wordParser
        ]


doneTagParser : Parser Content
doneTagParser =
    succeed DoneTag
        |. token "@done("
        |= ParserHelper.dateParser
        |. token ")"


prefixParser : Parser Completion
prefixParser =
    oneOf
        [ succeed Incomplete
            |. token "- [ ] "
        , succeed Completed
            |. token "- [x] "
        , succeed Completed
            |. token "- [X] "
        ]


fileDateParser : Maybe String -> Parser Dated
fileDateParser fileDate =
    fileDate
        |> Maybe.map Date.fromIsoString
        |> Maybe.map Result.toMaybe
        |> ME.join
        |> Maybe.map Due
        |> Maybe.withDefault Undated
        |> succeed


rejectIfNoTitle : TaskItem -> Parser TaskItem
rejectIfNoTitle item =
    if String.length (title item) == 0 then
        problem "Task has no title"

    else
        succeed item
