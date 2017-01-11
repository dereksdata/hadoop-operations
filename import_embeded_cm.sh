#!/bin/bash
echo "Postgres import from embedded Cloudera Manager Postgresql database export"

if [ "$1" == "--help" ] || [ "$1" == "-?" ] || [ "$1" == "-h" ]; then
    echo "Usage import_embeded_cm.sh [backup file]"
    echo "  e.g. import_embeded_cm.sh /data/backup/cloudera-scm-server-db.backup.xxxx.backup.gz "
    echo
    exit 0
fi

if [[ $USER != "postgres" ]]; then echo "Requires execution as postgres user account. Exiting."; exit 1 ; fi

if [ ! -f "$1" ]; then
    echo "Specified database backup file not found $1. Exiting"
    exit 1
fi

read -p "Continue [Y/N]?" -n 1 -r

if [[ $1 =~ \.gz$ ]]; then
    echo "Extracting gzipped backup"
    gzip -d $1 
    $1=$(echo $1 | sed 's/\.[^.]*$//')
fi

echo "Importing exported embedded databased to this Postgresql instance"
psql -f $1 postgres

echo "Completed"