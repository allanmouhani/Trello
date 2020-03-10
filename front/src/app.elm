module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html
import Html.Attributes as Attributes
import Html.Events exposing (on, onClick, onInput, onSubmit, preventDefaultOn)
import Http
import Json.Decode as Decode exposing (Decoder, bool, field, int, list, map, map2, map3, map4, map5, map6, nullable, string)
import Json.Encode as Encode exposing (Value, null)
import Url



-- Types


type alias Task =
    { id : Int
    , description : String
    , column_id : Int
    }


type alias Column =
    { id : Int
    , name : String
    , table_id : Int
    , tasks : Maybe (List Task)
    }


type alias Member =
    { id : Int
    , table_id : Int
    , member_email : String
    , member_role : String
    }


type alias Table =
    { id : Int
    , name : String
    , creator : String
    , columns : Maybe (List Column)
    , members : Maybe (List Member)
    , current_user_role : String
    }


type alias User =
    { useremail : String
    , username : String
    }


type alias ServerResponse =
    { error : Bool
    , message : String
    , clear : Bool
    }



-- This type represents the current state of the application
-- it affects the view i.e what the user sees


type APPLICATION_STATE
    = State_PrivateTables
    | State_TablesSharedWithOthers
    | State_TablesSharedWithMe
    | State_ViewPrivateTable
    | State_ViewTableSharedWithOthers
    | State_ViewTableSharedWithMe
    | State_ViewMemberOptions



{- State_ViewMemberOptions -}
-- Json Encoders


encodeTask : Task -> Value
encodeTask task =
    Encode.object
        [ ( "id", Encode.int task.id )
        , ( "description", Encode.string task.description )
        , ( "column_id", Encode.int task.column_id )
        ]


encodeColumn : Column -> Value
encodeColumn column =
    case column.tasks of
        Just tasks ->
            Encode.object
                [ ( "id", Encode.int column.id )
                , ( "name", Encode.string column.name )
                , ( "table_id", Encode.int column.table_id )
                , ( "tasks", Encode.list encodeTask tasks )
                ]

        Nothing ->
            Encode.object
                [ ( "id", Encode.int column.id )
                , ( "name", Encode.string column.name )
                , ( "table_id", Encode.int column.table_id )
                , ( "tasks", null )
                ]


encodeMember : Member -> Value
encodeMember member =
    Encode.object
        [ ( "id", Encode.int member.id )
        , ( "table_id", Encode.int member.table_id )
        , ( "member_email", Encode.string member.member_email )
        , ( "member_role", Encode.string member.member_role )
        ]



-- Json Decoders


decodeTask : Decoder Task
decodeTask =
    map3 Task (field "id" int) (field "description" string) (field "column_id" int)


decodeColumn : Decoder Column
decodeColumn =
    map4 Column (field "id" int) (field "name" string) (field "table_id" int) (field "tasks" (nullable (list decodeTask)))


decodeMember : Decoder Member
decodeMember =
    map4 Member (field "id" int) (field "table_id" int) (field "member_email" string) (field "member_role" string)


decodeTable : Decoder Table
decodeTable =
    map6 Table (field "id" int) (field "name" string) (field "creator" string) (field "columns" (nullable (list decodeColumn))) (field "members" (nullable (list decodeMember))) (field "current_user_role" string)


decodeUser : Decoder User
decodeUser =
    map2 User (field "useremail" string) (field "username" string)


decodeServerResponse : Decoder ServerResponse
decodeServerResponse =
    map3 ServerResponse (field "error" bool) (field "message" string) (field "clear" bool)


decodePrivateTables : Decoder (List String)
decodePrivateTables =
    field "private_tables" (list string)


decodeTablesSharedWithOthers : Decoder (List String)
decodeTablesSharedWithOthers =
    field "tables_shared_with_others" (list string)


decodeTablesSharedWithMe : Decoder (List String)
decodeTablesSharedWithMe =
    field "tables_shared_with_me" (list string)


getServerResponse : String -> String
getServerResponse chunk =
    if not (List.isEmpty (String.indexes "{" chunk)) && not (List.isEmpty (String.indexes "}" chunk)) then
        String.slice (Maybe.withDefault 0 (List.head (String.indexes "{" chunk))) (Maybe.withDefault (String.length chunk - 1) (List.head (List.drop (List.length (String.indexes "}" chunk) - 1) (String.indexes "}" chunk))) + 1) chunk

    else
        chunk



-- Drag Events Handlers


onDragStart msg =
    on "dragstart" <|
        Decode.succeed msg


onDragEnd msg =
    on "dragend" <|
        Decode.succeed msg


onDragOver msg =
    preventDefaultOn "dragover" <|
        Decode.succeed ( msg, True )


onDrop msg =
    preventDefaultOn "drop" <|
        Decode.succeed ( msg, True )



-- Model


type alias Model =
    { application_state : APPLICATION_STATE
    , last_application_state : APPLICATION_STATE
    , private_tables : List String
    , tables_shared_with_others : List String
    , tables_shared_with_me : List String
    , current_table : Maybe Table
    , taskBeingDragged : Maybe Task
    , user : User
    , server_response : ServerResponse
    , key : Nav.Key
    , url : Url.Url
    , input_field_table : String
    , input_field_column : String
    , input_field_task : String
    , input_field_addmember : String
    }


initialModel : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
initialModel flags url key =
    ( { application_state = State_PrivateTables
      , last_application_state = State_PrivateTables
      , private_tables = []
      , tables_shared_with_others = []
      , tables_shared_with_me = []
      , current_table = Nothing
      , taskBeingDragged = Nothing
      , user = User "" ""
      , server_response = ServerResponse False "" False
      , key = key
      , url = url
      , input_field_table = ""
      , input_field_column = ""
      , input_field_task = ""
      , input_field_addmember = ""
      }
    , Http.get
        { url = "/users/get-current-user/"
        , expect = Http.expectJson GotUser decodeUser
        }
    )



-- All the messages.


type Msg
    = GoToPrivateTables
    | GoToTablesSharedWithMe
    | GoToTablesSharedWithOthers
    | GotUser (Result Http.Error User)
    | GotPrivateTables (Result Http.Error (List String))
    | GotTable (Result Http.Error Table)
    | AddPrivateTable
    | AddColumn
    | AddTask
    | AddMember
    | RenameTable
    | PrivateTableFieldUpdated String
    | ColumnFieldUpdated String
    | TaskFieldUpdated String
    | AddMemberFieldUpdated String
    | DeletePrivateTable
    | DeleteColumn
    | DeleteTask
    | DeleteMember
    | ViewPrivateTable
    | ViewTableSharedWithOthers
    | ViewTableSharedWithMe
    | ViewMemberOptions
    | ShareTableWithOthers
    | GotTablesSharedWithOthers (Result Http.Error (List String))
    | GotTablesSharedWithMe (Result Http.Error (List String))
    | DeleteSharedTable
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | Drag Task
    | DragEnd
    | DragOver
    | Drop String
    | SetMemberAsAdmin
    | SetMemberAsEditor
    | SetMemberAsVisitor



-- Update


updateApplicationState : Msg -> Model -> ( Model, Cmd Msg )
updateApplicationState msg model =
    case msg of
        GoToPrivateTables ->
            ( { model | application_state = State_PrivateTables }
            , Http.get
                { url = "/tables/private-tables/"
                , expect = Http.expectJson GotPrivateTables decodePrivateTables
                }
            )

        GoToTablesSharedWithMe ->
            ( { model | application_state = State_TablesSharedWithMe }
            , Http.get
                { url = "/tables/tables-shared-with-me/"
                , expect = Http.expectJson GotTablesSharedWithMe decodeTablesSharedWithMe
                }
            )

        GoToTablesSharedWithOthers ->
            ( { model | application_state = State_TablesSharedWithOthers }
            , Http.get
                { url = "/tables/tables-shared-with-others/"
                , expect = Http.expectJson GotTablesSharedWithOthers decodeTablesSharedWithOthers
                }
            )

        _ ->
            ( model, Cmd.none )


updatePrivateTables : Msg -> Model -> ( Model, Cmd Msg )
updatePrivateTables msg model =
    case msg of
        GotPrivateTables (Ok private_tables) ->
            ( { model
                | private_tables = private_tables
                , server_response = ServerResponse False "" False
                , input_field_table = ""
              }
            , Cmd.none
            )

        GotPrivateTables (Err error) ->
            case error of
                Http.BadBody body ->
                    let
                        server_response =
                            Decode.decodeString decodeServerResponse (getServerResponse body)
                    in
                    case server_response of
                        Ok valid_response ->
                            if valid_response.clear == True then
                                ( { model
                                    | server_response = valid_response
                                    , private_tables = []
                                    , current_table = Nothing
                                    , input_field_table = ""
                                  }
                                , Cmd.none
                                )

                            else
                                ( { model
                                    | server_response = valid_response
                                  }
                                , Cmd.none
                                )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        AddPrivateTable ->
            ( model
            , Http.post
                { url = "/tables/add-table"
                , body = Http.jsonBody <| (\input -> Encode.object [ ( "table_name", Encode.string input ) ]) model.input_field_table
                , expect = Http.expectJson GotPrivateTables decodePrivateTables
                }
            )

        RenameTable ->
            ( model
            , Http.post
                { url =
                    "/tables/private-tables/"
                        ++ (case model.current_table of
                                Just table ->
                                    table.name

                                Nothing ->
                                    ""
                           )
                        ++ "/rename"
                , body = Http.jsonBody <| (\input -> Encode.object [ ( "name", Encode.string input ) ]) model.input_field_table
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        PrivateTableFieldUpdated text ->
            ( { model | input_field_table = text }
            , Cmd.none
            )

        DeletePrivateTable ->
            ( model
            , Http.get
                { url = Url.toString model.url
                , expect = Http.expectJson GotPrivateTables decodePrivateTables
                }
            )

        ViewPrivateTable ->
            ( { model | application_state = State_ViewPrivateTable }
            , Http.get
                { url = Url.toString model.url
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        ShareTableWithOthers ->
            ( model
            , Http.get
                { url = Url.toString model.url
                , expect = Http.expectJson GotPrivateTables decodePrivateTables
                }
            )

        _ ->
            ( model, Cmd.none )


updateTablesSharedWithOthers : Msg -> Model -> ( Model, Cmd Msg )
updateTablesSharedWithOthers msg model =
    case msg of
        GotTablesSharedWithOthers (Ok tables_shared_with_others) ->
            ( { model
                | tables_shared_with_others = tables_shared_with_others
                , server_response = ServerResponse False "" False
                , input_field_table = ""
              }
            , Cmd.none
            )

        GotTablesSharedWithOthers (Err error) ->
            case error of
                Http.BadBody body ->
                    let
                        server_response =
                            Decode.decodeString decodeServerResponse (getServerResponse body)
                    in
                    case server_response of
                        Ok valid_response ->
                            if valid_response.clear == True then
                                ( { model
                                    | server_response = valid_response
                                    , tables_shared_with_others = []
                                    , current_table = Nothing
                                    , input_field_table = ""
                                  }
                                , Cmd.none
                                )

                            else
                                ( { model
                                    | server_response = valid_response
                                  }
                                , Cmd.none
                                )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        DeleteSharedTable ->
            ( model
            , Http.get
                { url = Url.toString model.url
                , expect = Http.expectJson GotTablesSharedWithOthers decodeTablesSharedWithOthers
                }
            )

        ViewTableSharedWithOthers ->
            ( { model | application_state = State_ViewTableSharedWithOthers }
            , Http.get
                { url = Url.toString model.url
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        _ ->
            ( model, Cmd.none )


updateTablesSharedWithMe : Msg -> Model -> ( Model, Cmd Msg )
updateTablesSharedWithMe msg model =
    case msg of
        GotTablesSharedWithMe (Ok tables_shared_with_me) ->
            ( { model
                | tables_shared_with_me = tables_shared_with_me
                , server_response = ServerResponse False "" False
                , input_field_table = ""
              }
            , Cmd.none
            )

        GotTablesSharedWithMe (Err error) ->
            case error of
                Http.BadBody body ->
                    let
                        server_response =
                            Decode.decodeString decodeServerResponse (getServerResponse body)
                    in
                    case server_response of
                        Ok valid_response ->
                            if valid_response.clear == True then
                                ( { model
                                    | server_response = valid_response
                                    , tables_shared_with_me = []
                                    , current_table = Nothing
                                    , input_field_table = ""
                                  }
                                , Cmd.none
                                )

                            else
                                ( { model
                                    | server_response = valid_response
                                  }
                                , Cmd.none
                                )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ViewTableSharedWithMe ->
            ( { model | application_state = State_ViewTableSharedWithMe }
            , Http.get
                { url = Url.toString model.url
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        _ ->
            ( model, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        -- Application State Updates
        GoToPrivateTables ->
            updateApplicationState msg model

        GoToTablesSharedWithMe ->
            updateApplicationState msg model

        GoToTablesSharedWithOthers ->
            updateApplicationState msg model

        -- Private Tables Updates
        GotPrivateTables (Ok private_tables) ->
            updatePrivateTables msg model

        GotPrivateTables (Err error) ->
            updatePrivateTables msg model

        GotTable (Ok table) ->
            ( { model
                | current_table = Just table
                , server_response = ServerResponse False "" False
                , input_field_table = ""
                , input_field_column = ""
                , input_field_task = ""
              }
            , Cmd.none
            )

        GotTable (Err error) ->
            case error of
                Http.BadBody body ->
                    let
                        server_response =
                            Decode.decodeString decodeServerResponse (getServerResponse body)
                    in
                    case server_response of
                        Ok valid_response ->
                            if valid_response.clear == True then
                                ( { model
                                    | server_response = valid_response
                                    , input_field_table = ""
                                  }
                                , Cmd.none
                                )

                            else
                                ( { model
                                    | server_response = valid_response
                                  }
                                , Cmd.none
                                )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        AddPrivateTable ->
            updatePrivateTables msg model

        AddColumn ->
            ( model
            , Http.post
                { url =
                    "/tables/"
                        ++ (case model.current_table of
                                Just table ->
                                    table.name

                                Nothing ->
                                    ""
                           )
                        ++ "/add-column/"
                , body = Http.jsonBody <| Encode.object [ ( "column_name", Encode.string model.input_field_column ) ]
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        AddTask ->
            ( model
            , Http.post
                { url = Url.toString model.url
                , body = Http.jsonBody <| Encode.object [ ( "description", Encode.string model.input_field_task ) ]
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        AddMember ->
            ( model
            , Http.post
                { url =
                    "/tables/"
                        ++ (case model.current_table of
                                Just table ->
                                    table.name

                                Nothing ->
                                    ""
                           )
                        ++ "/add-member/"
                , body = Http.jsonBody <| Encode.object [ ( "member_email", Encode.string model.input_field_addmember ) ]
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        RenameTable ->
            updatePrivateTables msg model

        PrivateTableFieldUpdated text ->
            updatePrivateTables msg model

        ColumnFieldUpdated text ->
            ( { model | input_field_column = text }, Cmd.none )

        TaskFieldUpdated text ->
            ( { model | input_field_task = text }, Cmd.none )

        AddMemberFieldUpdated text ->
            ( { model | input_field_addmember = text }, Cmd.none )

        DeletePrivateTable ->
            updatePrivateTables msg model

        DeleteColumn ->
            ( model
            , Http.get
                { url = Url.toString model.url
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        DeleteTask ->
            ( model
            , Http.get
                { url = Url.toString model.url
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        DeleteMember ->
            ( { model | application_state = model.last_application_state }
            , Http.post
                { url =
                    "/tables/"
                        ++ (case model.current_table of
                                Just table ->
                                    table.name

                                Nothing ->
                                    ""
                           )
                        ++ "/delete-member/"
                , body = Http.jsonBody <| Encode.object [ ( "member_email", Encode.string (String.dropLeft 1 model.url.path) ) ]
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        ViewPrivateTable ->
            updatePrivateTables msg model

        ViewTableSharedWithOthers ->
            updateTablesSharedWithOthers msg model

        ViewTableSharedWithMe ->
            updateTablesSharedWithMe msg model

        ViewMemberOptions ->
            ( { model
                | last_application_state = model.application_state
                , application_state = State_ViewMemberOptions
              }
            , Cmd.none
            )

        ShareTableWithOthers ->
            updatePrivateTables msg model

        -- Tables Shared With Others Updates
        GotTablesSharedWithOthers (Ok tables_shared_with_others) ->
            updateTablesSharedWithOthers msg model

        GotTablesSharedWithOthers (Err error) ->
            updateTablesSharedWithOthers msg model

        DeleteSharedTable ->
            updateTablesSharedWithOthers msg model

        -- Tables Shared With Others Updates
        GotTablesSharedWithMe (Ok tables_shared_with_me) ->
            updateTablesSharedWithMe msg model

        GotTablesSharedWithMe (Err error) ->
            updateTablesSharedWithMe msg model

        -- Retrieve User's name
        GotUser (Ok user) ->
            ( { model | user = user }
            , Cmd.none
            )

        GotUser (Err error) ->
            ( model, Cmd.none )

        --
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    if String.contains "/logout/" (Url.toString url) then
                        ( model, Nav.load (Url.toString url) )

                    else
                        ( { model | url = url }, Cmd.none )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )

        Drag task ->
            ( { model | taskBeingDragged = Just task }, Cmd.none )

        DragEnd ->
            ( { model | taskBeingDragged = Nothing }, Cmd.none )

        DragOver ->
            ( model, Cmd.none )

        Drop column_name ->
            case model.taskBeingDragged of
                Nothing ->
                    ( model, Cmd.none )

                Just task ->
                    ( { model
                        | taskBeingDragged = Nothing
                      }
                    , Http.post
                        { url =
                            "/tables/"
                                ++ (case model.current_table of
                                        Just table ->
                                            table.name

                                        Nothing ->
                                            ""
                                   )
                                ++ "/columns/"
                                ++ String.fromInt task.column_id
                                ++ "/tasks/task/"
                                ++ String.fromInt task.id
                                ++ "/move/"
                        , body = Http.jsonBody <| (\input -> Encode.object [ ( "move_to", Encode.string input ) ]) column_name
                        , expect = Http.expectJson GotTable decodeTable
                        }
                    )

        SetMemberAsAdmin ->
            ( { model | application_state = model.last_application_state }
            , Http.post
                { url =
                    "/tables/"
                        ++ (case model.current_table of
                                Just table ->
                                    table.name

                                Nothing ->
                                    ""
                           )
                        ++ "/set-member-as-admin/"
                , body = Http.jsonBody <| Encode.object [ ( "member_email", Encode.string (String.dropLeft 1 model.url.path) ) ]
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        SetMemberAsEditor ->
            ( { model | application_state = model.last_application_state }
            , Http.post
                { url =
                    "/tables/"
                        ++ (case model.current_table of
                                Just table ->
                                    table.name

                                Nothing ->
                                    ""
                           )
                        ++ "/set-member-as-editor/"
                , body = Http.jsonBody <| Encode.object [ ( "member_email", Encode.string (String.dropLeft 1 model.url.path) ) ]
                , expect = Http.expectJson GotTable decodeTable
                }
            )

        SetMemberAsVisitor ->
            ( { model | application_state = model.last_application_state }
            , Http.post
                { url =
                    "/tables/"
                        ++ (case model.current_table of
                                Just table ->
                                    table.name

                                Nothing ->
                                    ""
                           )
                        ++ "/set-member-as-visitor/"
                , body = Http.jsonBody <| Encode.object [ ( "member_email", Encode.string (String.dropLeft 1 model.url.path) ) ]
                , expect = Http.expectJson GotTable decodeTable
                }
            )



{- _ ->
   ( model, Cmd.none )
-}
-- View


viewServerResonse : ServerResponse -> Html.Html Msg
viewServerResonse server_response =
    if server_response.error == True then
        Html.span [ Attributes.style "margin-top" "1rem", Attributes.style "color" "red" ] [ Html.text server_response.message ]

    else
        Html.span [ Attributes.style "margin-top" "1rem", Attributes.style "color" "green" ] [ Html.text server_response.message ]


viewHome : Model -> Html.Html Msg
viewHome model =
    Html.section [ Attributes.id "home-section" ]
        [ Html.div []
            [ Html.ul []
                [ Html.li [ onClick GoToPrivateTables, Attributes.style "cursor" "pointer" ]
                    [ if model.application_state == State_PrivateTables then
                        Html.h2 [ Attributes.class "home-active" ] [ Html.text "Private Tables" ]

                      else
                        Html.h2 [ Attributes.style "color" "white" ] [ Html.text "Private Tables" ]
                    ]
                , Html.li [ onClick GoToTablesSharedWithOthers, Attributes.style "cursor" "pointer" ]
                    [ if model.application_state == State_TablesSharedWithOthers then
                        Html.h2 [ Attributes.class "home-active" ] [ Html.text "Tables shared with others" ]

                      else
                        Html.h2 [ Attributes.style "color" "white" ] [ Html.text "Tables shared with others" ]
                    ]
                , Html.li [ onClick GoToTablesSharedWithMe, Attributes.style "cursor" "pointer" ]
                    [ if model.application_state == State_TablesSharedWithMe then
                        Html.h2 [ Attributes.class "home-active" ] [ Html.text "Tables shared with me" ]

                      else
                        Html.h2 [ Attributes.style "color" "white" ] [ Html.text "Tables shared with me" ]
                    ]
                ]
            ]
        ]


viewPrivateTables : Model -> Html.Html Msg
viewPrivateTables model =
    Html.section [ Attributes.id "private-tables-section" ]
        [ viewHome model
        , Html.div [ Attributes.id "view-private-tables" ]
            [ Html.form [ onSubmit AddPrivateTable ]
                [ Html.label []
                    [ Html.h3 []
                        [ Html.text "Add a private table"
                        ]
                    , Html.input [ onInput PrivateTableFieldUpdated, Attributes.value model.input_field_table, Attributes.type_ "text", Attributes.required True, Attributes.placeholder "Enter your table name here" ] []
                    , Html.input [ Attributes.type_ "submit", Attributes.value "Add" ] []
                    ]
                ]
            , viewServerResonse model.server_response
            , Html.ul []
                (List.map
                    (\private_table ->
                        Html.li []
                            [ Html.a [ onClick ViewPrivateTable, Attributes.href <| "/tables/" ++ private_table, Attributes.style "cursor" "pointer" ] [ Html.h3 [] [ Html.text private_table ] ]
                            , Html.a [ onClick DeletePrivateTable, Attributes.href <| "/tables/private-tables/delete-table/" ++ private_table ] [ Html.button [] [ Html.text "delete" ] ]
                            , Html.a [ onClick ShareTableWithOthers, Attributes.href <| "/tables/private-tables/" ++ private_table ++ "/share/" ] [ Html.button [] [ Html.text "Share with others" ] ]
                            ]
                    )
                    model.private_tables
                )
            ]
        ]


viewTablesSharedWithOthers : Model -> Html.Html Msg
viewTablesSharedWithOthers model =
    Html.section [ Attributes.id "tables-shared-with-others-section" ]
        [ viewHome model
        , Html.div [ Attributes.id "view-tables-shared-with-others" ]
            [ viewServerResonse model.server_response
            , Html.ul []
                (List.map
                    (\table ->
                        Html.li []
                            [ Html.a [ onClick ViewTableSharedWithOthers, Attributes.href <| "/tables/" ++ table, Attributes.style "cursor" "pointer" ] [ Html.h3 [] [ Html.text table ] ]
                            , Html.a [ onClick DeleteSharedTable, Attributes.href <| "/tables/shared-tables/delete-table/" ++ table ] [ Html.button [] [ Html.text "delete" ] ]
                            ]
                    )
                    model.tables_shared_with_others
                )
            ]
        ]


viewTablesSharedWithMe : Model -> Html.Html Msg
viewTablesSharedWithMe model =
    Html.section [ Attributes.id "tables-shared-with-me-section" ]
        [ viewHome model
        , Html.div [ Attributes.id "view-tables-shared-with-me" ]
            [ viewServerResonse model.server_response
            , Html.ul []
                (List.map
                    (\table ->
                        Html.li []
                            [ Html.a [ onClick ViewTableSharedWithMe, Attributes.href <| "/tables/" ++ table, Attributes.style "cursor" "pointer" ] [ Html.h3 [] [ Html.text table ] ]
                            ]
                    )
                    model.tables_shared_with_me
                )
            ]
        ]


viewPrivateTablesList : List String -> Html.Html Msg
viewPrivateTablesList private_tables =
    Html.div [ Attributes.id "private-tables-list" ]
        [ Html.button [ onClick GoToPrivateTables ] [ Html.h2 [ Attributes.title "Go Back to Private Tables Section" ] [ Html.text "Private Tables" ] ]
        , Html.ul []
            (List.map
                (\table ->
                    Html.li []
                        [ Html.a [ onClick ViewPrivateTable, Attributes.href <| "/tables/" ++ table, Attributes.style "cursor" "pointer" ] [ Html.text table ]
                        ]
                )
                private_tables
            )
        ]


viewTableMembers : Model -> Html.Html Msg
viewTableMembers model =
    Html.div [ Attributes.id "view-members" ]
        [ Html.button [] [ Html.h2 [] [ Html.text "Members" ] ]
        , case model.current_table of
            Just table ->
                if table.current_user_role == "creator" || table.current_user_role == "admin" then
                    Html.div [ Attributes.id "add-members" ]
                        [ Html.input [ onInput AddMemberFieldUpdated, Attributes.value model.input_field_addmember, Attributes.type_ "email", Attributes.required True, Attributes.placeholder "Add new member" ] []
                        , Html.button [ onClick AddMember ] [ Html.text "Add" ]
                        ]

                else
                    Html.text ""

            Nothing ->
                Html.text ""
        , case model.current_table of
            Just table ->
                Html.ul [ Attributes.id "list-members" ]
                    (case table.members of
                        Just members ->
                            List.map
                                (\member ->
                                    Html.li []
                                        [ Html.div []
                                            [ if member.member_role == "creator" || model.user.useremail == member.member_email then
                                                Html.text ""

                                              else
                                                Html.div [ Attributes.id "member" ]
                                                    [ Html.h3 [] [ Html.text member.member_email ]
                                                    , if table.current_user_role == "creator" || table.current_user_role == "admin" then
                                                        Html.a [ onClick ViewMemberOptions, Attributes.href member.member_email ] [ Html.text "options" ]

                                                      else
                                                        Html.text ""
                                                    ]
                                            ]
                                        ]
                                )
                                members

                        Nothing ->
                            List.map Html.text [ "", "" ]
                    )

            Nothing ->
                Html.text ""
        ]


viewTable : Model -> Html.Html Msg
viewTable model =
    Html.section [ Attributes.id "view-table-section" ]
        [ case model.application_state of
            State_ViewPrivateTable ->
                viewPrivateTablesList model.private_tables

            _ ->
                viewTableMembers model
        , Html.div [ Attributes.id "table-main-section" ]
            [ case model.application_state of
                State_ViewPrivateTable ->
                    Html.form [ Attributes.id "rename-table-form", onSubmit RenameTable ]
                        [ Html.input
                            [ onInput PrivateTableFieldUpdated
                            , Attributes.value model.input_field_table
                            , Attributes.type_ "text"
                            , Attributes.placeholder
                                (case model.current_table of
                                    Just table ->
                                        table.name

                                    Nothing ->
                                        " Oops !! the table seems not to be loaded, please try refreshing the page"
                                )
                            ]
                            []
                        , Html.input [ Attributes.type_ "submit", Attributes.style "display" "none" ] []
                        ]

                _ ->
                    Html.h3 [ Attributes.id "table-name" ]
                        [ Html.text
                            (case model.current_table of
                                Just table ->
                                    table.name

                                Nothing ->
                                    " Oops !! the table seems not to be loaded, please try refreshing the page"
                            )
                        ]
            , case model.current_table of
                Just table ->
                    if model.application_state == State_ViewPrivateTable || table.current_user_role == "creator" || table.current_user_role == "admin" || table.current_user_role == "editor" then
                        Html.form [ Attributes.id "add-column-form", onSubmit AddColumn ]
                            [ Html.input [ onInput ColumnFieldUpdated, Attributes.value model.input_field_column, Attributes.type_ "text", Attributes.required True, Attributes.placeholder "Enter your column name here" ] []
                            , Html.input [ Attributes.type_ "submit", Attributes.value "Add a new column" ] []
                            ]

                    else
                        Html.h3 [ Attributes.style "color" "red", Attributes.style "background" "white" ] [ Html.text "visitor" ]

                Nothing ->
                    Html.text ""
            , viewServerResonse model.server_response
            , Html.div [ Attributes.id "table-view-container" ]
                [ case model.current_table of
                    Just table ->
                        Html.ul [ Attributes.id "table-view" ]
                            (case table.columns of
                                Just columns ->
                                    List.map
                                        (\column ->
                                            Html.li []
                                                [ Html.div [ Attributes.id "columns-view" ]
                                                    [ Html.div [ Attributes.id "columns-view-head" ]
                                                        [ Html.h3 [] [ Html.text column.name ]
                                                        , if model.application_state == State_ViewPrivateTable || table.current_user_role == "creator" || table.current_user_role == "admin" || table.current_user_role == "editor" then
                                                            Html.a [ onClick DeleteColumn, Attributes.href <| "/tables/" ++ table.name ++ "/delete-column/" ++ column.name ] [ Html.button [] [ Html.text "x" ] ]

                                                          else
                                                            Html.text ""
                                                        ]
                                                    , if model.application_state == State_ViewPrivateTable || table.current_user_role == "creator" || table.current_user_role == "admin" || table.current_user_role == "editor" then
                                                        Html.div [ Attributes.id "columns-view-add-task" ]
                                                            [ Html.input [ onInput TaskFieldUpdated, Attributes.value model.input_field_task, Attributes.type_ "text", Attributes.required True, Attributes.placeholder "Enter new task here" ] []
                                                            , Html.a [ onClick AddTask, Attributes.href <| "/tables/" ++ table.name ++ "/columns/" ++ column.name ++ "/add-task/" ] [ Html.button [] [ Html.text "+" ] ]
                                                            ]

                                                      else
                                                        Html.text ""
                                                    , Html.ul [ Attributes.id "tasks-view" ]
                                                        (case column.tasks of
                                                            Just tasks ->
                                                                List.map
                                                                    (\task ->
                                                                        Html.li
                                                                            [ Attributes.draggable "true"
                                                                            , onDragStart <| Drag task
                                                                            , onDragEnd DragEnd
                                                                            ]
                                                                            [ Html.div []
                                                                                [ Html.p [ Attributes.style "cursor" "grabbing", Attributes.style "display" "inline-block" ] [ Html.text task.description ]
                                                                                , if model.application_state == State_ViewPrivateTable || table.current_user_role == "creator" || table.current_user_role == "admin" || table.current_user_role == "editor" then
                                                                                    Html.a [ onClick DeleteTask, Attributes.href <| "/tables/" ++ table.name ++ "/columns/" ++ column.name ++ "/delete-task/" ++ String.fromInt task.id ] [ Html.button [] [ Html.text "-" ] ]

                                                                                  else
                                                                                    Html.text ""
                                                                                ]
                                                                            ]
                                                                    )
                                                                    tasks

                                                            Nothing ->
                                                                List.map Html.text [ "", "" ]
                                                        )
                                                    , if model.application_state == State_ViewPrivateTable || table.current_user_role == "creator" || table.current_user_role == "admin" || table.current_user_role == "editor" then
                                                        Html.div [ Attributes.id "tasks-drop-zone", onDragOver DragOver, onDrop <| Drop column.name ] [ Html.text "Drop your task here" ]

                                                      else
                                                        Html.text ""
                                                    ]
                                                ]
                                        )
                                        columns

                                Nothing ->
                                    List.map Html.text [ "", "" ]
                            )

                    Nothing ->
                        viewServerResonse model.server_response
                ]
            ]
        ]


viewMembersOptions : Model -> Html.Html Msg
viewMembersOptions model =
    Html.section [ Attributes.id "view-members-section" ]
        [ Html.div [ Attributes.id "view-members-options" ]
            [ Html.button
                [ onClick
                    (case model.last_application_state of
                        State_ViewTableSharedWithMe ->
                            ViewTableSharedWithMe

                        State_ViewTableSharedWithOthers ->
                            ViewTableSharedWithOthers

                        _ ->
                            GoToPrivateTables
                    )
                , Attributes.id "go-back-to-last-state"
                ]
                [ Html.text "X" ]
            , Html.div [ Attributes.id "members-options" ]
                [ Html.div [ Attributes.id "delete-member" ]
                    [ Html.h3 [] [ Html.text (String.dropLeft 1 model.url.path) ]
                    , Html.a
                        [ Attributes.href (String.dropLeft 1 model.url.path)
                        , onClick DeleteMember
                        ]
                        [ Html.button [] [ Html.text "delete" ] ]
                    ]
                , Html.a
                    [ Attributes.href (String.dropLeft 1 model.url.path)
                    , Attributes.class "options"
                    , onClick SetMemberAsAdmin
                    ]
                    [ Html.button [] [ Html.text "set as 'admin' " ] ]
                , Html.a
                    [ Attributes.href (String.dropLeft 1 model.url.path)
                    , Attributes.class "options"
                    , onClick SetMemberAsEditor
                    ]
                    [ Html.button [] [ Html.text "set as 'editor' " ] ]
                , Html.a
                    [ Attributes.href (String.dropLeft 1 model.url.path)
                    , Attributes.class "options"
                    , onClick SetMemberAsVisitor
                    ]
                    [ Html.button [] [ Html.text "set as 'visitor' " ] ]
                ]
            ]
        ]


view : Model -> Browser.Document Msg
view model =
    { title = "Trello Clone - Welcome " ++ model.user.username
    , body =
        [ Html.header [ Attributes.id "main-header" ]
            [ Html.a [ onClick GoToPrivateTables, Attributes.href "/", Attributes.id "banner" ]
                [ Html.img [ Attributes.src "static/assets/trello.svg", Attributes.alt "Trello Logo" ] []
                , Html.h3 [] [ Html.text "Trello Clone" ]
                ]
            ]
        , if model.application_state == State_PrivateTables || model.application_state == State_TablesSharedWithOthers || model.application_state == State_TablesSharedWithMe then
            Html.div [ Attributes.id "logout-style" ]
                [ Html.h1 [] [ Html.text <| " Welcome " ++ model.user.username ]
                , Html.a [ Attributes.href "/logout/" ] [ Html.text "Log out" ]
                ]

          else
            Html.text ""
        , case model.application_state of
            State_PrivateTables ->
                viewPrivateTables model

            State_TablesSharedWithOthers ->
                viewTablesSharedWithOthers model

            State_TablesSharedWithMe ->
                viewTablesSharedWithMe model

            State_ViewPrivateTable ->
                viewTable model

            State_ViewTableSharedWithOthers ->
                viewTable model

            State_ViewTableSharedWithMe ->
                viewTable model

            State_ViewMemberOptions ->
                viewMembersOptions model
        ]
    }



-- Main


main : Program () Model Msg
main =
    Browser.application
        { init = initialModel
        , view = view
        , update = update
        , subscriptions = always Sub.none
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
