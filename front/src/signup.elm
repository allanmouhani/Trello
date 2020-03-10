module Main exposing (main)

import Browser
import Html
import Html.Attributes as Attributes
import Html.Events exposing (onClick, onInput, onSubmit)
import Http
import Json.Decode as Decode exposing (Decoder, bool, field, int, list, map2, map3, map4, nullable, string)
import Json.Encode as Encode exposing (Value, null)


type alias ServerResponse =
    { error : Bool
    , message : String
    }


type alias SignupCredentials =
    { email : String
    , name : String
    , password : String
    , password_confirmation : String
    }



-- Json Decoders


decodeServerResponse : Decoder ServerResponse
decodeServerResponse =
    map2 ServerResponse (field "error" bool) (field "message" string)



-- Json Encoders


encodeSignupCredentials : SignupCredentials -> Value
encodeSignupCredentials signup_credentials =
    Encode.object
        [ ( "email", Encode.string signup_credentials.email )
        , ( "name", Encode.string signup_credentials.name )
        , ( "password", Encode.string signup_credentials.password )
        , ( "password_confirmation", Encode.string signup_credentials.password_confirmation )
        ]



-- Model


type alias Model =
    { signup_credentials : SignupCredentials
    , server_response : ServerResponse
    }


initialModel : () -> ( Model, Cmd Msg )
initialModel () =
    ( { signup_credentials = SignupCredentials "" "" "" ""
      , server_response = ServerResponse False ""
      }
    , Cmd.none
    )



-- All the messages.


type Msg
    = GotServerResponse (Result Http.Error ServerResponse)
    | SubmitCredentials
    | EmailFieldUpdated String
    | NameFieldUpdated String
    | PasswordFieldUpdated String



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotServerResponse (Ok response) ->
            ( { model
                | server_response = response
                , signup_credentials = SignupCredentials "" "" "" ""
              }
            , Cmd.none
            )

        GotServerResponse (Err err) ->
            ( model, Cmd.none )

        SubmitCredentials ->
            ( model
            , Http.post
                { url = "/signup/"
                , body = Http.jsonBody <| encodeSignupCredentials model.signup_credentials
                , expect = Http.expectJson GotServerResponse decodeServerResponse
                }
            )

        EmailFieldUpdated email ->
            let
                old_signup_credentials =
                    model.signup_credentials

                new_signup_credentials =
                    { old_signup_credentials | email = email }
            in
            ( { model
                | signup_credentials = new_signup_credentials
              }
            , Cmd.none
            )

        NameFieldUpdated name ->
            let
                old_signup_credentials =
                    model.signup_credentials

                new_signup_credentials =
                    { old_signup_credentials | name = name }
            in
            ( { model
                | signup_credentials = new_signup_credentials
              }
            , Cmd.none
            )

        PasswordFieldUpdated password ->
            let
                old_signup_credentials =
                    model.signup_credentials

                new_signup_credentials =
                    { old_signup_credentials
                        | password = password
                        , password_confirmation = password
                    }
            in
            ( { model
                | signup_credentials = new_signup_credentials
              }
            , Cmd.none
            )



-- View


viewServerResonse : ServerResponse -> Html.Html Msg
viewServerResonse server_response =
    if server_response.error == True then
        Html.h3 [ Attributes.class "error-msg", Attributes.style "color" "red" ] [ Html.text server_response.message ]
    else
        Html.h3 [ Attributes.class "error-msg", Attributes.style "color" "green" ] [ Html.text server_response.message ]


view : Model -> Html.Html Msg
view model =
    Html.section [ Attributes.id "main-section" ]
        [ Html.h1 [ Attributes.id "main-heading" ] [ Html.text "Create a Trello Clone Account" ]
        , Html.a [ Attributes.id "go-to-login", Attributes.href "/login/" ] [ Html.text "or sign in to your account" ]
        , viewServerResonse model.server_response
        , Html.form [ Attributes.id "signup-form", onSubmit SubmitCredentials ]
            [ Html.label []
                [ Html.h3 [ Attributes.class "signup-label" ] [ Html.text "Email*" ]
                , Html.input [ Attributes.class "signup-input input-style", onInput EmailFieldUpdated, Attributes.type_ "email", Attributes.name "email", Attributes.value model.signup_credentials.email, Attributes.placeholder "e.g., harrypotter@hogwarts.org.uk", Attributes.required True ] []
                ]
            , Html.label []
                [ Html.h3 [ Attributes.class "signup-label" ] [ Html.text "Name*" ]
                , Html.input [ Attributes.class "signup-input input-style", onInput NameFieldUpdated, Attributes.pattern "^[a-zA-Z]([ ._-]?[a-zA-Z0-9]+){2,15}$", Attributes.value model.signup_credentials.name, Attributes.type_ "text", Attributes.name "name", Attributes.placeholder "e.g: Harry Potter", Attributes.required True, Attributes.title "e.g., Harry Potter, Bellman-Ford" ] []
                ]
            , Html.label []
                [ Html.h3 [ Attributes.class "signup-label" ] [ Html.text "Password*" ]
                , Html.input [ Attributes.class "signup-input", onInput PasswordFieldUpdated, Attributes.value model.signup_credentials.password, Attributes.type_ "password", Attributes.name "password", Attributes.placeholder "Enter your password here", Attributes.required True ] []
                ]
            , Html.input [ Attributes.id "submit-btn", Attributes.type_ "submit", Attributes.value "Create New Account" ] []
            ]
        ]



-- Main


main : Program () Model Msg
main =
    Browser.element
        { init = initialModel
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }
