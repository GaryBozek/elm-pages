module OptimizedDecoder exposing
    ( decodeString, decodeValue, Value
    , Error, errorToString
    , Decoder, string, bool, int, float
    , nullable, list, array, dict, keyValuePairs
    , field, at, index
    , maybe, oneOf
    , lazy, value, null, succeed, fail, andThen
    , map, map2, map3, map4, map5, map6, map7, map8, andMap
    , decoder
    )

{-| This package presents a somewhat experimental approach to JSON decoding. Its
API looks very much like the core `Json.Decode` API. The major differences are
the final `decodeString` and `decodeValue` functions, which return a
`DecodeResult a`.

Decoding with this library can result in one of 4 possible outcomes:

  - The input wasn't valid JSON
  - One or more errors occurred
  - Decoding succeeded but produced warnings
  - Decoding succeeded without warnings

Both the `Errors` and `Warnings` types are (mostly) machine readable: they are
implemented as a recursive data structure that points to the location of the
error in the input json, producing information about what went wrong (i.e. "what
was the expected type, and what did the actual value look like").

Further, this library also adds a few extra `Decoder`s that help with making
assertions about the structure of the JSON while decoding.

For convenience, this library also includes a `Json.Decode.Exploration.Pipeline`
module which is largely a copy of [`NoRedInk/elm-decode-pipeline`][edp].

[edp]: http://package.elm-lang.org/packages/NoRedInk/elm-decode-pipeline/latest


# Running a `Decoder`

Runing a `Decoder` works largely the same way as it does in the familiar core
library. There is one serious caveat, however:

> This library does **not** allowing decoding non-serializable JS values.

This means that trying to use this library to decode a `Value` which contains
non-serializable information like `function`s will not work. It will, however,
result in a `BadJson` result.

Trying to use this library on cyclic values (like HTML events) is quite likely
to blow up completely. Don't try this, except maybe at home.

@docs decodeString, decodeValue, strict, DecodeResult, Value


## Dealing with warnings and errors

@docs Error, errorToString


# Primitives

@docs Decoder, string, bool, int, float


# Data Structures

@docs nullable, list, array, dict, keyValuePairs


# Object Primitives

@docs field, at, index


# Inconsistent Structure

@docs maybe, oneOf


# Fancy Decoding

@docs lazy, value, null, succeed, fail, andThen


# Mapping

**Note:** If you run out of map functions, take a look at [the pipeline module][pipe]
which makes it easier to handle large objects.

[pipe]: http://package.elm-lang.org/packages/zwilias/json-decode-exploration/latest/Json-Decode-Exploration-Pipeline

@docs map, map2, map3, map4, map5, map6, map7, map8, andMap


# Directly Running Decoders

Usually you'll be passing your decoders to

@docs decodeString, decodeValue, decoder

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Internal.OptimizedDecoder exposing (OptimizedDecoder(..))
import Json.Decode as JD
import Json.Decode.Exploration as JDE


type alias Decoder a =
    OptimizedDecoder a


{-| A simple type alias for `Json.Decode.Value`.
-}
type alias Value =
    JD.Value


{-| A simple type alias for `Json.Decode.Error`.
-}
type alias Error =
    JD.Error


{-| A simple wrapper for `Json.Decode.errorToString`.
-}
errorToString : JD.Error -> String
errorToString =
    JD.errorToString


{-| Usually you'll want to directly pass your `OptimizedDecoder` to `StaticHttp` or other `elm-pages` APIs.
But if you want to re-use your decoder somewhere else, it may be useful to turn it into a plain `elm/json` decoder.
-}
decoder : Decoder a -> JD.Decoder a
decoder (OptimizedDecoder jd jde) =
    jd


{-| A simple wrapper for `Json.Decode.errorToString`.

This will directly call the raw `elm/json` decoder that is stored under the hood.

-}
decodeString : Decoder a -> String -> Result Error a
decodeString (OptimizedDecoder jd jde) =
    JD.decodeString jd


{-| A simple wrapper for `Json.Decode.errorToString`.

This will directly call the raw `elm/json` decoder that is stored under the hood.

-}
decodeValue : Decoder a -> Value -> Result Error a
decodeValue (OptimizedDecoder jd jde) =
    JD.decodeValue jd


{-| A decoder that will ignore the actual JSON and succeed with the provided
value. Note that this may still fail when dealing with an invalid JSON string.

If a value in the JSON ends up being ignored because of this, this will cause a
warning.

    import List.Nonempty exposing (Nonempty(..))
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode


    """ null """
        |> decodeString (value |> andThen (\_ -> succeed "hello world"))
    --> Success "hello world"


    """ null """
        |> decodeString (succeed "hello world")
    --> WithWarnings
    -->     (Nonempty (Here <| UnusedValue Encode.null) [])
    -->     "hello world"


    """ foo """
        |> decodeString (succeed "hello world")
    --> BadJson

-}
succeed : a -> Decoder a
succeed a =
    OptimizedDecoder (JD.succeed a) (JDE.succeed a)


{-| Ignore the json and fail with a provided message.

    import List.Nonempty exposing (Nonempty(..))
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode

    """ "hello" """
        |> decodeString (fail "failure")
    --> Errors (Nonempty (Here <| Failure "failure" (Just <| Encode.string "hello")) [])

-}
fail : String -> Decoder a
fail message =
    OptimizedDecoder (JD.fail message) (JDE.fail message)


{-| Decode a string.

    import List.Nonempty exposing (Nonempty(..))
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode


    """ "hello world" """
        |> decodeString string
    --> Success "hello world"


    """ 123 """
        |> decodeString string
    --> Errors (Nonempty (Here <| Expected TString (Encode.int 123)) [])

-}
string : Decoder String
string =
    OptimizedDecoder JD.string JDE.string


{-| Extract a piece without actually decoding it.

If a structure is decoded as a `value`, everything _in_ the structure will be
considered as having been used and will not appear in `UnusedValue` warnings.

    import Json.Encode as Encode


    """ [ 123, "world" ] """
        |> decodeString value
    --> Success (Encode.list identity [ Encode.int 123, Encode.string "world" ])

-}
value : Decoder Value
value =
    OptimizedDecoder JD.value JDE.value


{-| Decode a number into a `Float`.

    import List.Nonempty exposing (Nonempty(..))
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode


    """ 12.34 """
        |> decodeString float
    --> Success 12.34


    """ 12 """
        |> decodeString float
    --> Success 12


    """ null """
        |> decodeString float
    --> Errors (Nonempty (Here <| Expected TNumber Encode.null) [])

-}
float : Decoder Float
float =
    OptimizedDecoder JD.float JDE.float


{-| Decode a number into an `Int`.

    import List.Nonempty exposing (Nonempty(..))
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode


    """ 123 """
        |> decodeString int
    --> Success 123


    """ 0.1 """
        |> decodeString int
    --> Errors <|
    -->   Nonempty
    -->     (Here <| Expected TInt (Encode.float 0.1))
    -->     []

-}
int : Decoder Int
int =
    OptimizedDecoder JD.int JDE.int


{-| Decode a boolean value.

    """ [ true, false ] """
        |> decodeString (list bool)
    --> Success [ True, False ]

-}
bool : Decoder Bool
bool =
    OptimizedDecoder JD.bool JDE.bool


{-| Decode a `null` and succeed with some value.

    """ null """
        |> decodeString (null "it was null")
    --> Success "it was null"

Note that `undefined` and `null` are not the same thing. This cannot be used to
verify that a field is _missing_, only that it is explicitly set to `null`.

    """ { "foo": null } """
        |> decodeString (field "foo" (null ()))
    --> Success ()


    import List.Nonempty exposing (Nonempty(..))
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode


    """ { } """
        |> decodeString (field "foo" (null ()))
    --> Errors <|
    -->   Nonempty
    -->     (Here <| Expected (TObjectField "foo") (Encode.object []))
    -->     []

-}
null : a -> Decoder a
null val =
    OptimizedDecoder (JD.null val) (JDE.null val)


{-| Decode a list of values, decoding each entry with the provided decoder.

    import List.Nonempty exposing (Nonempty(..))
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode


    """ [ "foo", "bar" ] """
        |> decodeString (list string)
    --> Success [ "foo", "bar" ]


    """ [ "foo", null ] """
        |> decodeString (list string)
    --> Errors <|
    -->   Nonempty
    -->     (AtIndex 1 <|
    -->       Nonempty (Here <| Expected TString Encode.null) []
    -->     )
    -->     []

-}
list : Decoder a -> Decoder (List a)
list (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.list jd) (JDE.list jde)


{-| _Convenience function._ Decode a JSON array into an Elm `Array`.

    import Array

    """ [ 1, 2, 3 ] """
        |> decodeString (array int)
    --> Success <| Array.fromList [ 1, 2, 3 ]

-}
array : Decoder a -> Decoder (Array a)
array (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.array jd) (JDE.array jde)


{-| _Convenience function._ Decode a JSON object into an Elm `Dict String`.

    import Dict


    """ { "foo": "bar", "bar": "hi there" } """
        |> decodeString (dict string)
    --> Success <| Dict.fromList
    -->   [ ( "bar", "hi there" )
    -->   , ( "foo", "bar" )
    -->   ]

-}
dict : Decoder v -> Decoder (Dict String v)
dict (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.dict jd) (JDE.dict jde)


{-| Decode a specific index using a specified `Decoder`.

    import List.Nonempty exposing (Nonempty(..))
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode


    """ [ "hello", 123 ] """
        |> decodeString (map2 Tuple.pair (index 0 string) (index 1 int))
    --> Success ( "hello", 123 )


    """ [ "hello", "there" ] """
        |> decodeString (index 1 string)
    --> WithWarnings (Nonempty (AtIndex 0 (Nonempty (Here (UnusedValue (Encode.string "hello"))) [])) [])
    -->   "there"

-}
index : Int -> Decoder a -> Decoder a
index idx (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.index idx jd) (JDE.index idx jde)


{-| Decode a JSON object into a list of key-value pairs. The decoder you provide
will be used to decode the values.

    """ { "foo": "bar", "hello": "world" } """
        |> decodeString (keyValuePairs string)
    --> Success [ ( "foo", "bar" ), ( "hello", "world" ) ]

-}
keyValuePairs : Decoder a -> Decoder (List ( String, a ))
keyValuePairs (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.keyValuePairs jd) (JDE.keyValuePairs jde)


{-| Decode the content of a field using a provided decoder.

    import List.Nonempty as Nonempty
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode

    """ { "foo": "bar" } """
        |> decodeString (field "foo" string)
    --> Success "bar"


    """ [ { "foo": "bar" }, { "foo": "baz", "hello": "world" } ] """
        |> decodeString (list (field "foo" string))
    --> WithWarnings expectedWarnings [ "bar", "baz" ]


    expectedWarnings : Warnings
    expectedWarnings =
        UnusedField "hello"
            |> Here
            |> Nonempty.fromElement
            |> AtIndex 1
            |> Nonempty.fromElement

-}
field : String -> Decoder a -> Decoder a
field fieldName (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.field fieldName jd) (JDE.field fieldName jde)


{-| Decodes a value at a certain path, using a provided decoder. Essentially,
writing `at [ "a", "b", "c" ]  string` is sugar over writing
`field "a" (field "b" (field "c" string))`}.

    """ { "a": { "b": { "c": "hi there" } } } """
        |> decodeString (at [ "a", "b", "c" ] string)
    --> Success "hi there"

-}
at : List String -> Decoder a -> Decoder a
at fields (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.at fields jd) (JDE.at fields jde)



-- Choosing


{-| Tries a bunch of decoders. The first one to not fail will be the one used.

If all fail, the errors are collected into a `BadOneOf`.

    import List.Nonempty as Nonempty
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode

    """ [ 12, "whatever" ] """
        |> decodeString (list <| oneOf [ map String.fromInt int, string ])
    --> Success [ "12", "whatever" ]


    """ null """
        |> decodeString (oneOf [ string, map String.fromInt int ])
    --> Errors <| Nonempty.fromElement <| Here <| BadOneOf
    -->   [ Nonempty.fromElement <| Here <| Expected TString Encode.null
    -->   , Nonempty.fromElement <| Here <| Expected TInt Encode.null
    -->   ]

-}
oneOf : List (Decoder a) -> Decoder a
oneOf decoders =
    let
        jds =
            List.map
                (\(OptimizedDecoder jd jde) ->
                    jd
                )
                decoders

        jdes =
            List.map
                (\(OptimizedDecoder jd jde) ->
                    jde
                )
                decoders
    in
    OptimizedDecoder (JD.oneOf jds) (JDE.oneOf jdes)


{-| Decodes successfully and wraps with a `Just`, handling failure by succeeding
with `Nothing`.

    import List.Nonempty as Nonempty
    import Json.Decode.Exploration.Located exposing (Located(..))
    import Json.Encode as Encode


    """ [ "foo", 12 ] """
        |> decodeString (list <| maybe string)
    --> WithWarnings expectedWarnings [ Just "foo", Nothing ]


    expectedWarnings : Warnings
    expectedWarnings =
        UnusedValue (Encode.int 12)
            |> Here
            |> Nonempty.fromElement
            |> AtIndex 1
            |> Nonempty.fromElement

-}
maybe : Decoder a -> Decoder (Maybe a)
maybe (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.maybe jd) (JDE.maybe jde)


{-| Decodes successfully and wraps with a `Just`. If the values is `null`
succeeds with `Nothing`.

    """ [ { "foo": "bar" }, { "foo": null } ] """
        |> decodeString (list <| field "foo" <| nullable string)
    --> Success [ Just "bar", Nothing ]

-}
nullable : Decoder a -> Decoder (Maybe a)
nullable (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.nullable jd) (JDE.nullable jde)



--


{-| Required when using (mutually) recursive decoders.
-}
lazy : (() -> Decoder a) -> Decoder a
lazy toDecoder =
    lazy toDecoder



--Debug.todo ""
--Decoder <|
--    \json ->
--        let
--            (Decoder decoderFn) =
--                toDecoder ()
--        in
--        decoderFn json
-- Extras


{-| Useful for checking a value in the JSON matches the value you expect it to
have. If it does, succeeds with the second decoder. If it doesn't it fails.

This can be used to decode union types:

    type Pet = Cat | Dog | Rabbit

    petDecoder : Decoder Pet
    petDecoder =
        oneOf
            [ check string "cat" <| succeed Cat
            , check string "dog" <| succeed Dog
            , check string "rabbit" <| succeed Rabbit
            ]

    """ [ "dog", "rabbit", "cat" ] """
        |> decodeString (list petDecoder)
    --> Success [ Dog, Rabbit, Cat ]

-}
check : Decoder a -> a -> Decoder b -> Decoder b
check checkDecoder expectedVal actualDecoder =
    checkDecoder
        |> andThen
            (\actual ->
                if actual == expectedVal then
                    actualDecoder

                else
                    fail "Verification failed"
            )



-- Mapping and chaining


{-| Useful for transforming decoders.

    """ "foo" """
        |> decodeString (map String.toUpper string)
    --> Success "FOO"

-}
map : (a -> b) -> Decoder a -> Decoder b
map f (OptimizedDecoder jd jde) =
    OptimizedDecoder (JD.map f jd) (JDE.map f jde)


{-| Chain decoders where one decoder depends on the value of another decoder.
-}
andThen : (a -> Decoder b) -> Decoder a -> Decoder b
andThen toDecoderB (OptimizedDecoder jd jde) =
    OptimizedDecoder
        (JD.andThen (toDecoderB >> Internal.OptimizedDecoder.jd) jd)
        (JDE.andThen (toDecoderB >> Internal.OptimizedDecoder.jde) jde)


{-| Combine 2 decoders.
-}
map2 : (a -> b -> c) -> Decoder a -> Decoder b -> Decoder c
map2 f (OptimizedDecoder jdA jdeA) (OptimizedDecoder jdB jdeB) =
    OptimizedDecoder
        (JD.map2 f jdA jdB)
        (JDE.map2 f jdeA jdeB)


{-| Decode an argument and provide it to a function in a decoder.

    decoder : Decoder String
    decoder =
        succeed (String.repeat)
            |> andMap (field "count" int)
            |> andMap (field "val" string)


    """ { "val": "hi", "count": 3 } """
        |> decodeString decoder
    --> Success "hihihi"

-}
andMap : Decoder a -> Decoder (a -> b) -> Decoder b
andMap =
    map2 (|>)


{-| Combine 3 decoders.
-}
map3 :
    (a -> b -> c -> d)
    -> Decoder a
    -> Decoder b
    -> Decoder c
    -> Decoder d
map3 f decoderA decoderB decoderC =
    map f decoderA
        |> andMap decoderB
        |> andMap decoderC


{-| Combine 4 decoders.
-}
map4 :
    (a -> b -> c -> d -> e)
    -> Decoder a
    -> Decoder b
    -> Decoder c
    -> Decoder d
    -> Decoder e
map4 f decoderA decoderB decoderC decoderD =
    map f decoderA
        |> andMap decoderB
        |> andMap decoderC
        |> andMap decoderD


{-| Combine 5 decoders.
-}
map5 :
    (a -> b -> c -> d -> e -> f)
    -> Decoder a
    -> Decoder b
    -> Decoder c
    -> Decoder d
    -> Decoder e
    -> Decoder f
map5 f decoderA decoderB decoderC decoderD decoderE =
    map f decoderA
        |> andMap decoderB
        |> andMap decoderC
        |> andMap decoderD
        |> andMap decoderE


{-| Combine 6 decoders.
-}
map6 :
    (a -> b -> c -> d -> e -> f -> g)
    -> Decoder a
    -> Decoder b
    -> Decoder c
    -> Decoder d
    -> Decoder e
    -> Decoder f
    -> Decoder g
map6 f decoderA decoderB decoderC decoderD decoderE decoderF =
    map f decoderA
        |> andMap decoderB
        |> andMap decoderC
        |> andMap decoderD
        |> andMap decoderE
        |> andMap decoderF


{-| Combine 7 decoders.
-}
map7 :
    (a -> b -> c -> d -> e -> f -> g -> h)
    -> Decoder a
    -> Decoder b
    -> Decoder c
    -> Decoder d
    -> Decoder e
    -> Decoder f
    -> Decoder g
    -> Decoder h
map7 f decoderA decoderB decoderC decoderD decoderE decoderF decoderG =
    map f decoderA
        |> andMap decoderB
        |> andMap decoderC
        |> andMap decoderD
        |> andMap decoderE
        |> andMap decoderF
        |> andMap decoderG


{-| Combine 8 decoders.
-}
map8 :
    (a -> b -> c -> d -> e -> f -> g -> h -> i)
    -> Decoder a
    -> Decoder b
    -> Decoder c
    -> Decoder d
    -> Decoder e
    -> Decoder f
    -> Decoder g
    -> Decoder h
    -> Decoder i
map8 f decoderA decoderB decoderC decoderD decoderE decoderF decoderG decoderH =
    map f decoderA
        |> andMap decoderB
        |> andMap decoderC
        |> andMap decoderD
        |> andMap decoderE
        |> andMap decoderF
        |> andMap decoderG
        |> andMap decoderH
