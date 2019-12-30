#!/bin/bash

export PERL5LIB='.:/canadia/puzzleboss/lib'

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

export GOPATH=${PB_BIGJIMMY_PATH}:/home/ubuntu/go

(cd ${PB_BIGJIMMY_PATH} && go install -gcflags "-N -l" bigjimmybot/bigjimmy-the-google-drive-bot && ./bin/bigjimmy-the-google-drive-bot --dbhost=mysql.wind-up-birds.org --dbuser=bigjimmy --dbpassword=fhqwhgads --dbname=puzzleboss -log_level=info)
