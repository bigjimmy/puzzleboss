#!/bin/bash

eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

GOPATH=${PB_BIGJIMMY_PATH}

(cd ${PB_BIGJIMMY_PATH} && go install -gcflags "-N -l" bigjimmybot/bigjimmy-the-google-drive-bot && ./bin/bigjimmy-the-google-drive-bot $@)

