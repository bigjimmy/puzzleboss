#!/bin/bash

export PERL5LIB='.:/canadia/puzzleboss/lib'

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')
mysqldump --add-drop-database --skip-definer -d --databases $PB_DATA_DB_NAME -u $PB_DATA_DB_USER -P $PB_DATA_DB_PORT -h $PB_DATA_DB_HOST --password=$PB_DATA_DB_PASS > $PB_PATH/db/puzzlebossnew
cat $PB_PATH/db/puzzlebossnew | sed s/AUTO_INCREMENT=[[:digit:]]*//g | sed s/$PB_DATA_DB_NAME/\$PB_DATA_DB_NAME/g > $PB_PATH/db/puzzleboss.create.sql-template
rm -rf $PB_PATH/db/puzzlebossnew

