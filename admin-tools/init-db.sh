#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

####DISABLED cat $PB_PATH/db/puzzlebitch.create.sql-template | perl -pi -e 's/\$PB_DATA_DB_NAME/'$PB_DATA_DB_NAME'/g' | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS

$PB_ADMIN_TOOLS_PATH/set-db-config.sh

