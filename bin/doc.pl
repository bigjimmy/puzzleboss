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

my $pid = 0;

if (param('pid')) {
    $pid = param('pid');
} else {
    print "Content-type: text/html\n\n";
    print
"<!doctype html><html><body>No Puzzle-ID parameter supplied</body></html>";
    exit;
}

my $puzzlerow_ref = PB::API::get_puzzle($pid);
my %puzzlerow     = %$puzzlerow_ref;

my $doc_link = $puzzlerow{'drive_uri'};

if ($doc_link =~ /google/) {
    print "Location: $doc_link\n\n";
    exit;
} else {
    print "Content-type: text/html\n\n";
    print
"<!doctype html><html><body>No proper doc link found for puzzle id $pid<br><h2>contact puzzleboss immediately to repair bigjimmy bot</h2></body></html>";
    exit;
}

print "Content-type: text/html\n\n";
print "<!doctype html><html><head>\n";
print "<meta http-equiv='refresh' content='1;" . $doc_link . "'>";
print "</head><body>";

print "You should be automatically redirected, otherwise: ";
print "<a href='" . $doc_link . "'>google doc for puzzle</a><br>";

print "</body></html>";

exit;
