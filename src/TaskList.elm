module TaskList exposing
    ( TaskList
    , append
    , concat
    , empty
    , filter
    , foldl
    , fromMarkdown
    , map
    , parser
    , removeForFile
    , removeTags
    , replaceForFile
    , taskContainingId
    , taskFromId
    , taskIds
    , taskTitles
    , tasks
    , topLevelTasks
    )

import DataviewTaskCompletion exposing (DataviewTaskCompletion)
import List.Extra as LE
import MarkdownFile exposing (MarkdownFile)
import Parser as P exposing (Parser)
import ParserHelper exposing (anyLineParser)
import TagList exposing (TagList)
import TaskItem exposing (TaskItem)



-- TYPES


type TaskList
    = TaskList (List TaskItem)



-- CREATE


empty : TaskList
empty =
    TaskList []


fromMarkdown : DataviewTaskCompletion -> MarkdownFile -> TaskList
fromMarkdown dataviewTaskCompletion markdownFile =
    P.run
        (parser
            dataviewTaskCompletion
            markdownFile.filePath
            markdownFile.fileDate
            markdownFile.frontMatterTags
            markdownFile.bodyOffset
        )
        (markdownFile.body ++ "\n")
        |> Result.withDefault empty



-- PARSE


parser : DataviewTaskCompletion -> String -> Maybe String -> TagList -> Int -> Parser TaskList
parser dataviewTaskCompletion filePath fileDate frontMatterTags bodyOffset =
    P.loop [] (taskItemsHelp dataviewTaskCompletion filePath fileDate frontMatterTags bodyOffset)
        |> P.map (\ts -> TaskList ts)



-- COMBINE


append : TaskList -> TaskList -> TaskList
append (TaskList l1) (TaskList l2) =
    TaskList <| List.append l1 l2


concat : List TaskList -> TaskList
concat =
    List.foldr append empty



-- TRANSFORM


filter : (TaskItem -> Bool) -> TaskList -> TaskList
filter fn =
    TaskList << List.filter fn << topLevelTasks


foldl : (TaskItem -> b -> b) -> b -> TaskList -> b
foldl fn acc =
    List.foldl fn acc << topLevelTasks


map : (TaskItem -> TaskItem) -> TaskList -> TaskList
map fn =
    TaskList << List.map fn << topLevelTasks


replaceForFile : String -> TaskList -> TaskList -> TaskList
replaceForFile filePath updatedList =
    append updatedList << removeForFile filePath


removeForFile : String -> TaskList -> TaskList
removeForFile filePath =
    TaskList << itemsNotFromFile filePath << topLevelTasks


removeTags : List String -> TaskList -> TaskList
removeTags tags =
    map (TaskItem.removeTags tags)



-- UTILITIES


taskTitles : TaskList -> List String
taskTitles =
    List.map TaskItem.title << topLevelTasks


taskIds : TaskList -> List String
taskIds =
    List.map TaskItem.id << topLevelTasks


taskContainingId : String -> TaskList -> Maybe TaskItem
taskContainingId id =
    LE.find (TaskItem.containsId id) << tasks


taskFromId : String -> TaskList -> Maybe TaskItem
taskFromId id =
    LE.find (\i -> TaskItem.id i == id) << tasks


tasks : TaskList -> List TaskItem
tasks =
    List.concatMap (\t -> t :: TaskItem.descendantTasks t) << topLevelTasks


topLevelTasks : TaskList -> List TaskItem
topLevelTasks (TaskList taskList) =
    taskList



-- PRIVATE


itemsNotFromFile : String -> List TaskItem -> List TaskItem
itemsNotFromFile pathToFile =
    List.filter (\t -> not (TaskItem.isFromFile pathToFile t))


taskItemsHelp : DataviewTaskCompletion -> String -> Maybe String -> TagList -> Int -> List TaskItem -> Parser (P.Step (List TaskItem) (List TaskItem))
taskItemsHelp dataviewTaskCompletion filePath fileDate frontMatterTags bodyOffset revTaskItems =
    P.oneOf
        [ P.backtrackable
            (TaskItem.parser dataviewTaskCompletion filePath fileDate frontMatterTags bodyOffset
                |> P.map (\taskItem -> P.Loop (taskItem :: revTaskItems))
            )
        , anyLineParser
            |> P.map (\_ -> P.Loop revTaskItems)
        , P.succeed ()
            |> P.map (\_ -> P.Done (List.reverse revTaskItems))
        ]
