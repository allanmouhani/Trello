from database import DATABASE as db
from models.tasks import Tasks


class Columns(db.Model):
    __tablename__ = "columns"
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Text, nullable=False)
    table_id = db.Column(db.Integer, db.ForeignKey('tables.id'))
    tasks = db.relationship('Tasks', backref=db.backref('column'),
                            cascade='all,delete', lazy=True)

    def get_name(self):
        '''Return the column's name.'''
        return self.name

    def get_task_by_id(self, id):
        '''Return the task that matches the name.'''
        task = Tasks.query.filter_by(id=id, column_id=self.id).first()

        if task:
            return (task, "Task found")
        return (None, "Task not found")

    def get_tasks(self):
        '''Return the tasks of the column.'''
        if self.tasks:
            return (self.tasks, "Found")
        return (None, "You don't have any tasks yet")

    def add_task(self, description):
        '''Add a task to the column.'''
        if description:
            task = Tasks(description=description, column_id=self.id)
            db.session.add(task)
            db.session.commit()

            return (task, "Task successfully added")
        return (None, "You did not give a description to the task")

    def remove_task_by_id(self, id):
        '''Remove the task matching id from the list of the column's tasks.'''
        task, _ = self.get_task_by_id(id)

        if task:
            db.session.delete(task)
            db.session.commit()
            return True
        return False

    def move_task_to(self, task_id, column):
        '''Move the task matching id to a new column.'''
        task, _ = self.get_task_by_id(task_id)

        if task and column:
            new_task, _ = column.add_task(task.get_description())
            self.remove_task_by_id(task_id)
            return new_task
        return None

    def to_dict(self):
        return {'id': self.id,
                'name': self.name,
                'table_id': self.table_id,
                'tasks': [task.to_dict() for task in self.tasks],
                }
