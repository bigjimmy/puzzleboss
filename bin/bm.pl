#!/usr/bin/perl -w

use strict;
use warnings;

use lib qw(.);
BEGIN {
    require 'pblib.cfg';
}

use CGI ':standard';

use PB::API;
use PB::Config;

my $html = <<"EOF";
Content-type: text/html

<html>
<head><title>$PB::Config::TWIKI_WEB PuzzleBoss$PB::Config::PB_DEV_VERSION Bookmarklets</title></head>
<body>
<a href="javascript:location.href='$PB::Config::PB_BIN_URI/newpuzzle.pl?puzzurl='+encodeURIComponent(location.href)+'&puzzid='+encodeURIComponent(document.title)">$PB::Config::TWIKI_WEB$PB::Config::PB_DEV_VERSION post new puzzle</a>
</body>
</html>
EOF

print $html;
