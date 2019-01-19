#!/bin/bash

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
/etc/init.d/apache2 stop
/etc/init.d/bigjimmy stop


eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

cat $PB_PATH/db/puzzleboss.create.sql-template | perl -pi -e 's/\$PB_DATA_DB_NAME/'$PB_DATA_DB_NAME'/g' | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS


#Initialize config (in database) from Config.pm
$PB_ADMIN_TOOLS_PATH/set-db-config.sh

#Reset meteor log index and restart
$PB_ADMIN_TOOLS_PATH/reset-log-index.sh
/etc/init.d/meteord stop
/etc/init.d/meteord start

#Start up bigjimmy the google drive monitor
/etc/init.d/bigjimmy start

#restart apache for good measure
/etc/init.d/apache2 start
