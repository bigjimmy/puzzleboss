#!/bin/bash

#channel=`echo \`dirname $(cd ${0%/*} && echo $PWD/${0##*/})\` | perl -n -e 'if(m/puzzlebitch\-(.*?)\//) {print "version-$1";} else {print "version";}'`

pblib="$(cd ${0%/*}/../lib && echo $PWD)"
perl -e 'use lib "'${pblib}'"; use PB::Config; use PB::Meteor; PB::Meteor::message($PB::Config::METEOR_VERSION_CHANNEL, 0);'

