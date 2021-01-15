#!/bin/bash -e

export PERL5LIB='.:/canadia/puzzleboss/lib'

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

echo "==WARNING!!!===WARNING!!!===WARNING!!!===WARNING=="
echo "Running this command will ERASE ALL PROGRESS AND DATA FROM PB."
echo "DO NOT DO THIS DURING HUNT!"
echo ""
echo "Please verify that you are running this as ROOT from the backend server (series-of-tubes)"
echo ""
echo "Enter the phrase IWANTTODESTROYTHEHUNT to continue:"
read PHRASE

if [[ $PHRASE != "IWANTTODESTROYTHEHUNT" ]]; then
	echo "ABORTED."
	exit 2
	else echo "OK. You asked for it."
fi

#STOP everything!

echo "Stopping s-o-t apache"
/etc/init.d/apache2 stop

echo "Stopping bigjimmy bot"
/etc/init.d/bigjimmy stop


#Load current config
eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

#Dump tables to preserve
echo "Dumping discord_users table to $PB_PATH/backup/sometables.$$.sql"
mysqldump -h $PB_DATA_DB_HOST -u $PB_DATA_DB_USER -P $PB_DATA_DB_PORT -p$PB_DATA_DB_PASS --add-drop-table puzzleboss discord_users > $PB_PATH/backup/sometables.$$.sql

echo "Dumping entire mysql database to $PB_PATH/backup/mysqldump-YYYY-MM-DD-HHMMSS.sql"
mysqldump -h $PB_DATA_DB_HOST -u $PB_DATA_DB_USER -P $PB_DATA_DB_PORT -p$PB_DATA_DB_PASS --add-drop-table puzzleboss > $PB_PATH/backup/mysqldump-`date +%Y-%m-%d-%H%M%S`.sql

#Drop and Re-create database using the sql template
echo "Destroying database and reloading saved schema"
cat $PB_PATH/db/puzzleboss.create.sql-template | perl -pi -e 's/\$PB_DATA_DB_NAME/'$PB_DATA_DB_NAME'/g' | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS

#Restore previously preserved tables
echo "Restoring discord_users table"
cat $PB_PATH/backup/sometables.$$.sql | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS puzzleboss

echo "Re-loading config into database"
#Initialize config (in database) 
$PB_ADMIN_TOOLS_PATH/set-db-config.sh

echo "Resetting meteor log index and restarting meteord"
#Reset meteor log index and restart
$PB_ADMIN_TOOLS_PATH/reset-log-index.sh
pkill -f meteord
/etc/init.d/meteord start

echo "Restarting bigjimmy bot"
#Start up bigjimmy the google drive monitor
/etc/init.d/bigjimmy start

echo "Restarting s-o-t apache"
#restart apache for good measure
/etc/init.d/apache2 start

#Purge puzzcord discord stuff
echo "Purging discord stuff"
$PB_PATH/bin/puzzcord.sh cleanup no really purge

echo "OK, we are all clear for a new hunt. Re-add solvers from LDAP if we're not enforcing a full account purge"

