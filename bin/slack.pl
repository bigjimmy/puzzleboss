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


my $html_start = <<"EOF";
Content-type: text/html

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>

EOF

print $html_start;
my $pid = 0;

if (param('pid')){
	$pid = param('pid');
}else{
	print "</head><body>No Puzzle-ID parameter supplied</body></html>";
	exit;
}


my $puzzlerow_ref = PB::API::get_puzzle($pid);
my %puzzlerow = %$puzzlerow_ref;

my $slack_link = "http://importanthuntpoll.slack.com/archives/".%puzzlerow{'slack_channel_id'};

print "<meta http-equiv='refresh' content='1;".$slack_link."'>";
print "</head><body>";

print "You should be automatically redirected, otherwise: <a href='".$slack_link."'>slack chat for puzzle</a><br>"; 

print "</body></html>";

exit;
