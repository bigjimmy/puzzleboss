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

my $title = "PB Solver-o-matic$PB::Config::PB_DEV_VERSION_POSTPAREN : $PB::Config::TEAM_NAME";

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
	var my_ps;
    require({
		waitSeconds: 5,
	    },
		["../js/pb-meteor-rest-client.js", "../js/puzzsolvers.js"],
	    function(pbmrc,ps) {
		pbmrc.pb_set_config("$PB::Config::METEOR_HTTP_HOST", "$PB::Config::METEOR_VERSION_CHANNEL", "$PB::Config::PBREST_ROOT");
		my_pbmrc = pbmrc;
		my_ps = ps;
		ps.my_init();
	    });	

    </script>
</head>
<body class="tundra">
    <h1>$title</h1>
    <div id="waitDiv"><b>Please wait, while data loads. (This could take a while!)</b></br></div>
    <div id="poolcontainer">
    <h2>Solver Pool</h2>
    </div>

    <div id="puzzles_layout">
    <h2>Unsolved Puzzles</h2>
    </div>

    <div id="statuscontainer"></div>
</body>
</html>

EOF

print $html;
