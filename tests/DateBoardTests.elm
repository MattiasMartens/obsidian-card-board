module DateBoardTests exposing (suite)

import Column
import ColumnNames exposing (ColumnNames)
import DateBoard
import Expect
import Filter
import Helpers.BoardConfigHelpers as BoardConfigHelpers
import Helpers.BoardHelpers as BoardHelpers
import Helpers.DateTimeHelpers as DateTimeHelpers
import Helpers.DecodeHelpers as DecodeHelpers
import Helpers.FilterHelpers as FilterHelpers
import Helpers.TaskListHelpers as TaskListHelpers
import List.Extra as LE
import TagList
import TaskItem
import Test exposing (..)
import TsJson.Encode as TsEncode


suite : Test
suite =
    concat
        [ columns
        , columnCompleted
        , columnUndated
        , encodeDecode
        ]


columns : Test
columns =
    describe "columns"
        [ test "default columns are just today tomorrow and future" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default DateTimeHelpers.nowWithZone defaultConfig
                    |> List.map Column.name
                    |> Expect.equal [ "Today", "Tomorrow", "Future" ]
        , test "default column names can be customised" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns { defaultColumnNames | today = Just "0", tomorrow = Just "1", future = Just "2" } DateTimeHelpers.nowWithZone defaultConfig
                    |> List.map Column.name
                    |> Expect.equal [ "0", "1", "2" ]
        , test "todaysItems are sorted by due date (then task title ascending)" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default DateTimeHelpers.nowWithZone defaultConfig
                    |> BoardHelpers.thingsInColumn "Today"
                    |> List.map TaskItem.title
                    |> Expect.equal [ "another yesterday incomplete", "yesterday incomplete", "today incomplete" ]
        , test "tommorrowsItems are sorted by task title ascending" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default DateTimeHelpers.nowWithZone defaultConfig
                    |> BoardHelpers.thingsInColumn "Tomorrow"
                    |> List.map TaskItem.title
                    |> Expect.equal [ "a task for tomorrow", "tomorrow incomplete" ]
        , test "futureItems are sorted by due date ascending (then task title)" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default DateTimeHelpers.nowWithZone defaultConfig
                    |> BoardHelpers.thingsInColumn "Future"
                    |> List.map TaskItem.title
                    |> Expect.equal [ "future incomplete", "far future incomplete", "zapping into the future" ]
        , test "removes exact matches of tags defined in config.filters from all task items if the config says not to show them" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default
                        DateTimeHelpers.nowWithZone
                        { defaultConfig
                            | filters = [ FilterHelpers.tagFilter "tag1" ]
                            , filterPolarity = Filter.Allow
                            , showFilteredTags = False
                        }
                    |> BoardHelpers.thingsInColumns [ "Future", "Today" ]
                    |> List.map TaskItem.tags
                    |> List.foldl TagList.append TagList.empty
                    |> TagList.toList
                    |> List.sort
                    |> Expect.equal [ "future", "today" ]
        ]


columnCompleted : Test
columnCompleted =
    describe "columnCompleted"
        [ test "a Completed column is appended if config sets includeCompleted" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default DateTimeHelpers.nowWithZone { defaultConfig | completedCount = 1 }
                    |> List.map Column.name
                    |> Expect.equal [ "Today", "Tomorrow", "Future", "Completed" ]
        , test "the Completed column name can be customized" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns { defaultColumnNames | completed = Just "xxx" } DateTimeHelpers.nowWithZone { defaultConfig | completedCount = 1 }
                    |> List.map Column.name
                    |> Expect.equal [ "Today", "Tomorrow", "Future", "xxx" ]
        , test "completedItems are sorted by completion date desc (then task title asc)" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default DateTimeHelpers.nowWithZone { defaultConfig | completedCount = 99 }
                    |> BoardHelpers.thingsInColumn "Completed"
                    |> List.map TaskItem.title
                    |> Expect.equal
                        [ "more undated complete"
                        , "future complete"
                        , "today complete"
                        , "tomorrow complete"
                        , "undated complete"
                        , "yesterday complete"
                        , "far future complete"
                        , "invalid date complete"
                        ]
        , test "removes exact matches of tags defined in config.filters from all task items if the config says not to show them" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default
                        DateTimeHelpers.nowWithZone
                        { defaultConfig
                            | filters = [ FilterHelpers.tagFilter "tag1" ]
                            , filterPolarity = Filter.Allow
                            , showFilteredTags = False
                            , completedCount = 10
                        }
                    |> BoardHelpers.thingsInColumn "Completed"
                    |> List.map TaskItem.tags
                    |> List.foldl TagList.append TagList.empty
                    |> TagList.toList
                    |> List.sort
                    |> Expect.equal [ "invalid", "today" ]
        ]


columnUndated : Test
columnUndated =
    describe "columnUndated"
        [ test "an Undated column is prepended if config sets includeUndated" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default DateTimeHelpers.nowWithZone { defaultConfig | includeUndated = True }
                    |> List.map Column.name
                    |> Expect.equal [ "Undated", "Today", "Tomorrow", "Future" ]
        , test "the Undated column name can be customized" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns { defaultColumnNames | undated = Just "xxx" } DateTimeHelpers.nowWithZone { defaultConfig | includeUndated = True }
                    |> List.map Column.name
                    |> Expect.equal [ "xxx", "Today", "Tomorrow", "Future" ]
        , test "undatedItems are sorted by title ascending" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default DateTimeHelpers.nowWithZone { defaultConfig | includeUndated = True }
                    |> BoardHelpers.thingsInColumn "Undated"
                    |> List.map TaskItem.title
                    |> Expect.equal
                        [ "an undated incomplete"
                        , "incomplete with cTag"
                        , "invalid date incomplete"
                        , "more undated incomplete"
                        , "more undated incomplete with cTag"
                        , "untagged incomplete"
                        ]
        , test "removes exact matches of tags defined in config.filters from all task items if the config says not to show them" <|
            \() ->
                TaskListHelpers.exampleDateBoardTaskList
                    |> DateBoard.columns ColumnNames.default
                        DateTimeHelpers.nowWithZone
                        { defaultConfig
                            | filters = [ FilterHelpers.tagFilter "tag1" ]
                            , filterPolarity = Filter.Allow
                            , showFilteredTags = False
                            , includeUndated = True
                        }
                    |> BoardHelpers.thingsInColumn "Undated"
                    |> List.map TaskItem.tags
                    |> List.foldl TagList.append TagList.empty
                    |> TagList.toList
                    |> List.sort
                    |> LE.unique
                    |> Expect.equal [ "aTag", "bTag", "cTag" ]
        ]


encodeDecode : Test
encodeDecode =
    describe "encoding and decoding config"
        [ test "can decode the encoded string back to the original" <|
            \() ->
                exampleConfig
                    |> TsEncode.runExample DateBoard.configEncoder
                    |> .output
                    |> DecodeHelpers.runDecoder DateBoard.configDecoder_v_0_4_0
                    |> .decoded
                    |> Expect.equal (Ok exampleConfig)
        ]



-- HELPERS


defaultColumnNames : ColumnNames
defaultColumnNames =
    ColumnNames.default


defaultConfig : DateBoard.Config
defaultConfig =
    BoardConfigHelpers.defaultDateBoardConfig


exampleConfig : DateBoard.Config
exampleConfig =
    BoardConfigHelpers.exampleDateBoardConfig
