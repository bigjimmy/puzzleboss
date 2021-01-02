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
<title>Delete Puzzle</title>
</head>
<body>

EOF

print $html_start;
my $pid = "";

if (param('pid')) {
    $pid = param('pid');
} else {
    print "<body>Select puzzle to delete<br><hr>";
    my @rounds = PB::API::get_round_list();
    foreach (@rounds) {
        my $curround = $_;
        print "<b>" . $curround . "</b><br>";

        my @puzzlesinround = PB::API::get_puzzle_list($curround);
        foreach (@puzzlesinround) {
            my $curpuzzlename = $_;
            my $pid           = PB::API::get_puzzle($curpuzzlename)->{"id"};
            print "<form action='deletepuzzle.pl' method='get'>";
            print "<input type='hidden' name='pid' value=$pid>";
            print "Puzzle " . $pid . ": " . $curpuzzlename;
            print "&nbsp";
            print "<input type='submit' value='Delete'>";
            print "</form><br><br>";
        }

        print "<hr>";
    }
    exit;
}

if (param('reallysure') eq 'yes') {
    $pid = param('pid');
    print "<body>Ok. Deleting Puzzle id $pid.</body>";
    my $retval = PB::API::delete_puzzle($pid);
    print "<br>retval=$retval";
    print "</html>";
    exit;
}

my $puzzlerow_ref    = PB::API::get_puzzle_info($pid);
my %puzzlerow        = %$puzzlerow_ref;
my $activityrows_ref = PB::API::get_puzzle_activity($pid);
my @activityrows     = @$activityrows_ref;

if (@activityrows < 1) {
    print
"<body>No google doc activity for puzzle $puzzlerow{'name'} or error fetching<br>";
} else {

    print "Recent Activity History for puzzle: $puzzlerow{'name'}<br>\n";

    print
"<table border=1><tr><th>Time</th><th>Solver</th><th>Activity</th></tr>\n";
    foreach my $rowref (@activityrows) {
        my %row = %$rowref;

        #Exclude "BigJimmy" robot activity
        next if $row{'solver'} eq "BigJimmy";
        print
"<tr><td>$row{'time'}</td><td>$row{'solver'}</td><td>$row{'activity'}</td></tr>\n";
    }
    print "</table>";
}

print
"<br><b>Are you sure you want to delete this puzzle: $puzzlerow{'name'} in round $puzzlerow{'round'}?<br></b>\n";
print "<br><b>THIS IS AN IRREVERSIBLE OPERATION</b></br>";

print "<form action='deletepuzzle.pl' method='get'>";
print "<input type='hidden' name='reallysure' value='yes'>";
print "<input type='hidden' name='pid' value=$pid>";
print "<input type='submit' value='Delete Puzzle'>";
print "</form>";

print "</body></html>";

exit;
