#!/bin/bash

export PERL5LIB='.:/canadia/puzzleboss/lib'

echo "==WARNING!!!===WARNING!!!===WARNING!!!===WARNING=="
echo "Running this command will ERASE ALL PROGRESS AND DATA FROM PB."
echo "DO NOT DO THIS DURING HUNT!"

echo "Enter the phrase IWANTTODESTROYTHEHUNT to continue:"
read PHRASE

if [[ $PHRASE != "IWANTTODESTROYTHEHUNT" ]]; then
	echo "ABORTED."
	exit 2
	else echo "OK. You asked for it."
fi

#STOP everything!
sudo /etc/init.d/apache2 stop
ssh -t series-of-tubes-internal.wind-up-birds.org "sudo /etc/init.d/bigjimmy stop"


#Load current config
eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

#Dump tables to preserve

echo "Dumping solver and discord_users tables to $PB_PATH/backup/sometables.$$.sql"
mysqldump -h $PB_DATA_DB_HOST -u $PB_DATA_DB_USER -P $PB_DATA_DB_PORT -p$PB_DATA_DB_PASS --add-drop-table puzzleboss discord_users > $PB_PATH/backup/sometables.$$.sql

#Drop and Re-create database using the sql template
echo "Destroying database and reloading saved schema"
cat $PB_PATH/db/puzzleboss.create.sql-template | perl -pi -e 's/\$PB_DATA_DB_NAME/'$PB_DATA_DB_NAME'/g' | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS

#Restore previously preserved tables
echo "Restoring solver and discord_users tables"
cat $PB_PATH/backup/sometables.$$.sql | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS puzzleboss

#Initialize config (in database) 
$PB_ADMIN_TOOLS_PATH/set-db-config.sh

#Reset meteor log index and restart
$PB_ADMIN_TOOLS_PATH/reset-log-index.sh
ssh -t series-of-tubes-internal.wind-up-birds.org "sudo /etc/init.d/meteord stop"
ssh -t series-of-tubes-internal.wind-up-birds.org "sudo /etc/init.d/meteord start"

#Start up bigjimmy the google drive monitor
ssh -t series-of-tubes-internal.wind-up-birds.org "sudo /etc/init.d/bigjimmy start"

#restart apache for good measure
sudo /etc/init.d/apache2 start
