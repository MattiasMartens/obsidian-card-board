module DateBoardTests exposing (suite)

import DateBoard exposing (DateBoard)
import Expect
import Iso8601
import Parser
import TaskItem exposing (TaskItem)
import TaskList exposing (TaskList)
import Test exposing (..)
import Time


suite : Test
suite =
    concat
        [ columns
        , columnUndated
        ]


columns : Test
columns =
    describe "columns"
        [ test "default columns are just today tomorrow and future" <|
            \() ->
                parsedFiles
                    |> DateBoard.fill defaultConfig
                    |> DateBoard.columns now zone
                    |> List.map Tuple.first
                    |> Expect.equal [ "Today", "Tomorrow", "Future", "Done" ]
        , test "todaysItems are sorted by filePath ascending" <|
            \() ->
                parsedFiles
                    |> DateBoard.fill defaultConfig
                    |> DateBoard.columns now zone
                    |> tasksInColumn "Today"
                    |> List.map TaskItem.title
                    |> Expect.equal [ "yesterday incomplete", "today incomplete" ]
        , test "tommorrowsItems" <|
            \() ->
                parsedFiles
                    |> DateBoard.fill defaultConfig
                    |> DateBoard.columns now zone
                    |> tasksInColumn "Tomorrow"
                    |> List.map TaskItem.title
                    |> Expect.equal [ "tomorrow incomplete" ]
        , test "futureItems are sorted by due date ascending" <|
            \() ->
                parsedFiles
                    |> DateBoard.fill defaultConfig
                    |> DateBoard.columns now zone
                    |> tasksInColumn "Future"
                    |> List.map TaskItem.title
                    |> Expect.equal [ "future incomplete", "far future incomplete" ]
        , test "completedItems are sorted by completion date desc (then filePath asc)" <|
            \() ->
                parsedFiles
                    |> DateBoard.fill defaultConfig
                    |> DateBoard.columns now zone
                    |> tasksInColumn "Done"
                    |> List.map TaskItem.title
                    |> Expect.equal
                        [ "undated complete"
                        , "yesterday complete"
                        , "invalid date complete"
                        , "future complete"
                        , "far future complete"
                        , "tomorrow complete"
                        , "today complete"
                        ]
        ]


columnUndated : Test
columnUndated =
    describe "columnUndated"
        [ test "an Undated column is prepended if config sets includeUndated" <|
            \() ->
                parsedFiles
                    |> DateBoard.fill { defaultConfig | includeUndated = True }
                    |> DateBoard.columns now zone
                    |> List.map Tuple.first
                    |> Expect.equal [ "Undated", "Today", "Tomorrow", "Future", "Done" ]
        , test "undatedItems are sorted by filePath ascending" <|
            \() ->
                parsedFiles
                    |> DateBoard.fill { defaultConfig | includeUndated = True }
                    |> DateBoard.columns now zone
                    |> tasksInColumn "Undated"
                    |> List.map TaskItem.title
                    |> Expect.equal [ "invalid date incomplete", "undated incomplete" ]
        ]



-- HELPERS


defaultConfig : DateBoard.Config
defaultConfig =
    { includeUndated = False
    }


tasksInColumn : String -> List ( String, List TaskItem ) -> List TaskItem
tasksInColumn columnName tasksInColumns =
    tasksInColumns
        |> List.filter (\( c, ts ) -> c == columnName)
        |> List.concatMap Tuple.second


yesterday : String
yesterday =
    "2020-06-19"


today : String
today =
    "2020-06-20"


tomorrow : String
tomorrow =
    "2020-06-21"


future : String
future =
    "2020-06-22"


farFuture : String
farFuture =
    "2020-06-23"


now : Time.Posix
now =
    today
        |> Iso8601.toTime
        |> Result.map Time.posixToMillis
        |> Result.withDefault 0
        |> Time.millisToPosix


zone : Time.Zone
zone =
    Time.utc


parsedFiles : TaskList
parsedFiles =
    taskFiles
        |> List.map parsedTasks
        |> TaskList.concat


parsedTasks : ( String, Maybe String, String ) -> TaskList
parsedTasks ( p, d, ts ) =
    Parser.run (TaskList.parser p d) ts
        |> Result.withDefault TaskList.empty


taskFiles : List ( String, Maybe String, String )
taskFiles =
    [ undatedTasks
    , ( "d", Just farFuture, """
- [ ] far future incomplete
- [x] far future complete
""" )
    , ( "e", Just future, """
- [ ] future incomplete
- [x] future complete
""" )
    , ( "c", Just tomorrow, """
- [ ] tomorrow incomplete
- [x] tomorrow complete
""" )
    , ( "b", Just today, """
- [ ] today incomplete
- [x] today complete
""" )
    , yesterdaysTasks
    , ( "f", Just "invalid date", """
- [ ] invalid date incomplete
- [x] invalid date complete
""" )
    ]


undatedTasks : ( String, Maybe String, String )
undatedTasks =
    ( "g", Nothing, """
- [ ] undated incomplete
- [x] undated complete @done(2020-06-02)
""" )


yesterdaysTasks : ( String, Maybe String, String )
yesterdaysTasks =
    ( "a", Just yesterday, """
- [ ] yesterday incomplete
- [x] yesterday complete @done(2020-06-01)
""" )
