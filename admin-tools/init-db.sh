#!/bin/bash

cat $PB_PATH/db/puzzlebitch.create.sql | perl -pi -e 's/\$PB_DEV_VERSION/puzzlebitch'$PB_DEV_VERSION'/g' | mysql -u $PB_DB_USER -p$PB_DB_PASS

