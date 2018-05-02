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
    from redash import models
    users = models.User.query.all()

    for user in users:
        user.update_data_usage_limit(1.0*1024.0*1024.0)
    models.db.session.commit()


@manager.command()
def create_non_existing_usernames():
    """Creates usernames for users which do not have them."""
    from redash import models
    users = models.User.query.filter(models.User.username == None)

    for user in users:
        user.username = user.email.split("@")[0]
    models.db.session.commit()
