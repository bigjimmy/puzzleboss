#!/usr/bin/perl -w 

use strict;
use warnings;

use lib qw(.);
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));

BEGIN {
    require 'pblib.cfg';
}

use CGI ':standard';

use Data::Validate::URI qw(is_uri);

use PB::API;
use PB::Config;

my %known_errors;
$known_errors{"-102"} = "Duplicate entry.";
$known_errors{"-200"} = "Slack creation failure.";

my $puzzid = "";
if (param('puzzid')) {
    $puzzid = param('puzzid');
}
my $round = "";
if (param('round')) {
    $round = param('round');
}
my $puzzurl = "";
if (param('puzzurl')) {
    $puzzurl = param('puzzurl');
}

my $cleanpuzzurl = is_uri($puzzurl) || "";
if (   ($puzzid eq "")
    || ($round eq "")
    || ($cleanpuzzurl eq "")
    || ($round eq "Choose Round"))
{
    print header;
    print start_html(-title => "Add Puzzle");

    # fix puzzle id from title
    $puzzid =~ s/[[:space:]][-][-][[:space:]].+$//g;
    $puzzid =~ s/\://g;
    $puzzid =~ s/\W//g;
    $puzzid =~ s/\_//g;
    $puzzid =~ s/\-//g;
    $puzzid =~ s/\ //g;
    if ($round eq "Choose Round") {
        print "<b>Please select a round.</b>\n";
    }
    if ($cleanpuzzurl ne $puzzurl) {
        print "<b>URL does not validate, please correct!</b>\n";
    }
    print newpuzzform($puzzid, $round, $puzzurl);
    print end_html;
} else {

    # Clean up user-entered puzzid
    $puzzid =~ s/\://g;
    $puzzid =~ s/\W//g;
    $puzzid =~ s/\_//g;
    $puzzid =~ s/\-//g;
    $puzzid =~ s/\ //g;
    if (!((my $rval = PB::API::add_puzzle($puzzid, $round, $cleanpuzzurl)) < 0))
    {
        print header(-Refresh => "5; URL=$cleanpuzzurl");
        print start_html(-title => "Add Puzzle");
        print
"Puzzle $puzzid successfully added!  Returning you to the page you came from in 5 seconds unless you would rather go to hell!\n";
        print end_html;
    } else {
        print header;
        print start_html(-title => "Add Puzzle");
        print
"Error adding puzzle $puzzid to round $round with url $cleanpuzzurl please retry.\n<br>";
        if ($known_errors{$rval}) {
            print "Error: $known_errors{$rval}\n";
        } else {
            print
"Unknown error: code=$rval, search logs for \"_add_puzzle_db\" for more information.\n";
        }
        print newpuzzform($puzzid, $round, $puzzurl);
    }
    print end_html;
}

sub newpuzzform {
    my $puzzid  = shift;
    my $round   = shift;
    my $puzzurl = shift;
    my $str;
    $str .=
      "<table><tr><th>Puzzle ID</td><th>Round</th><th>URI</th></tr><tr>\n";
    $str .= "<form action=\"newpuzzle.pl\" method=\"post\">\n";
    $str .=
      "<td><INPUT TYPE=\"text\" NAME=\"puzzid\" VALUE=\"$puzzid\"/></td>\n";
    my @rounds = PB::API::get_round_list();
    unshift @rounds, "Choose Round";
    $str .= "<td>" . build_selector("round", $round, \@rounds) . "</td>\n";
    $str .=
      "<td><INPUT TYPE=\"text\" NAME=\"puzzurl\" VALUE=\"$puzzurl\"/></td>\n";
    $str .=
"<td><INPUT TYPE=\"submit\" NAME=\"Add Puzzle\" VALUE=\"Add Puzzle\"/></td>\n";
    $str .= "</form>\n";
    $str .= "</tr></table>\n";
    $str .=
"<h2>After pressing &quot;Add Puzzle&quot; please wait for the server to finish adding the puzzle.</h2><p>It can easily take 10-60s to create the puzzle, depending on how busy our server and the Google Documents server are.  Please do not push the button twice or press back or reload on your browser.</p>\n";
    return ($str);
}

sub build_selector {
    my $name           = shift;
    my $value          = shift;
    my $optionarrayref = shift;
    my @options        = @$optionarrayref;
    my $html           = "";
    $html .= "<SELECT NAME=\"$name\">\n";
    foreach (@options) {
        my $optval = $_;
        $html .= "   <OPTION VALUE=\"$optval\"";
        if ($optval eq $value) {
            $html .= " SELECTED";
        }
        $html .= ">$optval</OPTION>\n";
    }
    $html .= "</SELECT>\n";
    return ($html);
}

