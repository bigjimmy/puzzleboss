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
<title>Recent Activity</title>
</head>

EOF

print $html_start;
my $pid = 0;

if (param('pid')){
	$pid = param('pid');
}else{
	print "<body>No Puzzle-ID parameter supplied</body></html>";
	exit;
}

print "<body>";

my $activityrows_ref = PB::API::get_puzzle_activity($pid);
my @activityrows = @$activityrows_ref;

if (@activityrows < 1){
print "<body>No activity for puzzle or error fetching</body></html>";
exit;
}

my $puzzlerow_ref = PB::API::get_puzzle_info($pid);
my %puzzlerow = %$puzzlerow_ref;
print "Recent Activity History for puzzle: $puzzlerow{'name'}<br>\n";

print "<table border=1><tr><th>Time</th><th>Solver</th><th>Activity</th></tr>\n";
foreach my $rowref (@activityrows) {
my %row = %$rowref;
print "<tr><td>$row{'time'}</td><td>$row{'solver'}</td><td>$row{'activity'}</td></tr>\n";
}
print "</table>";

print "</body></html>";

exit;
