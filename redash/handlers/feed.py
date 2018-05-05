from itertools import chain

from flask import request, url_for
from funcy import distinct, project, take
from flask_login import login_required
from flask_restful import abort
from redash import models, serializers, settings
from redash.handlers.base import BaseResource, get_object_or_404
from redash.permissions import (can_modify, require_admin_or_owner,
                                require_object_modify_permission,
                                require_permission)
from sqlalchemy.orm.exc import StaleDataError
import logging
logger = logging.getLogger('test')

class FeedListResource(BaseResource):
    def post(self):
        """
        Lists dashboards,Queryies.
        """
        query_results = models.Query.all_queries(self.current_user.group_ids)
        dashboards = models.Dashboard.all(self.current_org, self.current_user.group_ids, self.current_user.id)

        results = [q.to_feed_dict() for q in query_results]
        dashboards_results = [q.to_feed_dict() for q in dashboards]

        return results + dashboards_results
