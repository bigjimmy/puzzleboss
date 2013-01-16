#!/usr/bin/env perl

use PB::Config;
use PB::API;

my $evalstr = join(" ",@ARGV);
print STDERR "evaling $evalstr\n";
eval($evalstr);
