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


type alias LoginCredentials =
    { email : String
    , password : String
    }



-- Json Decoders


decodeServerResponse : Decoder ServerResponse
decodeServerResponse =
    map2 ServerResponse (field "error" bool) (field "message" string)



-- Json Encoders


encodeLoginCredentials : LoginCredentials -> Value
encodeLoginCredentials login_credentials =
    Encode.object
        [ ( "email", Encode.string login_credentials.email )
        , ( "password", Encode.string login_credentials.password )
        ]



-- Model


type alias Model =
    { login_credentials : LoginCredentials
    , server_response : ServerResponse
    }


initialModel : () -> ( Model, Cmd Msg )
initialModel () =
    ( { login_credentials = LoginCredentials "" ""
      , server_response = ServerResponse False ""
      }
    , Cmd.none
    )



-- All the messages.


type Msg
    = GotServerResponse (Result Http.Error ServerResponse)
    | SubmitCredentials
    | EmailFieldUpdated String
    | PasswordFieldUpdated String



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotServerResponse (Ok response) ->
            ( { model
                | server_response = response
                , login_credentials = LoginCredentials "" ""
              }
            , Cmd.none
            )

        GotServerResponse (Err err) ->
            ( model, Cmd.none )

        SubmitCredentials ->
            ( model
            , Http.post
                { url = "/login/"
                , body = Http.jsonBody <| encodeLoginCredentials model.login_credentials
                , expect = Http.expectJson GotServerResponse decodeServerResponse
                }
            )

        EmailFieldUpdated email ->
            let
                old_login_credentials =
                    model.login_credentials

                new_login_credentials =
                    { old_login_credentials | email = email }
            in
            ( { model
                | login_credentials = new_login_credentials
              }
            , Cmd.none
            )

        PasswordFieldUpdated password ->
            let
                old_login_credentials =
                    model.login_credentials

                new_login_credentials =
                    { old_login_credentials | password = password }
            in
            ( { model
                | login_credentials = new_login_credentials
              }
            , Cmd.none
            )



-- View


viewServerResonse : ServerResponse -> Html.Html Msg
viewServerResonse server_response =
    if server_response.error == True then
        Html.span [ Attributes.class "error-msg", Attributes.style "color" "red" ] [ Html.text server_response.message ]
    else
        Html.span [ Attributes.class "error-msg", Attributes.style "color" "green" ] [ Html.text server_response.message ]


view : Model -> Html.Html Msg
view model =
    Html.div [ Attributes.id "main-section" ]
        [ Html.h1 [ Attributes.id "main-heading" ] [ Html.text "Log in to Trello Clone" ]
        , Html.a [ Attributes.id "go-to-signup", Attributes.href "/signup/" ] [ Html.text "or create an account" ]
        , viewServerResonse model.server_response
        , Html.form [ Attributes.id "login-form", onSubmit SubmitCredentials ]
            [ Html.label []
                [ Html.h3 [ Attributes.class "login-label " ] [ Html.text "Email*" ]
                , Html.input [ Attributes.class "login-input input-style", onInput EmailFieldUpdated, Attributes.value model.login_credentials.email, Attributes.type_ "email", Attributes.name "email", Attributes.placeholder "e.g., harrypotter@hogwarts.org.uk", Attributes.required True ] []
                ]
            , Html.label []
                [ Html.h3 [ Attributes.class "login-label" ] [ Html.text "Password*" ]
                , Html.input [ Attributes.class "login-input", onInput PasswordFieldUpdated, Attributes.value model.login_credentials.password, Attributes.type_ "password", Attributes.name "password", Attributes.placeholder "Enter your password here", Attributes.required True ] []
                ]
            , Html.input [ Attributes.id "submit-btn", Attributes.type_ "submit", Attributes.value "Log Into Your Account" ] []
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
