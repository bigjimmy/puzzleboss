#!/usr/bin/env perl

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use PB::Config;
use PB::API;

my $user_from = shift;
my $user_to   = shift;

foreach my $usernum ($user_from .. $user_to) {
    my $user = "TestUser" . $usernum;
    PB::API::add_solver($user);
}

