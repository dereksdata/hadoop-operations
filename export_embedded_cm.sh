#!/bin/bash

echo "Embedded Cloudera Manager Postgresql database export"

if [ "$1" == "--help" ] || [ "$1" == "-?" ] || [ "$1" == "-h" ]; then
    echo "Usage export_embedded_cm.sh [export path]"
    echo "  e.g. export_embedded_cm.sh /data/backup"
    echo
    exit 0
fi

if [[ $(id -u) -ne 0 ]] ; then echo "Requires execution as sudo or root. Exiting." ; exit 1 ; fi

if [ ! -d "$1" ]; then
    echo "Specified export directory not found $1. Exiting"
    exit 1
fi

read -p "Continue [Y/N]?" -n 1 -r
echo    
if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi

read -p "Stop Cloudera Manager [Y/N]?" -n 1 -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]; then 
    service cloudera-scm-server stop  
fi

service cloudera-scm-server-db start 
BACKUP_LOCATION=$1

PGPASSWORD=$(head -n 1 /var/lib/cloudera-scm-server-db/data/generated_password.txt)
PGPASSLINE="127.0.0.1:7432:*:cloudera-scm:$PGPASSWORD"
if [ ! -f ~/.pgpass ]; then
    echo "$PGPASSLINE"  >>  ~/.pgpass
else
    if ! grep -q "$PGPASSWORD" ~/.pgpass; then
        echo "$PGPASSLINE"  >>  ~/.pgpass
    fi
fi 
chmod 0600 ~/.pgpass

DATABASE_BACKUP=$BACKUP_LOCATION/cloudera-scm-server-db.backup.`date +%Y-%m-%d-%H-%M-%S.backup`
echo "Backing up all embedded databases to $DATABASE_BACKUP"
pg_dumpall -h 127.0.0.1 -p 7432 -U cloudera-scm $DATABASE_BACKUP

SCM_BACKUP=$BACKUP_LOCATION/cloudera-scm-server.backup.`date +%Y-%m-%d-%H-%M-%S.tar.gz`
echo "Backing up /var/lib/cloudera-scm-server/ to $SCM_BACKUP"
env GZIP=-9 tar -czf $SCM_BACKUP /var/lib/cloudera-scm-server/

echo "Copying database connection (.properties) files"
cp /etc/cloudera-scm-server/db.properties $BACKUP_LOCATION/db.properties
cp /etc/cloudera-scm-server/db.mgmt.properties $BACKUP_LOCATION/db.mgmt.properties

read -p "Compress database backup [Y/N]?" -n 1 -r
echo    
if [[ ! $REPLY =~ ^[Yy]$ ]]; then 
    echo "Compressing $DATABASE_BACKUP"
    gzip -9 $DATABASE_BACKUP
fi

echo "Export completed"
