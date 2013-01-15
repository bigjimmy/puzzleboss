#!/usr/bin/perl -w                                                                                                                                                              
use strict;
use warnings;

use lib qw(.);
BEGIN {
    require 'pblib.cfg';
}

use PB::Config;
use PB::API;
use CGI qw(:standard:);
use CGI qw(param);
use URI::Escape;

my $debugp="false";
if($PB::Config::PB_DEV_VERSION ne "") {
    $debugp="true";
}

my $hidesolved = "";

if (param('hidesolved')){
        $hidesolved="checked";
}

my $showrounds = "";
if (param('showrounds')){
        $showrounds="checked";
}

my $editable;
my $title = "Hunt Overview$PB::Config::PB_DEV_VERSION_POSTPAREN : $PB::Config::TEAM_NAME";

my $remote_user = $ENV{'REMOTE_USER'};
my $selfuri = uri_escape($PB::Config::PB_BIN_URI."/overview.pl");

my $html = <<"EOF";
Content-type: text/html

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
	<title>$title</title>
	<style type="text/css">
    \@import "$PB::Config::DOJO_ROOT/dijit/themes/tundra/tundra.css";
    \@import "$PB::Config::PB_CSS_REL/pb.css";
	</style>
    <script type="text/javascript" src="$PB::Config::METEOR_JS_URI"></script>
    <script type="text/javascript" src="$PB::Config::DOJO_ROOT/dojo/dojo.js"
            data-dojo-config="async: true, parseOnLoad: true"></script>
	<script type="text/javascript">

		var my_pbmrc;
		var my_overview;
		require({
			waitSeconds: 5,
		},
		["../js/pb-meteor-rest-client.js", "../js/overview.js"],
		function(pbmrc,overview) {
		    pbmrc.pb_set_config("$PB::Config::METEOR_HTTP_HOST", "$PB::Config::METEOR_VERSION_CHANNEL", "$PB::Config::PBREST_ROOT");
			my_pbmrc = pbmrc;
			my_overview = overview;
			overview.my_init("$remote_user");
		});	

	</script>
</head>
<body class="tundra">
    <h1>$title - <a href="/twiki/bin/view" target="_twiki">TWiki</a></h1>
    <div id="adminDiv">Hello, $remote_user. 
    <span id="current_puzzle"></span>
    <span id="take_a_break"></span>
      <p id="logout_span">Not $remote_user? 
        <a href="https://wind-up-birds.org/saml/module.php/core/as_logout.php?AuthId=default-sp&ReturnTo=$selfuri">Logout</a> (or close browser)
      </p>
    </div>
    
	<div id="waitDiv"><b>Please wait, while data loads. (This could take a while!)</b></br></div>

	<div id="summary_layout"></div>
	
	<div id="statuscontainer"></div>
	
	<h2>Help:</h2>
	<span id="overview_legend">
	<b>Status icons: </b>
	New (<img class="pi_icon" src="../images/new.png" >),
	Being worked (<img class="pi_icon" src="../images/work.png">),
	Needs eyes (<img class="pi_icon" src="../images/eyes.png">),
	Solved (<img class="pi_icon" src="../images/solved.png">)
	</span>
</body>
</html>

EOF

    print $html;



