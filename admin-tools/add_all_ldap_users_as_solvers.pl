#!/usr/bin/env perl

use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

use PB::Config;
use PB::API;

my %userlist = PB::API::ldap_get_user_list();

foreach $user (sort keys %userlist) {
    PB::API::add_solver($user,$userlist{$user});
}
