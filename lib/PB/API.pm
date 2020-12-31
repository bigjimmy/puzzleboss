package PB::API;
use strict;
use warnings;
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use lib dirname(abs_path($0));


use Scalar::Util qw(tainted looks_like_number);

use PB::Config;
use PB::Meteor;
use PB::BigJimmy;

use Net::LDAP;

use DBI;
use SQL::Yapp;

use LWP::Simple;
use JSON qw( decode_json );
use URI::Escape;

my $dbh = DBI->connect('DBI:mysql:database='.$PB::Config::PB_DATA_DB_NAME.$PB::Config::PB_DEV_VERSION.';host='.$PB::Config::PB_DATA_DB_HOST.';port='.$PB::Config::PB_DATA_DB_PORT, $PB::Config::PB_DATA_DB_USER, $PB::Config::PB_DATA_DB_PASS) || die "Could not connect to database: $DBI::errstr";

my $EXCLUSIVE_LOCK = 2;
my $UNLOCK = 8;

sub debug_log {
    my $message = shift;
    my $level = shift;

    print STDERR $message if($PB::Config::DEBUG > $level);
}

########
#PUZZLES
########

sub get_puzzle_list {
    my $roundfilter = shift || '.*';
    return _get_puzzle_list_db($roundfilter);
}

sub _get_puzzle_list_db {
    my $roundfilter = shift;
    debug_log("_get_puzzle_list_db()", 6);

    my $res;
    if(defined($roundfilter)) {
	my $sql = "SELECT `puzzle`.`name` AS 'puzzle_name' FROM `puzzle` JOIN `round` ON `round`.`id`=`puzzle`.`round_id` WHERE `round`.`name` REGEXP ?";
	$res = $dbh->selectcol_arrayref($sql, undef, $roundfilter);
    } else {
	my $sql = "SELECT `name` FROM `puzzle`";
	$res = $dbh->selectcol_arrayref($sql);
    }
    return @{$res};
}

sub _add_puzzle_db {
    my $id = shift;
    my $round = shift;
    my $puzzle_uri = shift;
    my $drive_uri = shift;
    my $slack_channel_id = shift;
    my $slack_channel_name = lc shift;
    my $slack_channel_link = shift;

    debug_log("add_puzzle_db params: id=$id round=$round puzzle_uri=$puzzle_uri slack_channel_name=$slack_channel_name \n", 4);

    # convert drive_uri to null (undef) if not set
    if($drive_uri eq '') {
	$drive_uri = undef;
    }

    my $sql = "INSERT INTO `puzzle` (`name`, `round_id`, `puzzle_uri`, `drive_uri`, `slack_channel_id`, `slack_channel_name`, `slack_channel_link`, `status`) VALUES (?, (SELECT id FROM `round` WHERE `round`.`name`=?), ?, ?, ?, ?, ?, 'New');";
    my $c = $dbh->do($sql, undef, $id, $round, $puzzle_uri, $drive_uri, $slack_channel_id, $slack_channel_name, $slack_channel_link);
    
    if(defined($c)) {
	debug_log("_add_puzzle_db: dbh->do returned $c\n",2);
	_send_data_version();
	debug_log("_add_puzzle_db: dbh->do returned success: ".$dbh->errstr." for query $sql with parameters id=$id, round=$round, puzzle_uri=$puzzle_uri drive_uri=$drive_uri slack_channel_name=$slack_channel_name slack_channel_link=$slack_channel_link\n",4);
	return(1);
    } else {
	debug_log("_add_puzzle_db: dbh->do returned error: ".$dbh->errstr." for query $sql with parameters id=$id, round=$round, puzzle_uri=$puzzle_uri drive_uri=$drive_uri slack_channel_name=$slack_channel_name, slack_channel_link=$slack_channel_link\n",0);
	#make the error reporting a bit more descriptive downstream
	if ($dbh->errstr =~ /Duplicate/){
	    return (-2);
	}else{
	    return(-1);
	}
    }
}

sub add_puzzle {
    my $id = shift;
    my $round = shift;
    my $puzzle_uri = shift;

    debug_log("add_puzzle: unsanitized id=$id\n");

    #clean up id
    $id =~ s/[[:space:]][-][-][[:space:]].+$//g;
    $id =~ s/\W//g;
#   $id =~ s/\-//g;
    $id =~ s/\_//g;
    $id =~ s/\ //g;

    debug_log("add_puzzle: id=$id round=$round puzzle_uri=$puzzle_uri\n", 2);

    my $round_drive_id = get_round($round)->{"drive_id"};
    my $channel_name = lc $id;
    my $channel_id = -1;
    my $channel_link = "";

    # create channel so we have the id to insert
    #my $channel = slack_create_channel_for_puzzle($id);
    my $channel = discord_create_channel_for_puzzle($channel_name, $round, $puzzle_uri, "https://drive.google.com/drive/u/2/folders/$round_drive_id");

    if (defined($channel->{channel_id})) {
        $channel_id = $channel->{channel_id};
    }
    else {
        debug_log("add_puzzle:  puzzle never got chat channel id! ABORTING ADD");
	return(-200);
    }
    $channel_id =~ s/\n//g;
    $channel_id =~ s/\W//g;


    if ($channel_id < 0) {
        debug_log("add_puzzle: puzzle never got a channel_id");
	return(-200);
    }
    
    $channel_link = $channel->{channel_link};

    # Initially populate the drive uri with a script that will look it up and do a redirect
    my $drive_uri = "$PB::Config::PB_BIN_URI/doc.pl?pid=$id";
    
    my $retvalue = _add_puzzle_db($id, $round, $puzzle_uri, $drive_uri, $channel_id, $channel_name, $channel_link);

    if ($retvalue <= 0) {
	    debug_log("add_puzzle: couldn't add to db!\n",0);
	    return(-100+$retvalue);
    }


    # set channel topic
    #slack_set_channel_topic($channel_id, $id, $round, $puzzle_uri, "https://drive.google.com/drive/u/2/folders/$round_drive_id");

    #Announce puzzle in general slack
    #slack_say_something ("slackannouncebot",$PB::Config::ANNOUNCE_CHANNEL,"NEW PUZZLE *$id* ADDED! \n Puzzle URL: $puzzle_uri \n Round: $round \n Google Doc: https://$PB::Config::PB_DOMAIN_NAME/puzzleboss/bin/doc.pl?pid=$id \n Slack Channel: <#$channel_id>");

    discord_announce_new($id);

    #Announce puzzle in giphy slack with giphy
    #commenting out because this is dumb
    #slack_say_something ("slackannouncebot","giphy","NEW PUZZLE *$id* ADDED! \n Puzzle URL: $puzzle_uri \n Round: $round \n Google Docs Folder: $round_uri \n Giphy: \n");
    #slack_say_something ("slackannouncebot","giphy",$id,"--giphy");

    return 0; # success
}

sub puzzle_solved {
    my $idin = shift;
    debug_log("puzzle_solved():  $idin has been solved\n", 5);

    #We want to send solvers working on this puzzle to the pool.
    my $puzzref = get_puzzle($idin);
    my @cursolvers = split(",", $puzzref->{"cursolvers"});
    foreach my $solver (@cursolvers){
	assign_solver_puzzle("", $solver);
    }
    my $theanswer = $puzzref->{"answer"};

    my $message = "PUZZLE $idin HAS BEEN SOLVED! (ANSWER: $theanswer) \n Way to go team! :doge:";
    #slack_say_something ("slackannouncebot", $PB::Config::SLACK_CHANNEL, $message);
    #slack_say_something ("slackannouncebot", $puzzref->{"slack_channel_name"}, $message);
    discord_announce_solve($idin);
}

sub delete_puzzle {
    my $idin = shift;
    chomp $idin;

    debug_log("delete_puzzle: $idin\n",6);

    my $puzzref = get_puzzle($idin);

    # remove solvers from puzzle before you delete it
    my @cursolvers = split(",", $puzzref->{"cursolvers"});
    foreach my $solver (@cursolvers){
        assign_solver_puzzle("", $solver);
    }
 
    return _delete_puzzle_db($idin);
}

sub _delete_puzzle_db {
    my $idin = shift;
    debug_log("_delete_puzzle_db: $idin\n", 6);

    my $sql = 'DELETE FROM `puzzle` WHERE id='.$idin;
    my $sth;
    $sth = $dbh->prepare($sql);
    $sth->execute() or die $dbh->errstr;
    return(1);
}


sub get_puzzle {
    my $idin = shift;
    chomp $idin;
    
    debug_log("get_puzzle: $idin\n",6);

    return _get_puzzle_db($idin);
}

sub _get_puzzle_db {
    my $idin = shift;

    my $res;
    my $sql = 'SELECT * FROM `puzzle_view`';
    my $sth;
    my $always_return_array = 0;
    #This fixes problem with type error when there is exactly one puzzle in the DB.
    if ($idin eq '*') {
	$always_return_array = 1;
	$sth  = $dbh->prepare($sql);
	$sth->execute() or die $dbh->errstr;;
    } else {
        $sql .= ' WHERE (`name` REGEXP ?)';
	$sth = $dbh->prepare($sql);
	$sth->execute('^'.$idin.'$');
    }
    my @rows;
    while ( my $res = $sth->fetchrow_hashref() ) {
	foreach my $key (keys %{$res}) {
	    if(!defined($res->{$key})) {
		$res->{$key} = "";
	    }
	}
	push @rows, $res;
    }
    if($always_return_array > 0 || @rows > 1) {
	return \@rows;
    } else {
	return \%{$rows[0]};
    }
}

sub update_puzzle_part {
	my $id = shift;
	my $part = shift;
	my $val = shift;

	#We need special handling for a puzzle part update which imples the puzzle is solved
	#This might be either a status change to "Solved", or an answer change to non-null
	#Our accepted logic, system wide, is that only both of these things represent a solved puzzle
        my $answer = undef;
	
	# Don't actually enter status change to "solved" without answer
	# pb page edited will still say "solved" but at least it won't propagate
 	# and everyone else will know the puzz still isn't really solved
	if ($part eq "status" && $val eq "Solved"){
	    #is there an answer?
	    my $puzzref = get_puzzle($id);
	    my $answer = $puzzref->{"answer"};
	    debug_log("update_puzzle_part for status solved: PART=$part VAL=$val ANS=$answer\n",5);
	    if ($answer ne undef){
		debug_log("ok answer is defined.  we can mark as solved.",5);
		puzzle_solved($id);
	    } else {
	    debug_log("whoa whoa whoa. can't mark as solved. no answer defined.",1);
	    return 255;
            }
	}

	my $rval = _update_puzzle_part_db($id, $part, $val);

	if ($part eq "status" && $val eq "Needs eyes"){
	    my $eyespuzzref = get_puzzle($id);
	    my $eyespuzzle_name = $eyespuzzref->{"name"};
	    discord_announce_attention($eyespuzzle_name);
	#slack_say_something ("slackannouncebot",$PB::Config::SLACK_CHANNEL, "Puzzle *$eyespuzzle_name* NEEDS EYES! \n Puzzle URL: $eyespuzzle_uri \n Google Doc: $eyespuzzle_googdoc \n Slack Channel: <#$eyespuzzle_slackchannelid>");
	#slack_say_something ("slackannouncebot",$eyespuzzref->{"slack_channel_name"}, "Puzzle *$eyespuzzle_name* NEEDS EYES");
    }

    if ($part eq "status" && $val eq "Critical"){
        my $critpuzzref = get_puzzle($id);
        my $critpuzzle_name = $critpuzzref->{"name"};
        discord_announce_attention($critpuzzle_name);
	#slack_say_something ("slackannouncebot",$PB::Config::SLACK_CHANNEL, "Puzzle *$critpuzzle_name* IS CRITICAL! \n Puzzle URL: $critpuzzle_uri \n Google Doc: $critpuzzle_googdoc \n Slack Channel: <#$critpuzzle_slackchannelid>");
	#slack_say_something ("slackannouncebot",$critpuzzref->{"slack_channel_name"}, "Puzzle *$critpuzzle_name* is CRITICAL");
    }

    if ($part eq "status" && $val eq "Unnecessary"){
        my $unnecessarypuzzref = get_puzzle($id);
        my $unnecessarypuzzle_name = $unnecessarypuzzref->{"name"};
        discord_announce_attention($unnecessarypuzzle_name);
	#slack_say_something ("slackannouncebot",$unnecessarypuzzref->{"slack_channel_name"}, "Puzzle *$unnecessarypuzzle_name* is UNNECESSARY");
    }


	# If an answer is submitted, automatically mark the puzzle as solved
	if ($part eq "answer" && $val ne ""){
            #am I solved status?
            my $puzzref = get_puzzle($id);
            if ($puzzref->{"status"} ne "Solved"){
                puzzle_solved($id);
		my $rval = _update_puzzle_part_db($id, "status", "Solved");
            }
        }

	if(looks_like_number($rval) && $rval < 0) {
		return $rval;
	}
}

sub _update_puzzle_part_db {
    my $id = shift;
    my $part = shift;
    my $val = shift;
    my $retries = shift || 10;

    # TODO: fix SQL injection attack vector through $part
    my $sql = 'UPDATE `puzzle_view` SET `'.$part.'` = ? WHERE `name` LIKE ? LIMIT 1';
    debug_log("_update_puzzle_part_db: SQL: $sql\n",2);

    my $c = $dbh->do($sql, undef, $val, $id);
    
    if(defined($c)) {
	debug_log("_update_puzzle_part_db: id=$id part=$part val=$val dbh->do returned $c\n",2);
	_send_data_version();
	return(1);
    } else {
	debug_log("_update_puzzle_part_db: id=$id part=$part val=$val dbh->do returned error: ".$dbh->errstr."\n",0);
	if($dbh->errstr =~ m/deadlock/i) {
	    sleep 5;
	    return _update_puzzle_part_db($id, $part, $val, $retries);
	}
	return(-1);
    }
}

sub get_puzzle_activity {
    my $pid = shift;
    
    my $sql = 'SELECT solver.name as solver, activity.time as time, activity.source as activity FROM solver, activity WHERE solver.id = activity.solver_id AND activity.puzzle_id = '.$pid.' ORDER BY activity.time DESC';

    my $sth  = $dbh->prepare($sql);
    $sth->execute() or die $dbh->errstr;
    my @rows;

    while (my $row = $sth->fetchrow_hashref) {
        push @rows, $row;
	debug_log("get_puzzle_activity: fetched line of activity for puzzid $pid\n",4);
    } 

    return \@rows; 
    
}

sub get_puzzle_info {
    my $pid = shift;

    my $sql = 'SELECT * FROM puzzle_view WHERE id = '.$pid;
    my $sth = $dbh->prepare($sql);
    $sth->execute() or die $dbh->errstr;

    debug_log("get_puzzle_info:  fetching line of puzzle_view table for puzzid $pid\n",4);
 
    my $row = $sth->fetchrow_hashref;

    return $row;
}
#######
#ROUNDS
#######
    

sub get_round_list {
    debug_log("get_round_list\n",6);
    return _get_round_list_db();
}

sub _get_round_list_db {
    debug_log("_get_round_list_db\n",6);
    my $sql = "SELECT name FROM `round`";
    debug_log("SQL: $sql\n",6);
    my $res = $dbh->selectcol_arrayref($sql);
    debug_log("_get_round_list SQL result: $res\n", 6);
    return @{$res};
}

sub _add_round_db {
    my $new_round = shift;

    my $sql = "INSERT INTO `round` (`name`) VALUES (?);";
    my $c = $dbh->do($sql, undef, $new_round);
    
    if(defined($c)) {
	debug_log("_add_round_db: dbh->do returned $c\n",2);
	_send_data_version();
	return(1);
    } else {
	debug_log("_add_round_db: dbh->do returned error: ".$dbh->errstr."\n",0);
	return(-1);
    }
}

sub add_round {
	my $new_round = shift;
	#clean up input
	$new_round =~ s/^.+\:\ //g;
	$new_round =~ s/\W//g;
	$new_round =~ s/\-/Dash/g;
	$new_round =~ s/\_/Underscore/g;
	$new_round =~ s/\ //g;

	# untaint new_round
	if($new_round =~ /^([[:alnum:]]+)$/ ) {
		$new_round = $1;
	} else {
		debug_log("add_round: new_round did not pass security checks ($new_round)\n",1);
		return(-4);
	}

	my $gfuri = "";
    
	my $rval = _add_round_db($new_round);
	if($rval < 0) {
		return $rval;
	}

	#slack_say_something ("puzzannouncebot",$PB::Config::SLACK_CHANNEL,"New Round Added! $new_round");
	discord_announce ("New Round Added! $new_round");

	return 0; # success
}

sub get_round {
    my $idin = shift;

    my $res;
    my $sql = 'SELECT * FROM `round`';
    my $sth;
    my $always_return_array = 0;
    #This fixes problem with type error when there is exactly one round in the DB.
    if ($idin eq '*') {
	$always_return_array = 1;
	$sth  = $dbh->prepare($sql);
	$sth->execute() or die $dbh->errstr;;
    } else {
        $sql .= ' WHERE (`name` REGEXP ?)';
	$sth = $dbh->prepare($sql);
	$sth->execute('^'.$idin.'$');
    }
    my @rows;
    while ( my $res = $sth->fetchrow_hashref() ) {
	foreach my $key (keys %{$res}) {
	    if(!defined($res->{$key})) {
		$res->{$key} = "";
	    }
	}
	push @rows, $res;
    }
    if($always_return_array > 0 || @rows > 1) {
	return \@rows;
    } else {
	return \%{$rows[0]};
    }
}

sub update_round_part {
    my $id = shift;
    my $part = shift;
    my $val = shift;

    # TODO: fix SQL injection attack vector through $part
    my $sql = 'UPDATE `round` SET `'.$part.'` = ? WHERE `name` LIKE ? LIMIT 1';
    my $c = $dbh->do($sql, undef, $val, $id);
    
    if(defined($c)) {
	debug_log("_update_round_part_db: id=$id part=$part val=$val dbh->do returned $c\n",2);
	_send_data_version();
	return(1);
    } else {
	debug_log("_update_round_part_db: id=$id part=$part val=$val dbh->do returned error: ".$dbh->errstr."\n",0);
	return(-1);
    }
}


##############
#SOLVERS/USERS
##############

sub get_solver_list {
	return _get_solver_list_db();
}

sub _get_solver_list_db {
	my $sql = 'SELECT `name` FROM `solver_view`';
	my $res = $dbh->selectcol_arrayref($sql);
	return $res;
}

sub get_solver {
	my $idin = shift;
	chomp $idin;
    
	debug_log("get_solver: $idin\n",6);

	return _get_solver_db($idin);
}

sub _get_solver_db {
	my $idin = shift;

	my $res;
	my $sql = 'SELECT * FROM `solver_view`';
	my $sth;
	#This fixes problem with type error when there is exactly one solver in the DB.
	my $always_return_array = 0;
	if ($idin eq '*') {
		$always_return_array = 1;
		$sth  = $dbh->prepare($sql);
		$sth->execute() or die $dbh->errstr;;
	} else {
		$sql .= ' WHERE (`name` REGEXP ?)';
		$sth = $dbh->prepare($sql);
		$sth->execute('^'.$idin.'$');
	}
	my @rows;
	while ( my $res = $sth->fetchrow_hashref() ) {
		foreach my $key (keys %{$res}) {
			if(!defined($res->{$key})) {
				$res->{$key} = "";
			}
		}
		push @rows, $res;
	}
	if(@rows > 1 || $always_return_array) {
		return \@rows;
	} else {
		return \%{$rows[0]};
	}
}

sub add_solver {
	my $idin = $_[0];
        my $fullname = $_[1];
    
	debug_log("add_solver: username:$idin fullname:$fullname\n",6);

	return _add_solver_db($idin, $fullname);
}


sub _add_solver_db {
	my $id = $_[0];
	my $fullname = $_[1];

	my $sql = "INSERT INTO `solver` (`name`, `fullname`) VALUES ('$id', '$fullname');";
	debug_log("_add_solver_db: sql: $sql\n",3);
	my $c = $dbh->do($sql, undef, $id);
    
	if(defined($c)) {
		debug_log("_add_solver_db: dbh->do returned $c\n",2);
		_send_data_version();
		return(1);
	} else {
		debug_log("_add_solver_db: dbh->do returned error: ".$dbh->errstr."\n",0);
		return(-1);
	}
}

sub ldap_add_user {
	my $username = shift;
	my $firstname = shift;
	my $lastname = shift;
	my $email = shift;
	my $password = shift;
    
	my $ldap = Net::LDAP->new(  "$PB::Config::REGISTER_LDAP_HOST" );
	# bind to a directory with dn and password
	my $mesg = $ldap->bind( "cn=$PB::Config::REGISTER_LDAP_ADMIN_USER,$PB::Config::REGISTER_LDAP_DC",
	password => $PB::Config::REGISTER_LDAP_ADMIN_PASS
	);
    
	my $result = $ldap->add( "uid=$username,ou=people,$PB::Config::REGISTER_LDAP_DC",
	attr => [
	'objectclass' => [ 'inetOrgPerson' ],
	'uid' => $username,
	'sn'   => $lastname,
	'givenName' => $firstname,
	'cn'   => "$firstname $lastname",
	'displayName'   => "$firstname $lastname",
	'userPassword' => $password,
	'email' => $email,
	'mail' => $username.'@'.$PB::Config::GOOGLE_DOMAIN,
	'o' => $PB::Config::REGISTER_LDAP_O,
	]
			     
	);
    
	if($result->code() != 0 && !($result->error_desc() =~ m/Already exists/)) {
		return -1;
	}

        my $resultgrp => $ldap->modify( "cn=HuntTeam,ou=groups,$PB::Config::REGISTER_LDAP_DC", 
	add => {
        	memberUid	=> $username
		}
	);

	return 0;
}

sub ldap_change_password {
	my $username = shift;
	my $password = shift;

	my $ldap = Net::LDAP->new(  "$PB::Config::REGISTER_LDAP_HOST" );
        # bind to a directory with dn and password
        my $mesg = $ldap->bind( "cn=$PB::Config::REGISTER_LDAP_ADMIN_USER,$PB::Config::REGISTER_LDAP_DC",
        password => $PB::Config::REGISTER_LDAP_ADMIN_PASS
        );

	my $result = $ldap->modify( "uid=$username,ou=people,$PB::Config::REGISTER_LDAP_DC", 
        replace => {
            userPassword    =>  $password,
        }
        );
        
        if($result->code() != 0) {
		return -1;
	}
	return 0;
}

sub google_add_user {
	my $username = shift;
	my $firstname = shift;
	my $lastname = shift;
	my $password = shift;
	my $domain = $PB::Config::GOOGLE_DOMAIN;

	chdir $PB::Config::PB_GOOGLE_PATH;

	print STDERR "Running AddDomainUser.py from $PB::Config::PB_GOOGLE_PATH\n";
	# Prepare command
	my $cmd = "./AddDomainUser.py --firstname '$firstname' --lastname '$lastname' --username '$username' --password '$password' --domain '$domain' |";
	my $cmdout="";

	# Execute command
	if(open ADDPUZZSSPS, $cmd) {
		# success, check output
		while(<ADDPUZZSSPS>) {
			$cmdout .= $_;
		}
	} else {
		# failure
		debug_log("_google_add_user: could not open command\n",1);
		return -100;
	}
	close ADDPUZZSSPS;
	if(($?>>8) != 0) {
		debug_log("_google_add_user: exit value ".($?>>8)."\n",1);
		return ($?>>8);
	}

	return(0);
}

sub google_change_password {
	my $username = shift;
	my $password = shift;
	my $domain = $PB::Config::GOOGLE_DOMAIN;

        chdir $PB::Config::PB_GOOGLE_PATH;

	print STDERR "Running ChangeDomainUserPassword.py from $PB::Config::PB_GOOGLE_PATH\n";
	# Prepare command
        my $cmd = "./ChangeDomainUserPassword.py --username '$username' --password '$password' --domain '$domain' |";
        my $cmdout="";

        # Execute command
        if(open ADDPUZZSSPS, $cmd) {
                # success, check output
                while(<ADDPUZZSSPS>) {
                        $cmdout .= $_;
                }
        } else {
                # failure
                debug_log("google_change_password: could not open command\n",1);
                return -100;
        }
        close ADDPUZZSSPS;
        if(($?>>8) != 0) {
                debug_log("google_change_password: exit value ".($?>>8)."\n",1);
                return ($?>>8);
        }

        return(0);
}

sub ldap_get_user_list {
    debug_log("ldap_get_user_list() using LDAP\n",2);
    
    my $ldap = Net::LDAP->new ("ldap.wind-up-birds.org") or die "$@";
    my $mesg = $ldap->search ( base => "ou=people,dc=wind-up-birds,dc=org",
			       scope   => "sub",
			       filter  => "sn=*",
			       attrs   =>  ['uid','displayName']
	);
    my @entries = $mesg->entries;
    my %userhash = ();
    foreach my $e (@entries){
	my $uid = ($e->get_value('uid'));
	my $fullname = ($e->get_value('displayName'));
	$userhash{$uid} = $fullname;
    }
    
    return %userhash;
}

sub update_solver_part {
    my $id = shift;
    my $part = shift;
    my $val = shift;

    my $remote_user = $ENV{'REMOTE_USER'};
	
    if ($part eq "puzz"){
	#If this action is being taken by the solver herself, log it in the activity table
	if (defined $remote_user && $id eq $remote_user){
	    #apache is the source for interactions via the web UI
	    _write_solver_activity($val,$id,"apache","interact");
	}
	return assign_solver_puzzle($val,$id);
    }else{
	#I don't know what you are.
	return -7;
    }
}

sub assign_solver_puzzle {
    my $puzzname = shift;
    my $solver = shift;
    
    my $rval = _assign_solver_puzzle_db($puzzname, $solver);
    if($rval < 0) {
	    return $rval;
    }

    #If this puzzle is NEW, we should change it to being worked
    my $puzzle = get_puzzle($puzzname);
    if ($puzzle->{"status"} eq "New"){
	update_puzzle_part($puzzname,"status","Being worked");
    }

    return $rval;
}

sub _write_solver_activity {
    my $puzzname = shift;
    my $solver = shift;
    my $source = shift;
    my $type = shift;

    my $sql = "INSERT INTO `activity` (`puzzle_id`, `solver_id`, `source`, `type`) VALUES ((SELECT `id` FROM `puzzle` WHERE `name` LIKE ?), (SELECT `id` FROM `solver` WHERE `name` LIKE ?),?,?)";
    my $c = $dbh->do($sql,undef,$puzzname,$solver,$source,$type);
    if(defined($c)) {
	debug_log("_write_solver_activity: dbh->do returned $c\n",2);
	return(1);
    } else {
	debug_log("_write_solver_activity: dbh->do returned error: ".$dbh->errstr."\n",0);
	return(-1);
    }

}

sub _assign_solver_puzzle_db {    
	my $puzzname = shift;
	my $solver = shift;
    
	my $sql = "INSERT INTO `puzzle_solver` (`puzzle_id`, `solver_id`) VALUES ((SELECT `id` FROM `puzzle` WHERE `name` LIKE ?), (SELECT `id` FROM `solver` WHERE `name` LIKE ?))";
	my $c = $dbh->do($sql,undef,$puzzname,$solver);
	if(defined($c)) {
		debug_log("_assign_solver_puzzle_db: dbh->do returned $c\n",2);
		_send_data_version();
		return(1);
	} else {
		debug_log("_assign_solver_puzzle_db: dbh->do returned error: ".$dbh->errstr."\n",0);
		return(-1);
	}
}

sub assign_solver_location {
    my $puzzname = shift;
    my $solver = shift;
    my $rval = _assign_solver_location_db($puzzname, $solver);
    if($rval < 0) {
        return $rval;
    }
}

sub _assign_solver_location_db {    
    my $puzzname = shift;
    my $solver = shift;
    
    my $sql = "INSERT INTO `puzzle_solver` (`puzzle_id`, `solver_id`) VALUES ((SELECT `id` FROM `puzzle` WHERE `name` LIKE ?), (SELECT `id` FROM `solver` WHERE `name` LIKE ?))";
    my $c = $dbh->do($sql);
    if(defined($c)) {
	debug_log("_get_client_index_db: dbh->do returned $c\n",2);
	_send_data_version();
	return(1);
    } else {
	debug_log("_get_client_index_db: dbh->do returned error: ".$dbh->errstr."\n",0);
	return(-1);
    }
}


####
#LOG
####
sub get_log_index {
    return _get_log_index_db();
}

sub _get_log_index_db {
    debug_log("_get_log_index_db\n",6);
    my $sql = "SELECT MAX(version) FROM `log`";
    my $res = $dbh->selectcol_arrayref($sql);
    my $version = -1;
    if(defined($res)) {
	if($res->[0] eq 'null') {
	    $version = "";
	} else {
	    $version = $res->[0];
	}
    }
    return $version;
}

# get_log_diff only return first part (before :)
sub get_log_diff { 
    my $log_pos = shift;
    debug_log("get_log_diff: $log_pos\n",6);
    my $curr_pos = shift || get_log_index();
    if(!defined($curr_pos)) {
	$curr_pos = 0;
    }
    chomp($curr_pos);
    if($curr_pos < $log_pos) {
	return "from log position ($log_pos) cannot be greater than current (to) log position ($curr_pos)";
    }
    return _get_log_diff_db($log_pos, $curr_pos);
}

sub _get_log_diff_db { 
    my $cur_pos = shift;
	my $from_pos = $cur_pos+1;
    my $to_pos = shift;
    debug_log("_get_log_diff_db: $from_pos - $to_pos\n",6);
    
    my $sql = "SELECT DISTINCT CONCAT_WS('/', IFNULL(module,''), IFNULL(name,''), IFNULL(part,'')) FROM `log` WHERE log.version>= ? AND log.version <= ?";
    my $res = $dbh->selectcol_arrayref($sql, undef, $from_pos, $to_pos);
    my @changes = @{$res};
    debug_log("_get_log_diff_db: have changes: ".join(',',@changes)."\n", 2);
    
    my %reentry_vehicle =(
	from => $from_pos,
	to => $to_pos,
	diff => \@changes);
    
    return (\%reentry_vehicle);
}

sub get_full_log_diff { 
    my $log_pos = shift;
  debug_log("get_full_log_diff: $log_pos\n",6);
  my $curr_pos = shift || get_log_index();
  chomp($curr_pos);
  return _get_full_log_diff_db($log_pos, $curr_pos);
}

sub _get_full_log_diff_db { 
    my $cur_pos = shift;
	my $from_pos = $cur_pos+1;
    my $to_pos = shift;
    debug_log("_get_log_diff_db: $from_pos - $to_pos\n",6);
    
    my $sql = "SELECT CONCAT_WS('/', IFNULL(module,''), IFNULL(name,''), IFNULL(part,'')) AS entry, user, time FROM `log` WHERE log.version>= ? AND log.version <= ? ORDER BY id";
    my $res = $dbh->selectall_arrayref($sql, undef, $from_pos, $to_pos);
    my @entries;
    my @messages;
    foreach my $row (@{$res}) {
	my $entry = $row->{entry};
	push @entries, $entry;
	my $time = $row->{time};
	my $user = $row->{user} || "unknown user";
	push @messages, "$user at $time updated $entry";
    }
    
    my %reentry_vehicle =(
	from => $from_pos,
	to => $to_pos,
	entries => \@entries,
	messages => \@messages,);
    
    return (\%reentry_vehicle);
}

####################
#CONVENIENCE METHODS
####################

sub _get_client_index_db {
    debug_log("get_client_index\n",6);
    my $index = 0;

    my $sql = "INSERT INTO `clientindex` (`id`) VALUES (NULL)";
    my $c = $dbh->do($sql);
    if(!defined($c)) {
	debug_log("_get_client_index_db: dbh->do returned error: ".$dbh->errstr."\n",0);
	return(-1);
    }
    $index = $dbh->last_insert_id(undef, undef, undef, undef);
    
    return($index);
}

sub get_client_index { 
  return _get_client_index_db();
}

###############
# Data Version
###############
sub _send_data_version {
    my $dataversion = _get_log_index_db();
    my $ret = 1;

    # Send to bigjimmy bot
    if(PB::BigJimmy::send_version($dataversion) <= 0) {
     	debug_log("PB::API::_send_data_version() error sending version $dataversion to bigjimmy bot\n",0);
    $ret = -1;
    }

    # Send to meteor
    debug_log("PB::API::_send_data_version() sending version ".$dataversion." to meteor\n",4);
    if(PB::Meteor::message($PB::Config::METEOR_VERSION_CHANNEL, $dataversion) <= 0) {
	debug_log("PB::API::_send_data_version() error sending version $dataversion over meteor\n",0);
	$ret = -1;
    }
    return $ret;
}

sub slack_say_something {
    my $username = shift;
    my $channel = shift;
    my $message = shift;
    my $apiurl = $PB::Config::SLACK_API_URL;

    chdir $PB::Config::PB_GOOGLE_PATH;

    print STDERR "Running slackcat.py from $PB::Config::PB_GOOGLE_PATH with url $apiurl\n";

    # Prepare command
    my $cmd = "./slackcat.py -u $apiurl -c $channel -n $username -t '$message' |";
    my $cmdout="";

    # Execute command
    if(open SLACKSAY, $cmd) {
        # success, check output
        while(<SLACKSAY>) {
            $cmdout .= $_;
        }
    } else {
        # failure
        debug_log("_slack_say_something: could not open command\n",1);
        return -100;
    }
    close SLACKSAY;
    if(($?>>8) != 0) {
        debug_log("_slack_say_something: exit value ".($?>>8)."\n",1);
        return ($?>>8);
    }

    return(0);
}

sub discord_announce {
    my $message = shift;
    my $apiurl = $PB::Config::DISCORD_HOOK_URL;

    chdir $PB::Config::PB_GOOGLE_PATH;

    print STDERR "Running discordcat.py from $PB::Config::PB_GOOGLE_PATH with url $apiurl\n";

    # Prepare command
    my $cmd = "./discordcat.py -u $apiurl -t '$message' |";
    debug_log("discord_announce: running command: $cmd",2);
    my $cmdout="";

    # Execute command
    if(open SLACKSAY, $cmd) {
        # success, check output
        while(<SLACKSAY>) {
            $cmdout .= $_;
        }
    } else {
        # failure
        debug_log("_discord_announce: could not open command\n",1);
        return -100;
    }
    close SLACKSAY;
    if(($?>>8) != 0) {
        debug_log("_discord_announce: exit value ".($?>>8)."\n",1);
        return ($?>>8);
    }

    return(0);
}

sub discord_announce_new {
    my $id = shift;
    return discord_announce_impl('_new', $id);
}

sub discord_announce_solve {
    my $id = shift;
    return discord_announce_impl('_solve', $id);
}

sub discord_announce_attention {
    my $id = shift;
    return discord_announce_impl('_attention', $id);
}

# Tell Puzzcord API an announcement command
sub discord_announce_impl {
    my $command = shift;
    my $id = shift;

    chdir $PB::Config::DISCORD_API_PATH;

    my $cmd = "./api $command $id |";
    debug_log("_discord_announce$command: running: $cmd\n",2);

    my $cmdout = "";

    if(open DISCORDSAY, $cmd) {
        # success
	while(<DISCORDSAY>) {
            $cmdout .= $_;
	}
    } else {
	#failure
	debug_log("_discord_announce$command: could not open command\n", 1);
	return -100
    }
    close DISCORDSAY;
    if(($?>>8) != 0) {
        debug_log("_discord_announce$command: exit value ".($?>>8)."\n",1);
        return ($?>>8);
    }

    return(0);
}

sub slack_create_channel_for_puzzle {
    my $puzzle_name = lc shift;

    debug_log("slack_create_channel_for_puzzle: puzzle_name=$puzzle_name\n", 2);

    # invoke API call to create channel
    my $channels_create_url = "https://slack.com/api/conversations.create?token=$PB::Config::SLACK_API_USER_TOKEN&name=p-$puzzle_name&pretty=1";
    my $response;

    $response = get($channels_create_url);
    debug_log("slack channel creation url: $channels_create_url\n", 2);
    debug_log("slack response: $response\n", 2);
    
    unless (defined($response)) {
        debug_log("get request to $channels_create_url failed\n");
    }

    # extract channel id
    my $json = decode_json($response);
    unless ($json->{ok}) {
        debug_log("Slack API: channels.create failed with error: $json->{error}\n");
    }

    my $channel_id;
    $channel_id = $json->{channel}->{id};
    my $channel_name;
    $channel_name = $json->{channel}->{name};

    return {
        channel_id => $channel_id,
        channel_name => $channel_name
    };
}

sub discord_create_channel_for_puzzle {
    my $puzzle_name = shift;
    my $round_name = shift;
    my $puzzle_uri = shift;
    my $google_docs_folder = shift;

    debug_log("discord_create_channel_for_puzzle: puzzle_name=$puzzle_name, round_name=$round_name, puzzle_uri=$puzzle_uri, google_docs_folder=$google_docs_folder\n",2);

    chdir $PB::Config::DISCORD_API_PATH;

    print STDERR "Running puzzcord api create\n";

    my $topic = "\nPuzzle: $puzzle_name \nRound: $round_name \nPuzzle URL: $puzzle_uri \nGoogle Docs Folder: $google_docs_folder";

    my $cmd = "./api create_json $puzzle_name '$topic' |";
    debug_log("discord_create_channel_for_puzzle: running: $cmd");
    my $cmdout = "";

    if(open DISCORDSAY, $cmd) {
        # success
        while(<DISCORDSAY>) {
            $cmdout .= $_;
        }
    } else {
        #failure
        debug_log("_discord_create_channel_for_puzzle: could not open command\n", 1);
        return -100
    }
    close DISCORDSAY;
    if(($?>>8) != 0) {
        debug_log("_discord_create_channel_for_puzzle: exit value ".($?>>8)."\n",1);
        return (-1*($?>>8));
    }
    debug_log("api create returned our puzzle id: $cmdout", 3);

    my $json = decode_json($cmdout);
    unless ($json->{id}) {
	    debug_log("DISCORD API FAILED TO CREATE CHANNEL!")
    }

    my $channel_id = $json->{id};
    my $channel_link = $json->{url};
    return {
	    channel_id => $channel_id,
	    channel_link => $channel_link,
    };
}

sub slack_set_channel_topic {
    my $channel_id = shift;
    my $puzzle_name = shift;
    my $round_name = shift;
    my $puzzle_uri = shift;
    my $google_docs_folder = shift;

    my $topic_url_param = uri_escape ("Puzzle: $puzzle_name / Round: $round_name\nPuzzle URL: $puzzle_uri\nGoogle Docs Folder: $google_docs_folder");
    my $channels_set_topic_url = "https://slack.com/api/conversations.setTopic?token=$PB::Config::SLACK_API_USER_TOKEN&channel=$channel_id&topic=$topic_url_param&pretty=1";
    debug_log("setting channel topic for channel id: $channel_id via url param: $topic_url_param", 2);
    get($channels_set_topic_url);
    
    return $channel_id;
}

1;

