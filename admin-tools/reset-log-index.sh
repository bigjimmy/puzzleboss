#!/bin/bash

perl -e 'use PB::Config; use PB::Meteor; PB::Meteor::message($PB::Config::METEOR_VERSION_CHANNEL, 0);'

