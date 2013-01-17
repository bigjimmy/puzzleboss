#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

cat $PB_PATH/db/puzzlebitch.create.sql | perl -pi -e 's/\$PB_DEV_VERSION/puzzlebitch'$PB_DEV_VERSION'/g' | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS

$PB_ADMIN_TOOLS_PATH/set-db-config.sh

