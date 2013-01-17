#!/usr/bin/env perl

use PB::Config;
use PB::API;

my $user_from = shift;
my $user_to = shift;

foreach my $usernum ( $user_from .. $user_to ) {
    my $user = "TestUser".$usernum;
    PB::API::add_solver($user);
}

