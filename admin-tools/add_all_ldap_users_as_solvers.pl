#!/usr/bin/env perl

use PB::Config;
use PB::API;

my %userlist = PB::API::ldap_get_user_list();

foreach $user (sort keys %userlist) {
    PB::API::add_solver($user,$userlist{$user});
}
