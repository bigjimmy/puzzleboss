#!/usr/bin/perl -w 

use strict;
use warnings;

use lib qw(.);
BEGIN {
    require 'pblib.cfg';
}

use CGI ':standard';

use Data::Validate::URI qw(is_uri);

use PB::API;
use PB::Config;

my $puzzid="";
if(param('puzzid')) {
    $puzzid = param('puzzid');
}
my $round="";
if(param('round')) {
    $round = param('round');
}
#we only really have one meaningful template as of 2010.
my $template="GenericPuzzleTopicTemplate";
if(param('template')) {
    $template = param('template');
}
my $puzzurl="";  
if(param('puzzurl')) {
    $puzzurl = param('puzzurl'); 
}
my $solver="";  
if($ENV{'REMOTE_USER'}) {
    $solver = $ENV{'REMOTE_USER'};
}


my $cleanpuzzurl = is_uri($puzzurl) || "";
if(($puzzid eq "") || ($round eq "") || ($template eq "") || ($cleanpuzzurl eq "") || ($round eq "Choose Round")) {
    print header;
    print start_html(-title=>"Add Puzzle");
    # fix puzzle id from title
    $puzzid =~ s/^.+\:\ //g;
    $puzzid =~ s/\W//g;
    $puzzid =~ s/\_//g;
    $puzzid =~ s/\-//g;
    $puzzid =~ s/\ //g;
    if ($round eq "Choose Round"){
		print "<b>Please select a round.</b>\n";
    }
    if ($cleanpuzzurl ne $puzzurl) {
	print "<b>URL does not validate, please correct!</b>\n";
    }
    print newpuzzform($puzzid, $round, $template, $puzzurl);
    print end_html;
} else {
    # Clean up user-entered puzzid
    $puzzid =~ s/\://g;
    $puzzid =~ s/\W//g;
    $puzzid =~ s/\_//g;
    $puzzid =~ s/\-//g;
    $puzzid =~ s/\ //g;
    # safety check and untaint vars
    $puzzid =~ m/^([A-Z][[:alnum:]]*)$/;
    $puzzid = $1;
    $round =~ m/^([A-Z][[:alnum:]]*)$/;
    $round = $1;
    $template =~ m/^([A-Z][[:alnum:]]*)$/;
    $template = $1;
    if(! ((my $rval = PB::API::add_puzzle($puzzid, $round, $cleanpuzzurl, $template)) < 0)) {
#	if(! ($solver eq "")) {
#	    # put the adding solver on the status line if we know them
#	    my $statusline = "Puzzle added to tracking system by $solver";
#	    PB::API::assign_solver_puzzle($puzzid, $statusline);
#	}
	my $twikiurl = "/twiki/bin/view/$PB::Config::TWIKI_WEB/".$puzzid."Puzzle";
	print header(-Refresh=>"5; URL=$cleanpuzzurl");
	print start_html(-title=>"Add Puzzle");
	print "Puzzle $puzzid successfully added!  Returning you to the page you came from in 5 seconds unless you would rather go to the <a href=\"$twikiurl\">puzzle twiki page</a>!\n";
    	print end_html;
    } else {
	print header;
	print start_html(-title=>"Add Puzzle");
	if($rval == -3) {
	    print "Could not add puzzle $puzzid to TWiki round page (but puzzle was successfully entered in the db, please do NOT attempt to add again).\n";
	} elsif($rval == -4) {
	    print "Could not add puzzle $puzzid to TWiki (but puzzle was successfully entered in the db, please do NOT attempt to add again).\n";
	} else {
	    print "Error adding puzzle $puzzid, please retry. (error $rval)\n";
	    print newpuzzform($puzzid, $round, $template, $puzzurl);
	}
	print end_html;
    }
}

sub newpuzzform {
    my $puzzid = shift;
    my $round = shift;
    my $template = shift;
    my $puzzurl = shift;
    my $str;
    $str .= "<table><tr><th>Puzzle ID</td><th>Round</th><th>URI</th></tr><tr>\n";
    $str .= "<form action=\"newpuzzle.pl\" method=\"post\">\n";
    $str .= "<td><INPUT TYPE=\"text\" NAME=\"puzzid\" VALUE=\"$puzzid\"/></td>\n";
    my @rounds = PB::API::get_round_list();
    unshift @rounds, "Choose Round";
    $str .= "<td>".build_selector("round",$round,\@rounds)."</td>\n";
    #my @templates = PB::API::get_template_list();
    #$str .= "<td>".build_selector("template",$template,\@templates)."</td>\n";
    $str .= "<td><INPUT TYPE=\"text\" NAME=\"puzzurl\" VALUE=\"$puzzurl\"/></td>\n";
    $str .= "<td><INPUT TYPE=\"submit\" NAME=\"Add Puzzle\" VALUE=\"Add Puzzle\"/></td>\n";
    $str .= "</form>\n";
    $str .= "</tr></table>\n";
    $str .= "<h2>After pressing &quot;Add Puzzle&quot; please wait for the server to finish adding the puzzle.</h2><p>It can easily take 10-60s to create the puzzle, depending on how busy our server and the Google Documents server are.  Please do not push the button twice or press back or reload on your browser.</p>\n";
    return($str);
}

sub build_selector {
    my $name = shift;
    my $value = shift;
    my $optionarrayref = shift;
    my @options = @$optionarrayref;
    my $html = "";
    $html .= "<SELECT NAME=\"$name\">\n";
    foreach(@options) {
	my $optval = $_;
	$html .= "   <OPTION VALUE=\"$optval\"";
	if($optval eq $value) {
	    $html .= " SELECTED";
	}
	$html .= ">$optval</OPTION>\n";
    }
    $html .= "</SELECT>\n";
    return($html);
}    


