#! /bin/bash

export PERL5LIB="../lib" 

#Load current config
eval $(perl -MPB::Config -e 'PB::Config::export_to_bash();')

echo "$@" | ncat $BIGJIMMY_CONTROL_HOST 2134
