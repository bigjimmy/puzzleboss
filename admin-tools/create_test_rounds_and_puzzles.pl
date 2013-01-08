#!/usr/bin/env perl

use lib qw(../bin);
BEGIN {
    require 'pblib.cfg';
}

use PB::Config;
use PB::API;

foreach my $roundnum ( 1 .. 10 ) {
    my $round = "TestRound".$roundnum;
    PB::API::add_round($round);
    foreach my $puzznum ( 1 .. 20 ) {
	my $puzz = "TestPuzzR".$roundnum."P".$puzznum;
	PB::API::add_puzzle($puzz, $round, 'http://google.com/?q='.$puzz);
    }
}

