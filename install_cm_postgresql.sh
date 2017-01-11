#!/bin/bash

SetProperty() {
	key=$(printf %s "$1" | sed 's/[][()\.^$?*+]/\\&/g')
	value=$(printf %s "$2" | sed 's/[][()\.^$?*+]/\\&/g')
	if grep -q "$key[ \t]*=" "$3"; then
		sed -c -i "s/\($key[ \t]*=[ \t]*\).*/\1$value/" "$3"
	else		
        sed -i -e '$a\' "$3"
		echo "$1=$2" >> "$3"
	fi
}   

echo "Install dedicated Postgresql for Cloudera Manager"

if [ "$1" == "--help" ] || [ "$1" == "-?" ] || [ "$1" == "-h" ]; then
    echo "Usage install_cm_postgresql.sh [database path]"
    echo "  Database path is optional - used to specify an alternate location for the postgres database"
    echo "  e.g. install_cm_postgresql.sh /data/postgres"
    echo
    exit 0
fi

if [[ $(id -u) -ne 0 ]] ; then echo "Requires execution as sudo or root. Exiting." ; exit 1 ; fi

read -p "Perform Postgresql installation [Y/N]?" -n 1 -r
echo    
if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi

if yum list installed "postgresql-server" >/dev/null 2>&1; then
    echo "Postgres already installed. Exiting."
    exit 1
fi

if [ ! -z "$1" ]; then
    if [ ! -d "$1" ]; then
        echo "Specified database directory not found $1. Exiting"
        exit 1
    fi
fi

yum -y install postgresql-server
service postgresql initdb
service postgresql start

POSTGRES_PATH=$(eval echo "~postgres")
if [ -f $POSTGRES_PATH/data/pg_hba.conf ]; then AUTH_CONF_FILE=$POSTGRES_PATH/data/pg_hba.conf; fi
if [ -f /etc/postgresql/8.4/main ]; then AUTH_CONF_FILE=/etc/postgresql/8.4/main; fi
echo "Auth $AUTH_CONF_FILE"
if [ ! -f $AUTH_CONF_FILE ]; then echo "Postgres auth conf file not found. Exiting"; exit 1; fi

if ! grep -q "host all all 127.0.0.1/32 md5" $AUTH_CONF_FILE; then
    sed -i '1ihost all all 127.0.0.1/32 md5' $AUTH_CONF_FILE
fi

POSTGRES_CONF_FILE=$POSTGRES_PATH/data/postgresql.conf

SetProperty "shared_buffers" "256MB" "$POSTGRES_CONF_FILE"
SetProperty "wal_buffers" "8MB" "$POSTGRES_CONF_FILE"
SetProperty "checkpoint_segments" "16" "$POSTGRES_CONF_FILE"
SetProperty "checkpoint_completion_target" "0.9" 
SetProperty "listen_addresses" "'*'" "$POSTGRES_CONF_FILE"

if [ ! -z "$1" ]; then
    echo "Moving postgres from /usr/local/pgsql/data to $1"
    chown postgres $1
    chmod 700 $1
    mv /usr/local/pgsql/data $1
    ln -s $1 /usr/local/pgsql/data
fi

chkconfig postgresql on
service postgresql restart

echo "Postgres installed. Don't forget to set the password for the postgres user."
echo "sudo -u postgres psql template1"
echo "ALTER USER postgres with encrypted password 'xxxxxxx';"
echo
echo "Modify $POSTGRES_PATH/data/pg_hba.conf if you require access to the database from external hosts (such as a db migration)"
echo
