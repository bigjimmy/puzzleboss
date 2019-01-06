#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

export GOPATH=${PB_BIGJIMMY_PATH}

(cd ${PB_BIGJIMMY_PATH} && go install -gcflags "-N -l" bigjimmybot/bigjimmy-the-google-drive-bot && ./bin/bigjimmy-the-google-drive-bot --dbhost=localhost --dbuser=bigjimmy --dbpassword=fhqwhgads --dbname=puzzleboss -log_level=error)
