import flask_login
from werkzeug.security import generate_password_hash, check_password_hash
from sqlalchemy import exc
from database import DATABASE as db
from models.tables import Tables


class Users(db.Model, flask_login.UserMixin):
    __tablename__ = "users"
    email = db.Column(db.Text, primary_key=True)
    username = db.Column(db.Text, nullable=False)
    password_hash = db.Column(db.Text, nullable=False)
    tables = db.relationship('Tables', backref='owner',
                             cascade='all,delete', lazy=True)
    membership = db.relationship('Members', backref='membership', lazy=True)

    def set_password(self, password):
        '''Set the user's password.'''
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        '''Check if the provided password and the user's password match.'''
        return check_password_hash(self.password_hash, password)

    def get_id(self):
        '''Return the user's email.'''
        return self.email

    def get_name(self):
        '''Return the user's name.'''
        return self.username

    def get_table_by_id(self, id):
        ''' Return corresponding table, mostly used when retrieveing a
            table shared with the user'''
        if self.membership:
            table, _ = self.get_tables_shared_with_me()

            for t in table:
                if t.id == id:
                    return (t, 'Found')

            return (None, 'Not found')
        return (None, 'Not found')

    def get_table_by_name(self, name):
        '''Return the table that matches the name provided.'''
        table = Tables.query.filter_by(name=name, creator=self.email).first()

        if table:
            return (table, "Table '{}' found".format(name))

        table = Tables.query.filter_by(name=name).first()

        if table and table.get_member_by_email(self.email):
            return (table, "Table '{}' found".format(name))

        return (None, "Table '{}' not found".format(name))

    def get_private_tables(self):
        '''Return a list of the user's private tables.'''
        if self.tables:
            table = [t for t in self.tables if not t.shared]

            if table:
                return (table, "Found")
            return (None, "You don't have any private table yet")
        return (None, "You don't have any private table yet")

    def get_tables_shared_with_others(self):
        '''Return a list of the user's shared tables.'''
        if self.tables:
            table = [t for t in self.tables if t.shared]

            if table:
                return (table, "Found")
            return (None, "You did not share any table yet")
        return (None, "You did not share any table yet")

    def get_tables_shared_with_me(self):
        '''Return a list of the tables shared with the user.'''
        table = []

        if self.membership:
            for m in self.membership:
                t = Tables.query.filter_by(id=m.get_table_id()).first()

                if t and t.creator != self.email:
                    table.append(t)
        if table:
            return (table, "Found")
        return (None, "No table shared with you")

    def add_table(self, name):
        '''Create a new table if it doesn't already exists.'''
        if name:

            table = Tables(name=name, creator=self.email, shared=False)

            if Tables.query.filter_by(name=name).first() is None:
                db.session.add(table)
                db.session.commit()
                return (table, "Table '{}' successfully created".format(name))
            return (None, "A table with name: '{}' already exists".format(name))
        return (None, "Looks like you did not give us a table name")

    def remove_table_by_name(self, name):
        '''Remove the table from the list of the user's tables.'''
        table = db.session.query(Tables).filter(Tables.name == name,
                                                Tables.creator == self.email).first()

        if table:
            db.session.delete(table)
            db.session.commit()
            return True
        return False

    def to_dict(self):
        return {'email': self.email,
                'username': self.username
                }



def add_user(email, username, password):
    '''Create a new user.'''
    if email and username and password:
        user = Users(email=email, username=username, password_hash=password)
        user.set_password(password)

        try:
            db.session.add(user)
            db.session.commit()
        except exc.IntegrityError:
            db.session.rollback()
            return (None,
                    "{} already exists, please try another one".format(email))
        else:
            return (user, "{} successfully created, you can now sign in".format(email))
    return (None, "Make sure you've filled all the credentials asked")


def retrieve_user(email, password):
    '''Return the user that matches the credentials.'''
    if email and password:
        user = Users.query.get(email)

        if user is None or not user.check_password(password):
            return (None, "Authentication failed")
        return (user, "You're now logged in as {}".format(user.get_id()))
    return (None, "Make sure you've entered all credentials asked")
