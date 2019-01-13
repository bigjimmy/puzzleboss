#!/bin/bash

export PERL5LIB=/canadia/puzzleboss/lib:/canadia/puzzleboss/bin

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

DATE=`date +%s`

mysqldump -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS --all-databases > $PB_PATH/backup/mysqldump.${DATE}

