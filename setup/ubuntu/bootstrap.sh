#!/bin/bash
#
# This script setups Redash along with supervisor, nginx, PostgreSQL and Redis. It was written to be used on
# Ubuntu 16.04. Technically it can work with other Ubuntu versions, but you might get non compatible versions
# of PostgreSQL, Redis and maybe some other dependencies.
#
# This script is not idempotent and if it stops in the middle, you can't just run it again. You should either
# understand what parts of it to exclude or just start over on a new VM (assuming you're using a VM).

set -eu

REDASH_BASE_PATH=/opt/redash
ANALYSE_ETHER_REPO_GIT=https://github.com/analyseether/redash-3.git
ANALYSE_ETHER_REPO_NAME=redash-3
ANALYSE_ETHER_CURRENT_REPO=$REDASH_BASE_PATH/$ANALYSE_ETHER_REPO_NAME
FILES_BASE_URL=setup/ubuntu/files

cd /tmp/

verify_root() {
    # Verify running as root:
    if [ "$(id -u)" != "0" ]; then
        if [ $# -ne 0 ]; then
            echo "Failed running with sudo. Exiting." 1>&2
            exit 1
        fi
        echo "This script must be run as root. Trying to run with sudo."
        sudo bash "$0" --with-sudo
        exit 0
    fi
}

create_redash_user() {
    adduser --system --no-create-home --disabled-login --gecos "" redash
}

install_system_packages() {
    apt-get -y update
    # Base packages
    apt install -y python-pip python-dev nginx curl build-essential pwgen
    # Data sources dependencies:
    apt install -y libffi-dev libssl-dev libmysqlclient-dev libpq-dev freetds-dev libsasl2-dev
    # SAML dependency
    apt install -y xmlsec1
    # Storage servers
    apt install -y postgresql redis-server
    apt install -y supervisor
    apt-get install -y npm nodejs-legacy
}

extract_redash_sources() {
    mkdir -p "$REDASH_BASE_PATH"
    chown redash "$REDASH_BASE_PATH"

    git clone $ANALYSE_ETHER_REPO_GIT
    mv "$ANALYSE_ETHER_REPO_NAME" "$ANALYSE_ETHER_CURRENT_REPO"
    ln -nfs "$ANALYSE_ETHER_REPO_NAME" "$REDASH_BASE_PATH/current"

}

setup_env_file() {
    # Default config file
    if [ ! -f "$REDASH_BASE_PATH/.env" ]; then
        cp "$ANALYSE_ETHER_CURRENT_REPO/$FILES_BASE_URL/env" "$REDASH_BASE_PATH/.env"
    fi

    COOKIE_SECRET=$(pwgen -1s 32)
    echo "export REDASH_COOKIE_SECRET=$COOKIE_SECRET" >> "$REDASH_BASE_PATH/.env"
    # set the database url before hand
    echo "export REDASH_DATABASE_URL=$DATABASE_URL" >> "$REDASH_BASE_PATH/.env"

    ln -nfs "$REDASH_BASE_PATH/.env" "$REDASH_BASE_PATH/current/.env"
}

install_python_packages() {
    pip install --upgrade pip
    # TODO: venv?
    pip install setproctitle # setproctitle is used by Celery for "pretty" process titles
    pip install -r $REDASH_BASE_PATH/current/requirements.txt
    pip install -r $REDASH_BASE_PATH/current/requirements_all_ds.txt
}

# For local database
# We now use an external RDS for scalability: https://discuss.redash.io/t/walkthrough-for-using-rds-as-a-backend/18/2
create_database() {
    # Create user and database
#    sudo -u postgres createuser redash --no-superuser --no-createdb --no-createrole
#    sudo -u postgres createdb redash --owner=redash

    cd $REDASH_BASE_PATH/current
    sudo -u redash bin/run ./manage.py database create_tables
}

npm_build() {
    cd $REDASH_BASE_PATH/current
    npm install
    npm run build
}

setup_supervisor() {
    cp "$ANALYSE_ETHER_CURRENT_REPO/$FILES_BASE_URL/supervisord.conf" /etc/supervisor/conf.d/redash.conf
    service supervisor restart
}

setup_nginx() {
    rm /etc/nginx/sites-enabled/default
    cp "$ANALYSE_ETHER_CURRENT_REPO/$FILES_BASE_URL/nginx_redash_site" /etc/nginx/sites-available/redash
    ln -nfs /etc/nginx/sites-available/redash /etc/nginx/sites-enabled/redash
    service nginx restart
}

verify_root
install_system_packages
create_redash_user
extract_redash_sources
setup_env_file
install_python_packages
create_database
npm_build
setup_supervisor
setup_nginx

sudo supervisorctl restart all
