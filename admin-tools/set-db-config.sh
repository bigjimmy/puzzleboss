#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

perl -MPB::Config -e 'PB::Config::export_to_sql();' | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS puzzlebitch$PB_DEV_VERSION

