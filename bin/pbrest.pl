#!/usr/bin/perl -w

use strict;

use lib qw(.);
BEGIN {
    require 'pblib.cfg';
}

use CGI::Application::Dispatch;

CGI::Application::Dispatch->dispatch(
    prefix  => 'PB::REST',
    auto_rest => 1,
    table => [
	':app'=> {rm => 'list'},
	':app/:id'=> {rm => 'full'},
	':app/:id/:part'=> {rm => 'part'},
    ]
    );

