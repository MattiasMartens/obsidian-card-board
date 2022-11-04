module TagTests exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Parser exposing ((|.), (|=))
import Tag
import Test exposing (..)


suite : Test
suite =
    concat
        [ equals
        , parser
        , startsWith
        , toString
        ]


equals : Test
equals =
    describe "equals"
        [ test "returns True if the tag matches (excluding the #)" <|
            \() ->
                "#foo-bar"
                    |> Parser.run Tag.parser
                    |> Result.map (Tag.equals "foo-bar")
                    |> Expect.equal (Ok True)
        , test "returns False if the tag only matches the start (excluding the #)" <|
            \() ->
                "#foo-bar"
                    |> Parser.run Tag.parser
                    |> Result.map (Tag.equals "foo-ba")
                    |> Expect.equal (Ok False)
        ]


parser : Test
parser =
    describe "parser"
        [ test "parses '#foo-bar'" <|
            \() ->
                "#foo-bar"
                    |> Parser.run Tag.parser
                    |> Result.map Tag.toString
                    |> Expect.equal (Ok "foo-bar")
        , test "parses '#foo_bar'" <|
            \() ->
                "#foo_bar"
                    |> Parser.run Tag.parser
                    |> Result.map Tag.toString
                    |> Expect.equal (Ok "foo_bar")
        , test "parses '#foo/bar'" <|
            \() ->
                "#foo/bar"
                    |> Parser.run Tag.parser
                    |> Result.map Tag.toString
                    |> Expect.equal (Ok "foo/bar")
        , fuzz validTagContentFuzzer "parses all valid tags that start with '#'" <|
            \fuzzedTag ->
                ("#" ++ fuzzedTag)
                    |> Parser.run Tag.parser
                    |> Result.map Tag.toString
                    |> Expect.equal (Ok fuzzedTag)
        , test "can parse multiple tags" <|
            \() ->
                "#foo/bar #baz"
                    |> Parser.run
                        (Parser.succeed (\first second -> ( first, second ))
                            |= Tag.parser
                            |. Parser.token " "
                            |= Tag.parser
                        )
                    |> Result.map (\r -> Tuple.mapFirst Tag.toString r)
                    |> Result.map (\r -> Tuple.mapSecond Tag.toString r)
                    |> Expect.equal (Ok ( "foo/bar", "baz" ))
        , test "fails with an empty string" <|
            \() ->
                ""
                    |> Parser.run Tag.parser
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "fails with just a '#'" <|
            \() ->
                "#"
                    |> Parser.run Tag.parser
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "fails with a '#as@r'" <|
            \() ->
                "#as@r"
                    |> Parser.run Tag.parser
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , fuzz validTagContentFuzzer "fails with strings that don't start with '#'" <|
            \fuzzedTag ->
                fuzzedTag
                    |> Parser.run Tag.parser
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , fuzz stringWithInvalidCharacters "fails for tags consitting of invalid characters" <|
            \fuzzedTag ->
                ("#" ++ fuzzedTag)
                    |> Parser.run Tag.parser
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , fuzz numericStringFuzzer "fails for tags containing only digits" <|
            \fuzzedTag ->
                ("#" ++ fuzzedTag)
                    |> Parser.run Tag.parser
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        ]


startsWith : Test
startsWith =
    describe "startsWith"
        [ test "returns True if the tag starts with the given string (not including the #" <|
            \() ->
                "#FOO-Bar"
                    |> Parser.run Tag.parser
                    |> Result.map (Tag.startsWith "FOO")
                    |> Expect.equal (Ok True)
        , test "returns False if the tag wdoes NOT start with the given string (not including the #" <|
            \() ->
                "#FOO-Bar"
                    |> Parser.run Tag.parser
                    |> Result.map (Tag.startsWith "OO")
                    |> Expect.equal (Ok False)
        ]


toString : Test
toString =
    describe "toString"
        [ test "preserves the case of tags" <|
            \() ->
                "#FOO-Bar"
                    |> Parser.run Tag.parser
                    |> Result.map Tag.toString
                    |> Expect.equal (Ok "FOO-Bar")
        ]



-- HELPERS


stringWithInvalidCharacters : Fuzzer String
stringWithInvalidCharacters =
    let
        dropValidCharacters : String -> String
        dropValidCharacters a =
            String.toList a
                |> List.filter (not << isValidTagCharacter)
                |> String.fromList

        ensureNotEmpty : String -> String
        ensureNotEmpty a =
            if String.length a == 0 then
                "!"

            else
                a
    in
    Fuzz.string
        |> Fuzz.map dropValidCharacters
        |> Fuzz.map ensureNotEmpty


numericStringFuzzer : Fuzzer String
numericStringFuzzer =
    Fuzz.map String.fromInt Fuzz.int


validTagContentFuzzer : Fuzzer String
validTagContentFuzzer =
    let
        dropInvalidCharacters : String -> String
        dropInvalidCharacters a =
            String.toList a
                |> List.filter isValidTagCharacter
                |> String.fromList

        ensureNotEmpty : String -> String
        ensureNotEmpty a =
            if String.length a == 0 then
                "a"

            else
                a

        ensureNotNumeric : String -> String
        ensureNotNumeric a =
            case String.toInt a of
                Just _ ->
                    "a"

                Nothing ->
                    a
    in
    Fuzz.string
        |> Fuzz.map dropInvalidCharacters
        |> Fuzz.map ensureNotEmpty
        |> Fuzz.map ensureNotNumeric


isValidTagCharacter : Char -> Bool
isValidTagCharacter c =
    if Char.isAlphaNum c then
        True

    else if List.member c [ '_', '-', '/' ] then
        True

    else
        False