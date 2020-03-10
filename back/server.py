import secrets
from flask import Flask, render_template, request, redirect, url_for, jsonify
import flask_login
from database import DATABASE
from forms_validation import validate_signup, validate_name, validate_email
from models.users import Users, add_user, retrieve_user
from models.tables import Tables
from models.columns import Columns
from models.tasks import Tasks
from models.members import Members


# #################-Application setup-#########################################

def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = secrets.token_urlsafe(64)
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///.database/trello.db'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    DATABASE.app = app
    DATABASE.init_app(app)
    login_manager.init_app(app)

    with app.test_request_context():
        DATABASE.create_all()
    return app


login_manager = flask_login.LoginManager()
login_manager.login_view = 'login'
app = create_app()


@login_manager.user_loader
def load_user(email):
    if email is not None:
        return Users.query.get(email)
    return None


# ############################- Basic Routes -################################
@app.route('/')
def index():
    if flask_login.current_user.is_authenticated:
        return render_template('home.html')
    return render_template('index.html')


@app.route('/signup/', methods=['GET', 'POST'])
def signup():
    if flask_login.current_user.is_authenticated:
        return redirect(url_for('index'))

    if request.method == 'GET':
        return render_template('signup.html')

    if request.method == 'POST' and request.json:
        password = request.json.get('password')
        email = request.json.get('email')
        name = request.json.get('name')

        status = validate_signup(name, email)

        if status:
            return jsonify({'error': True,
                            'message': status})

        new_user, status = add_user(email, name, password)

        if not new_user:
            return jsonify({'error': True,
                            'message': status})
        return jsonify({'error': False,
                        'message': status})
    return jsonify({'error': True,
                    'message': "Something is off with what you've submitted"})


@app.route('/login/', methods=['GET', 'POST'])
def login():
    if flask_login.current_user.is_authenticated:
        return redirect(url_for('index'))

    if request.method == 'GET':
        return render_template('login.html')

    if request.method == 'POST' and request.json:
        email = request.json.get('email')
        password = request.json.get('password')

        user, status = retrieve_user(email, password)

        if not user:
            return jsonify({'error': True,
                            'message': status})

        flask_login.login_user(user)

        return jsonify({'error': False,
                        'message': "You're now logged in press F5"})

    return jsonify({'error': True,
                    'message': "Something is off with what you've submitted"})


@app.route('/logout/')
@flask_login.login_required
def logout():
    flask_login.logout_user()
    return redirect(url_for('index'))


# ##################- Route to retrieve current user info -####################
@app.route('/users/get-current-user/')
@flask_login.login_required
def get_current_user():
    return jsonify({'useremail': flask_login.current_user.get_id(),
                    'username': flask_login.current_user.get_name()})


# ###################- Routes for tables manipulation-#########################
@app.route('/tables/private-tables/')
@flask_login.login_required
def view_private_tables():
    current_user = flask_login.current_user
    tables, status = current_user.get_private_tables()

    if tables:
        return jsonify({'private_tables': [t.name for t in tables]})
    return jsonify({'error': True,
                    'message': status,
                    'clear': True}
                   )


@app.route('/tables/tables-shared-with-others/')
@flask_login.login_required
def view_tables_shared_with_others():
    current_user = flask_login.current_user
    tables, status = current_user.get_tables_shared_with_others()

    if tables:
        return jsonify({'tables_shared_with_others': [t.name for t in tables]})
    return jsonify({'error': True,
                    'message': status,
                    'clear': True})


@app.route('/tables/tables-shared-with-me/')
@flask_login.login_required
def view_tables_shared_with_me():
    current_user = flask_login.current_user
    tables, status = current_user.get_tables_shared_with_me()

    if tables:
        return jsonify({'tables_shared_with_me': [t.name for t in tables]})
    return jsonify({'error': True,
                    'message': status,
                    'clear': True}
                   )


@app.route('/tables/<string:name>')
@flask_login.login_required
def view_table(name):
    current_user = flask_login.current_user
    
    if name:
        table, status = current_user.get_table_by_name(name)

        if not table:
            return jsonify({'error': True,
                            'message': status,
                            'clear': True}
                           )
        return jsonify(table.to_dict(current_user.get_id()))
    return jsonify({'error': True,
                            'message': "You did not provide a name for the table you wish to view",
                            'clear': True}
                           )


@app.route('/tables/private-tables/<string:name>/share/')
@flask_login.login_required
def share_table(name):
    current_user = current_user = flask_login.current_user
    table, _ = current_user.get_table_by_name(name)

    if table and table.get_creator() == current_user.get_id():
        table.share(current_user.get_id())

    return redirect(url_for('view_private_tables'))


@app.route('/tables/add-table', methods=['POST'])
@flask_login.login_required
def add_table():
    current_user = flask_login.current_user

    if request.json:
        table_name = request.json.get('table_name')

        is_name_valid, status = validate_name(table_name)

        if not is_name_valid:
            return jsonify({"error": True,
                            "message": status,
                            "clear": False}
                           )
        table, status = current_user.add_table(table_name)

        if table:
            return redirect(url_for('view_private_tables'))
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "You did not provide any information",
                    "clear": False})


@app.route('/tables/private-tables/delete-table/<string:name>')
@flask_login.login_required
def delete_private_table(name):
    current_user = flask_login.current_user
    status = current_user.remove_table_by_name(name)

    if status:
        return redirect(url_for('view_private_tables'))

    message = "Table '{}' not found, make sure you provided valid info".format(name)
    return jsonify({'error': True,
                    'message': message,
                    "clear": True})


@app.route('/tables/shared-tables/delete-table/<string:name>')
@flask_login.login_required
def delete_shared_table(name):
    current_user = flask_login.current_user
    status = current_user.remove_table_by_name(name)

    if status:
        return redirect(url_for('view_tables_shared_with_others'))

    message = "Table '{}' not found, make sure you provided valid info".format(name)
    return jsonify({'error': True,
                    'message': message,
                    "clear": True})


@app.route('/tables/private-tables/<string:current_name>/rename',
           methods=['POST', ])
@flask_login.login_required
def rename_table(current_name):
    current_user = flask_login.current_user

    if request.json:
        new_name = request.json.get('name')

        is_name_valid, status = validate_name(new_name)

        if not is_name_valid:
            return jsonify({"error": True,
                            "message": status,
                            "clear": False})

        table, status = current_user.get_table_by_name(current_name)

        if table and (not table.shared) and table.get_creator() == current_user.get_id():
            tab, status = table.rename(new_name)

            if tab:
                return jsonify(tab.to_dict(current_user.get_id()))
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "You did not provide any information",
                    "clear": False})


# ###################- Routes for columns manipulation-########################
@app.route('/tables/<string:table_name>/add-column/', methods=['POST'])
@flask_login.login_required
def add_column(table_name):
    current_user = flask_login.current_user

    if request.json:
        column_name = request.json.get('column_name')
        table, status = current_user.get_table_by_name(table_name)

        if table:
            is_name_valid, status = validate_name(column_name)

            if not is_name_valid:
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})

            col, status = table.add_column(column_name, current_user.get_id())

            if col:
                return jsonify(table.to_dict(current_user.get_id()))
            return jsonify({"error": True,
                            "message": status,
                            "clear": False})
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "You did not provide any information",
                    "clear": False})


@app.route('/tables/<string:table_name>/delete-column/<string:name>')
@flask_login.login_required
def delete_column_(table_name, name):
    current_user = flask_login.current_user
    table, status = current_user.get_table_by_name(table_name)

    if table:
        status, message = table.delete_column_by_name(name,
                                                      current_user.get_id())

        if status:
            return jsonify(table.to_dict(current_user.get_id()))
        return jsonify({"error": True,
                        "message": message,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "Something is off with your informations",
                    "clear": False})


# ###################- Routes for tasks manipulation-#########################
@app.route('/tables/<string:t_name>/columns/<string:col_name>/add-task/',
           methods=['POST'])
@flask_login.login_required
def add_task(t_name, col_name):
    current_user = flask_login.current_user

    if request.json:
        table, status = current_user.get_table_by_name(t_name)

        if table:
            column, status = table.get_column_by_name(col_name)

            if column:
                description = request.json.get('description')

                if not table.shared:
                    task, status = column.add_task(description)
                else:
                    member = table.get_member_by_email(current_user.get_id())

                    if member.get_member_role() in ("creator", "admin",
                                                    "editor"):
                        task, status = column.add_task(description)
                    else:
                        return jsonify({"error": True,
                                        "message": "Illegal action !!",
                                        "clear": False})

                if task:
                    return jsonify(table.to_dict(current_user.get_id()))
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})
            return jsonify({"error": True,
                            "message": status,
                            "clear": False})
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})

    return jsonify({"error": True,
                    "message": "You did not provide any information",
                    "clear": False})


@app.route('''/tables/<string:t_name>/columns/<int:col_id>/tasks/task/<int:task_id>/move/''', methods=['POST', ])
@flask_login.login_required
def move_task(t_name, col_id, task_id):
    current_user = flask_login.current_user
    table, status = current_user.get_table_by_name(t_name)

    if table:
        if not request.json:
            return jsonify({"error": True,
                            "message": '''Something is off
                             with what you submitted''',
                            "clear": False})
        if not table.shared or (table.get_member_by_email(current_user.get_id()) and table.get_member_by_email(current_user.get_id()).get_member_role() in ("creator", "admin", "editor")):
            dest_col_name = request.json.get('move_to')

            current_column, _ = table.get_column_by_id(col_id)
            destination, _ = table.get_column_by_name(dest_col_name)

            if current_column and destination:
                if current_column.move_task_to(task_id, destination):
                    return jsonify(table.to_dict(current_user.get_id()))
                return jsonify({"error": True,
                                "message": '''Something went wrong !!
                                Please Try again''',
                                "clear": False})
            return jsonify({"error": True,
                            "message": "Something is off with what you sent",
                            "clear": False})
        return jsonify({"error": True,
                        "message": "Illegal action !!",
                        "clear": False})
    return jsonify({"error": True,
                    "message": "Something is off with what you submitted",
                    "clear": False})


@app.route('/tables/<string:t_name>/columns/<string:col_name>/delete-task/<int:task_id>')
@flask_login.login_required
def delete_task(t_name, col_name, task_id):
    current_user = flask_login.current_user
    table, status = current_user.get_table_by_name(t_name)

    if table:
        column, status = table.get_column_by_name(col_name)

        if column:
            if not table.shared or (table.get_member_by_email(current_user.get_id()) and table.get_member_by_email(current_user.get_id()).get_member_role() in ("creator", "admin", "editor")):
                if column.remove_task_by_id(task_id):
                    return jsonify(table.to_dict(current_user.get_id()))
                return jsonify({"error": True,
                                "message": "Please submit valid informations",
                                "clear": False})
            return jsonify({"error": True,
                            "message": "Illegal action !!",
                            "clear": False})
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "Something is off with your informations",
                    "clear": False})


# ###################-Routes for table's members manipulation-#########################
@app.route('/tables/<string:table_name>/add-member/', methods=['POST'])
@flask_login.login_required
def add_member(table_name):
    current_user = flask_login.current_user

    if request.json:
        member_email = request.json.get('member_email')
        table, status = current_user.get_table_by_name(table_name)

        if table:
            is_email_valid, status = validate_email(member_email)

            if not is_email_valid:
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})

            member, status = table.add_member(member_email,
                                              current_user.get_id())

            if member:
                is_user = Users.query.filter_by(email=member_email).first()

                if is_user:
                    DATABASE.session.add(member)
                    DATABASE.session.commit()
                    return jsonify(table.to_dict(current_user.get_id()))
                return jsonify({"error": True,
                                "message": "{} is not a user".format(member_email),
                                "clear": False})
            return jsonify({"error": True,
                            "message": status,
                            "clear": False})
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "You did not provide any information",
                    "clear": False})




@app.route('/tables/<string:table_name>/delete-member/', methods=['POST'])
@flask_login.login_required
def delete_member(table_name):
    current_user = flask_login.current_user

    if request.json:
        member_email = request.json.get('member_email')
        table, status = current_user.get_table_by_name(table_name)

        if table:
            is_email_valid, status = validate_email(member_email)

            if not is_email_valid:
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})

            member = table.get_member_by_email(member_email)

            if member:
                is_member_deleted, status = table.delete_member_by_email(member_email, current_user.get_id())

                if is_member_deleted:
                    return jsonify(table.to_dict(current_user.get_id()))
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})
            return jsonify({"error": True,
                            "message": "{} is not a member of this table".format(member_email),
                            "clear": False})
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "You did not provide any information",
                    "clear": False})



@app.route('/tables/<string:table_name>/set-member-as-admin/', methods=['POST'])
@flask_login.login_required
def set_member_as_admin(table_name):
    current_user = flask_login.current_user

    if request.json:
        member_email = request.json.get('member_email')
        table, status = current_user.get_table_by_name(table_name)

        if table:
            is_email_valid, status = validate_email(member_email)

            if not is_email_valid:
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})

            member = table.get_member_by_email(member_email)

            if member:
                is_member_role_updated, status = table.set_member_as_admin(member_email, current_user.get_id())

                if is_member_role_updated:
                    return jsonify(table.to_dict(current_user.get_id()))
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})
            return jsonify({"error": True,
                            "message": "{} is not a member of this table".format(member_email),
                            "clear": False})
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "You did not provide any information",
                    "clear": False})


@app.route('/tables/<string:table_name>/set-member-as-editor/', methods=['POST'])
@flask_login.login_required
def set_member_as_editor(table_name):
    current_user = flask_login.current_user

    if request.json:
        member_email = request.json.get('member_email')
        table, status = current_user.get_table_by_name(table_name)

        if table:
            is_email_valid, status = validate_email(member_email)

            if not is_email_valid:
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})

            member = table.get_member_by_email(member_email)

            if member:
                is_member_role_updated, status = table.set_member_as_editor(member_email, current_user.get_id())

                if is_member_role_updated:
                    return jsonify(table.to_dict(current_user.get_id()))
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})
            return jsonify({"error": True,
                            "message": "{} is not a member of this table".format(member_email),
                            "clear": False})
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "You did not provide any information",
                    "clear": False})  


@app.route('/tables/<string:table_name>/set-member-as-visitor/', methods=['POST'])
@flask_login.login_required
def set_member_as_visitor(table_name):
    current_user = flask_login.current_user

    if request.json:
        member_email = request.json.get('member_email')
        table, status = current_user.get_table_by_name(table_name)

        if table:
            is_email_valid, status = validate_email(member_email)

            if not is_email_valid:
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})

            member = table.get_member_by_email(member_email)

            if member:
                is_member_role_updated, status = table.set_member_as_visitor(member_email, current_user.get_id())

                if is_member_role_updated:
                    return jsonify(table.to_dict(current_user.get_id()))
                return jsonify({"error": True,
                                "message": status,
                                "clear": False})
            return jsonify({"error": True,
                            "message": "{} is not a member of this table".format(member_email),
                            "clear": False})
        return jsonify({"error": True,
                        "message": status,
                        "clear": False})
    return jsonify({"error": True,
                    "message": "You did not provide any information",
                    "clear": False}) 




if __name__ == '__main__':
    app.run(debug=False)
