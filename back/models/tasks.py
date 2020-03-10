from database import DATABASE as db


class Tasks(db.Model):
    __tablename__ = "tasks"
    id = db.Column(db.Integer, primary_key=True)
    description = db.Column(db.Text, nullable=False)
    column_id = db.Column(db.Integer, db.ForeignKey('columns.id'))

    def get_id(self):
        '''Return the task's id.'''
        return self.id

    def get_description(self):
        '''Return the task's description.'''
        return self.description

    def to_dict(self):
        return {'id': self.id,
                'description': self.description,
                'column_id': self.column_id}
