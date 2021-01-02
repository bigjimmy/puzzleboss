#!/usr/bin/perl -w

use strict;

use lib qw(.);
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

BEGIN {
    require 'pblib.cfg';
}

use CGI::Application::Dispatch;

CGI::Application::Dispatch->dispatch(
    prefix    => 'PB::REST',
    auto_rest => 1,
    table     => [
        ':app'           => { rm => 'list' },
        ':app/:id'       => { rm => 'full' },
        ':app/:id/:part' => { rm => 'part' },
    ]
);

