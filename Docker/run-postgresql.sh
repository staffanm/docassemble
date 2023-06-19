#!/bin/bash

export CONTAINERROLE=":${CONTAINERROLE:-all}:"
export DA_ROOT="${DA_ROOT:-/usr/share/docassemble}"
export DA_DEFAULT_LOCAL="local3.10"

export DA_ACTIVATE="${DA_PYTHON:-${DA_ROOT}/${DA_DEFAULT_LOCAL}}/bin/activate"
export DA_CONFIG_FILE="${DA_CONFIG:-${DA_ROOT}/config/config.yml}"
source /dev/stdin < <(su -c "source \"${DA_ACTIVATE}\" && python -m docassemble.base.read_config \"${DA_CONFIG_FILE}\"" www-data)

source "${DA_ACTIVATE}"

set -- $LOCALE
export LANG=$1

PGVERSION=`pg_config --version | sed 's/PostgreSQL \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/'`

if [[ $PGVERSION == 10* ]]; then
    PGVERSION=10
fi

if [[ $PGVERSION == 11* ]]; then
    PGVERSION=11
fi

if [[ $PGVERSION == 12* ]]; then
    PGVERSION=12
fi

if [[ $PGVERSION == 13* ]]; then
    PGVERSION=13
fi

if [[ $PGVERSION == 14* ]]; then
    PGVERSION=14
fi

chown -R postgres.postgres /etc/postgresql
chown -R postgres.postgres /var/lib/postgresql
chown -R postgres.postgres /var/run/postgresql
chown -R postgres.postgres /var/log/postgresql

function stopfunc {
    if [[ ! $CONTAINERROLE =~ .*:(all):.* ]]; then
	echo "waiting for deregistration" >&2
	sleep 7
    fi
    echo "backing up postgres" >&2
    if [ "${S3ENABLE:-false}" == "true" ] || [ "${AZUREENABLE:-false}" == "true" ]; then
	PGBACKUPDIR=`mktemp -d`
    else
	PGBACKUPDIR="${DA_ROOT}/backup/postgres"
	mkdir -p "$PGBACKUPDIR"
    fi
    chown postgres.postgres "$PGBACKUPDIR"
    su postgres -c 'psql -Atc "SELECT datname FROM pg_database" postgres' | grep -v -e template -e postgres | awk -v backupdir="$PGBACKUPDIR" '{print "cd /tmp; su postgres -c \"pg_dump -F c -f " backupdir "/" $1 " " $1 "\""}' | bash
    if [ "${S3ENABLE:-false}" == "true" ]; then
	s4cmd dsync "$PGBACKUPDIR" "s3://${S3BUCKET}/postgres"
	rm -rf "$PGBACKUPDIR"
    elif [ "${AZUREENABLE:-false}" == "true" ]; then
	for the_file in $(find "$PGBACKUPDIR" -type f); do
	    target_file=`basename $the_file`
	    az storage blob upload --no-progress --overwrite true --only-show-errors --output none --container-name "${AZURECONTAINER}" -f "$the_file" -n "postgres/${target_file}"
	done
	rm -rf "$PGBACKUPDIR"
    fi
    echo "stopping postgres" >&2
    pg_ctlcluster --force $PGVERSION main stop
    exit 0
}

trap stopfunc SIGINT SIGTERM

#source /usr/share/postgresql-common/init.d-functions

if [ -d /var/run/postgresql ]; then
    chmod 2775 /var/run/postgresql
else
    install -d -m 2775 -o postgres -g postgres /var/run/postgresql
fi

mkdir -p "/var/run/postgresql/${PGVERSION}-main.pg_stat_tmp"
chown -R postgres:postgres "/var/run/postgresql/${PGVERSION}-main.pg_stat_tmp"

su postgres -c "/usr/lib/postgresql/${PGVERSION}/bin/postgres -D /var/lib/postgresql/${PGVERSION}/main -c config_file=/etc/postgresql/${PGVERSION}/main/postgresql.conf" &
wait %1
