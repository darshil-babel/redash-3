from flask.cli import AppGroup
from flask_migrate import stamp
manager = AppGroup(help="Manage the database (create/drop tables).")


@manager.command()
def create_tables():
    """Create the database tables."""
    from redash.models import db
    db.create_all()

    # Need to mark current DB as up to date
    stamp()


@manager.command()
def drop_tables():
    """Drop the database tables."""
    from redash.models import db

    db.drop_all()


@manager.command()
def update_all_usage_limits():
    """Updates all the usage limits in table users."""
    from redash.models import db
    users = db.User.query.all()

    for user in users:
        user.update_data_usage_limit(2.0*1024.0*1024.0)
    db.session.commit()
