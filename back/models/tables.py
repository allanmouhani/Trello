from database import DATABASE as db
from models.columns import Columns as Cols
from models.members import Members


class Tables(db.Model):
    __tablename__ = "tables"
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Text, nullable=False, unique=True)
    creator = db.Column(db.Text, db.ForeignKey('users.email'), nullable=False)
    columns = db.relationship('Columns', backref='table',
                              cascade='all,delete', lazy=True)
    shared = db.Column(db.Boolean, nullable=False, default=False)
    members = db.relationship('Members', backref='table',
                              cascade='all,delete', lazy=True)

    def get_name(self):
        '''Return the table's name.'''
        return self.name

    def get_creator(self):
        '''Return the table's creator.'''
        return self.creator

    def get_column_by_name(self, name):
        '''Return the column that matches the name.'''
        if name:
            column = Cols.query.filter_by(name=name, table_id=self.id).first()

            if column:
                return (column, "Column '{}' found".format(name))
            return (None, "Column '{}' not found".format(name))
        return (None, "You did not provide the column name")

    def get_column_by_id(self, id):
        '''Return the column that matches the id.'''
        column = Cols.query.filter_by(id=id, table_id=self.id).first()

        if column:
            return (column, "Column found")
        return (None, "Column not found")

    def get_columns(self):
        '''Return the columns of the table.'''
        if self.columns:
            return (self.columns, "Found")
        return (None, "You don't have any columns yet")

    def add_column(self, name, current_user_email):
        '''Add a column to the table.'''
        if self.creator == current_user_email or (self.get_member_by_email(current_user_email) and self.get_member_by_email(current_user_email).get_member_role() in ("admin", "editor")):
            if name:
                column = Cols(name=name, table_id=self.id)
                is_column, _ = self.get_column_by_name(name)

                if not is_column:
                    db.session.add(column)
                    db.session.commit()
                    return (column, "Column '{}' successfully created".format(name))
                return (None, "You already have a column with name: '{}'".format(name))
            return (None, "Looks like you did not give us a column name")
        return (None, "You don't have the right to add a column")

    def delete_column_by_name(self, name, current_user_email):
        '''Remove the column from the list of the table's columns.'''
        if self.creator == current_user_email or (self.get_member_by_email(current_user_email) and self.get_member_by_email(current_user_email).get_member_role() in ("admin", "editor")):
            if name:
                col = db.session.query(Cols).filter(Cols.name == name,
                                                    Cols.table_id == self.id).first()

                if col:
                    db.session.delete(col)
                    db.session.commit()
                    return (True, "'{}' successfully deleted".format(name))
                return (False, "The column you want to delete does not exist")
            return (None, "Looks like you did not give us a column name")
        return (None, "You don't have the right to delete this column")

    def get_member_by_email(self, email):
        '''Return the member that matches the email or None if do not exist.'''
        members, _ = self.get_members()

        if not members:
            return None

        for member in members:
            if member.get_member_id() == email:
                return member
        return None

    def get_members(self):
        '''Return table's members if the table is shared,
           and if there is any.'''
        if self.shared and self.members:
            return (self.members, "Found")
        return (None, '''This table is either not shared,
                      or do not have any member yet''')

    def add_member(self, new_member_email, current_user_email):
        '''Add a column to the table.'''
        if self.creator == current_user_email or (self.get_member_by_email(current_user_email) and self.get_member_by_email(current_user_email).get_member_role() == "admin"):
            if self.shared and new_member_email:
                if new_member_email == self.creator:
                    if self.get_member_by_email(new_member_email):
                        return (None, 'You cannot add the creator !')
                    member = Members(table_id=self.id,
                                     user_id=new_member_email, role='creator')
                    db.session.add(member)
                    db.session.commit()
                    return (member, "Ok")
                else:
                    member = Members(table_id=self.id,
                                     user_id=new_member_email,
                                     role='visitor')
                is_member = self.get_member_by_email(new_member_email)

                if is_member:
                    return (None, " '{}' is already a member".format(new_member_email))

                return (member, "Ok")

            return (None, '''Looks like you did not give us an email,
                           or maybe you're trying to add members to a private
                           table''')
        return (None, "You don't have the right to add new members")

    def delete_member_by_email(self, email, current_user_email):
        '''Remove a member from the list of the table's members.'''
        if self.creator == current_user_email or (self.get_member_by_email(current_user_email) and self.get_member_by_email(current_user_email).get_member_role() == "admin"):
          if email == self.creator:
              return (False, 'You cannot delete the creator')

          member = db.session.query(Members).filter(Members.user_id == email,
                                                    Members.table_id == self.id
                                                    ).first()

          if member:
              db.session.delete(member)
              db.session.commit()
              return (True, "member deleted")
          return (False, "something went wrong, please try again later")
        return (False, "You don't have the right to add new members")

    def set_member_as_admin(self, member_email, current_user_email):
      '''Grant member with admin privileges'''
      if self.creator == current_user_email or (self.get_member_by_email(current_user_email) and self.get_member_by_email(current_user_email).get_member_role() == "admin"):
        if member_email == self.creator:
              return (False, 'You cannot change the status of the creator')
        
        member = db.session.query(Members).filter(Members.user_id == member_email,
                                                    Members.table_id == self.id
                                                    ).first()
        if member:
            member.set_member_role("admin")
            db.session.add(member)
            db.session.commit()
            return (True, "{} granted 'admin' privileges".format(member_email))
        return (False, "something went wrong, please try again later")
      return (False, "You don't have the right to change member's role on this table")

    def set_member_as_editor(self, member_email, current_user_email):
      '''Grant member with editor privileges'''
      if self.creator == current_user_email or (self.get_member_by_email(current_user_email) and self.get_member_by_email(current_user_email).get_member_role() == "admin"):
        if member_email == self.creator:
              return (False, 'You cannot change the status of the creator')
        
        member = db.session.query(Members).filter(Members.user_id == member_email,
                                                    Members.table_id == self.id
                                                    ).first()
        if member:
            member.set_member_role("editor")
            db.session.add(member)
            db.session.commit()
            return (True, "{} granted 'editor' privileges".format(member_email))
        return (False, "something went wrong, please try again later")
      return (False, "You don't have the right to change member's role on this table")


    def set_member_as_visitor(self, member_email, current_user_email):
      '''Grant member with visitor privileges'''
      if self.creator == current_user_email or (self.get_member_by_email(current_user_email) and self.get_member_by_email(current_user_email).get_member_role() == "admin"):
        if member_email == self.creator:
              return (False, 'You cannot change the status of the creator')
        
        member = db.session.query(Members).filter(Members.user_id == member_email,
                                                    Members.table_id == self.id
                                                    ).first()
        if member:
            member.set_member_role("visitor")
            db.session.add(member)
            db.session.commit()
            return (True, "{} granted 'visitor' privileges".format(member_email))
        return (False, "something went wrong, please try again later")
      return (False, "You don't have the right to change member's role on this table")


    def share(self, current_user_email):
        if not self.shared:
            self.shared = True
            self.add_member(current_user_email, current_user_email)
            db.session.commit()

    def rename(self, name):
        '''Rename the table if there is no existing table with the same name
           already '''
        if name:
            table = Tables.query.filter_by(name=name).first()

            if table is None:
                self.name = name
                db.session.commit()
                return (self, "Updated successfully !")
            return (None, "A table with name: '{}' already exists".format(name))
        return (None, "Looks like you did not give us a table name")

    def to_dict(self, current_user_email):
        member = self.get_member_by_email(current_user_email)

        if member:
            current_user_role = member.get_member_role()
        else:
            current_user_role = 'visitor'
        return {'id': self.id,
                'name': self.name,
                'creator': self.creator,
                'columns': [col.to_dict() for col in self.columns],
                'members': [memb.to_dict() for memb in self.members],
                'current_user_role': current_user_role
                }
