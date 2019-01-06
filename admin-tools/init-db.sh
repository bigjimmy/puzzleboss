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

/etc/init.d/bigjimmy stop

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

cat $PB_PATH/db/puzzleboss.create.sql-template | perl -pi -e 's/\$PB_DATA_DB_NAME/'$PB_DATA_DB_NAME'/g' | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS

$PB_ADMIN_TOOLS_PATH/set-db-config.sh

/etc/init.d/bigjimmy start
