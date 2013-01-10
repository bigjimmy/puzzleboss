#!/usr/bin/env perl

BEGIN {
    use lib $ENV{'PB_PATH'}."/bin";
    require 'pblib.cfg';
}

use PB::Config;
use PB::API;

my $userlist = PB::API::ldap_get_user_list();

foreach my $user (@$userlist) {
    PB::API::add_solver($user);
}
