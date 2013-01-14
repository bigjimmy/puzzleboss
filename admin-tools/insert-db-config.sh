#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

(\
    echo "REPLACE INTO \`config\` (\`key\`,\`val\`) VALUES ('pb_rest_uri','$PBREST_URI');" && \
    echo "REPLACE INTO \`config\` (\`key\`,\`val\`) VALUES ('google_client_id','$GOOGLE_CLIENT_ID');" && \
    echo "REPLACE INTO \`config\` (\`key\`,\`val\`) VALUES ('google_client_secret','$GOOGLE_CLIENT_SECRET');" && \
echo "") | mysql -h $PB_DATA_DB_HOST -P $PB_DATA_DB_PORT -u $PB_DATA_DB_USER -p$PB_DATA_DB_PASS puzzlebitch$PB_DEV_VERSION

