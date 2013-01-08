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

my $editable;
my $title;
if (param('edit')){
	$editable = "true";
	$title = "$PB::Config::TEAM_NAME -- Puzzlebitch Central$PB::Config::PB_DEV_VERSION_POSTPAREN";
}else{
	$editable = "false";
	$title = "$PB::Config::TEAM_NAME -- Hunt Status$PB::Config::PB_DEV_VERSION_POSTPAREN";
}

my $html = <<"EOF";
Content-type: text/html

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>$title</title>
    <style type="text/css">
        \@import "$PB::Config::PB_CSS_REL/pb.css";
        \@import "$PB::Config::DOJO_ROOT/dijit/themes/tundra/tundra.css";
        \@import "$PB::Config::DOJO_ROOT/dojox/grid/resources/Grid.css";
        \@import "$PB::Config::DOJO_ROOT/dojox/grid/resources/tundraGrid.css";
    </style>
    <script type="text/javascript" src="$PB::Config::METEOR_JS_URI"></script>
    <script type="text/javascript" src="$PB::Config::DOJO_ROOT/dojo/dojo.js" 
            data-dojo-config="async: true, parseOnLoad: true, isDebug: $debugp"></script>
    <script type="text/javascript">

	var my_pbmrc;
	var my_pb;
    require({
		waitSeconds: 5,
	    },
		["../js/pb-meteor-rest-client.js", "../js/pb.js"],
	    function(pbmrc,pb) {
		pbmrc.pb_set_config("$PB::Config::METEOR_HTTP_HOST", "$PB::Config::METEOR_VERSION_CHANNEL", "$PB::Config::PBREST_ROOT");
		
		my_pbmrc = pbmrc;
		my_pb = pb;
		pb.my_init($editable);
	    });

	function create_round_cb(data, ioArgs) {
	    //    alert("round creation completed");
	    //alert("round creation callback: "+dojo.toJson(data));
	    //TODO handle errors
	    //createnewrounddialogStandby.hide();
	    //dijit.byId('createnewrounddialog').hide();
	}
	
	function create_wait(msg) {
	    //TODO: implement (and have create_round_cb tear it down)
	    //alert(msg);
	    //createnewrounddialogStandby.show();
	    //dijit.byId('createnewrounddialog').show();
	}
	

    </script>
</head>
<body class="tundra">
<h1>$title</h1>

<!--<div id="gridMessages">grid messages</div>-->

<div id="puzzlecontainer"></div>
<input id="hidesolved" type="checkbox" onclick="my_pb.updateHideSolved();" $hidesolved>Hide solved puzzles</input>
<br>
<input id="roundsvsall" type="checkbox" onclick="my_pb.updateRoundsVsAll();" $showrounds>Display puzzles by round</input>

<div id="statuscontainer"></div>

EOF

if ($editable eq "true"){
$html .= <<"EOF"	
<!-- new round -->
<button dojoType="dijit.form.Button" onclick="dijit.byId('createnewrounddialog').show()">Create New Round</button>
<div dojoType="dijit.Dialog" id="createnewrounddialog" title="Enter new round information" execute="msg=my_pbmrc.pb_create_round(arguments[0].newroundid); if(msg.indexOf('ERROR') > -1) {error_cb(msg)} else { create_wait(msg); }">
    <table>
      <tr>
	<td><label for="newroundid">Round Name:</label></td>
        <td><input dojoType="dijit.form.TextBox" type="text" name="newroundid" id="newroundid"></td>
      </tr>
      <tr>
        <td colspan="2" align="center">
          <button dojoType="dijit.form.Button" type="submit">Create</button>
        </td>
      </tr>
    </table>
</div> 
<!-- <div jsId="createnewrounddialogStandby" dojoType="dojox.widget.Standby" target="createnewrounddialog"></div> -->

<!--administrative stuff below here-->
<table border=1>

<!-- ghetto interface for solver removal -->
<tr><td><table>
<tr><td>Unassign a solver from his current puzzle:
<table><tr><th>Solver</td></tr>
<tr><form action="solver_resting.pl" method="post">
<td><INPUT TYPE="text" NAME="solver" VALUE=""/>
<INPUT TYPE="hidden" NAME="returnurl" VALUE="$PB::Config::PB_BIN_REL/pb.pl"</td>
<td><INPUT TYPE="submit" NAME="Unassign!" VALUE="Unassign!"/></td>
</form>
</tr></table>
</td></tr></table></td>


<!-- new puzzle -->
<table>
<tr><td>
To add a new puzzle:
<ul>
<li>There should be a "Post new puzzle" bookmarklet in the bookmarks toolbar of this browser. (if there isn't, install it by going to the <a href="bm.pl">bookmarklet install page</a> and dragging the link there to the bookmark bar)</li>
<li>Whenever a new puzzle becomes available, go to the <b>PUZZLE PAGE</b> so that you are looking at the actual puzzle and click the "post new puzzle" button in the bookmark bar. (note: if a single puzzle is composed of multiple HTML pages, it would be appropriate to use the first page you come to)</li>
<li>Select the round that the puzzle belongs to (you must have already added the round before clicking on the bookmark</li>
<li>Only if necessary, edit the Puzzle ID so that it uniquely represents the name of the puzzle (by default this will be automatically taken from the title of the HTML page and in most cases should not be changed from that unless there is a good reason to do so). This ID will be used in the name of the page for the puzzle.</li>
<li>Problems should be addressed to Jeff Barrett or Josh Randall</li>
</ul>
</td></tr></table>


</body>
</html>

EOF
}

print $html;
