module Data.Author exposing (Author, all, decoder, view)

import Element exposing (Element)
import Html.Attributes as Attr
import Json.Decode as Decode exposing (Decoder)
import List.Extra
import Pages.Path as Path exposing (Path)
import PagesNew


type alias Author =
    { name : String
    , avatar : Path PagesNew.PathKey Path.ToImage
    , bio : String
    }


all : List Author
all =
    [ { name = "Dillon Kearns"
      , avatar = PagesNew.images.dillon
      , bio = "Elm developer and educator. Founder of Incremental Elm Consulting."
      }
    ]


decoder : Decoder Author
decoder =
    Decode.string
        |> Decode.andThen
            (\lookupName ->
                case List.Extra.find (\currentAuthor -> currentAuthor.name == lookupName) all of
                    Just author ->
                        Decode.succeed author

                    Nothing ->
                        Decode.fail ("Couldn't find author with name " ++ lookupName ++ ". Options are " ++ String.join ", " (List.map .name all))
            )


view : Author -> Element msg
view author =
    Element.image
        [ Element.width (Element.px 70)
        , Element.htmlAttribute (Attr.class "avatar")
        ]
        { src = Path.toString author.avatar, description = author.name }