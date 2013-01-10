#!/usr/bin/env perl
use lib $ENV{'PB_PATH'}."/bin";
BEGIN {
    require 'pblib.cfg';
}

use PB::Config;
use PB::API;

my $round_from = shift;
my $round_to = shift;
my $puzzle_from = shift;
my $puzzle_to = shift;

foreach my $roundnum ( $round_from .. $round_to ) {
    my $round = "TestRound".$roundnum;
    PB::API::add_round($round);
    foreach my $puzznum ( $puzzle_from .. $puzzle_to ) {
	my $puzz = "TestPuzzR".$roundnum."P".$puzznum;
	PB::API::add_puzzle($puzz, $round, 'http://google.com/?q='.$puzz);
    }
}

