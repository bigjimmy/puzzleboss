#!/usr/bin/env perl

BEGIN {
    use lib $ENV{'PB_PATH'}."/bin";
    require 'pblib.cfg';
}

use PB::Config;
use PB::API;

eval(shift());
