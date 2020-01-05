#!/usr/bin/env perl

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use PB::Config;
use PB::API;

my $evalstr = join(" ",@ARGV);
print STDERR "evaling $evalstr\n";
eval($evalstr);
