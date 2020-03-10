from database import DATABASE as db


class Members(db.Model):
    __tablename__ = "members"
    id = db.Column(db.Integer, primary_key=True)
    table_id = db.Column(db.Integer, db.ForeignKey('tables.id'),
                         nullable=False)
    user_id = db.Column(db.Text, db.ForeignKey('users.email'), nullable=False)

    # Can be either 'creator', 'admin', 'editor' or 'visitor'
    role = db.Column(db.String(20), nullable=False)

    def get_table_id(self):
        return self.table_id

    def get_member_id(self):
        return self.user_id

    def get_member_role(self):
        return self.role

    def set_member_role(self, role):
        self.role = role

    def to_dict(self):
        return {'id': self.id,
                'table_id': self.table_id,
                'member_email': self.user_id,
                'member_role': self.role,
                }
