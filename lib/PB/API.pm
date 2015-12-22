package PB::API;
use strict;
use warnings;

use Scalar::Util qw(tainted looks_like_number);

use PB::Config;
use PB::Meteor;
use PB::TWiki;
use PB::BigJimmy;

use Net::LDAP;

use DBI;
use SQL::Yapp;

my $dbh = DBI->connect('DBI:mysql:database=puzzlebitch'.$PB::Config::PB_DEV_VERSION.';host='.$PB::Config::PB_DATA_DB_HOST.';port='.$PB::Config::PB_DATA_DB_PORT, $PB::Config::PB_DATA_DB_USER, $PB::Config::PB_DATA_DB_PASS) || die "Could not connect to database: $DBI::errstr";

my $remoteuser = $ENV{'REMOTE_USER'} || "unknown user";

my $EXCLUSIVE_LOCK = 2;
my $UNLOCK = 8;

my %PUZZDATA = (
    round => 1,
    puzzle_uri => 2,
    drive_uri => 3,
    comments => 4,
    status => 5,
    xyzloc => 6,
    answer => 7,
    past_solvers => 8,
    wrong_answers => 9,
    );

sub debug_log {
    my $message = shift;
    my $level = shift;
    print STDERR $message if($PB::Config::DEBUG>$level);
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

    debug_log("add_puzzle_db params: id=$id round=$round puzzle_uri=$puzzle_uri drive_uri=$drive_uri \n", 4);

    # convert drive_uri to null (undef) if not set
    if($drive_uri eq '') {
	$drive_uri = undef;
    }

    my $sql = "INSERT INTO `puzzle` (`name`, `round_id`, `puzzle_uri`, `drive_uri`, `status`) VALUES (?, (SELECT id FROM `round` WHERE `round`.`name`=?), ?, ?, 'New');";
    my $c = $dbh->do($sql, undef, $id, $round, $puzzle_uri, $drive_uri);
    
    if(defined($c)) {
	debug_log("_add_puzzle_db: dbh->do returned $c\n",2);
	_send_data_version();
	debug_log("_add_puzzle_db: dbh->do returned success: ".$dbh->errstr." for query $sql with parameters id=$id, round=$round, puzzle_uri=$puzzle_uri drive_uri=$drive_uri\n",4);
	return(1);
    } else {
	debug_log("_add_puzzle_db: dbh->do returned error: ".$dbh->errstr." for query $sql with parameters id=$id, round=$round, puzzle_uri=$puzzle_uri drive_uri=$drive_uri\n",0);
	return(-1);
    }
}

sub add_puzzle {
    my $id = shift;
    my $round = shift;
    my $puzzle_uri = shift;
    my $templatetopic = shift;

    debug_log("add_puzzle: unsanitized id=$id\n");

    #clean up id
    $id =~ s/[[:space:]][-][-][[:space:]].+$//g;
    $id =~ s/\W//g;
#   $id =~ s/\-//g;
    $id =~ s/\_//g;
    $id =~ s/\ //g;

    debug_log("add_puzzle: id=$id round=$round puzzle_uri=$puzzle_uri templatetopic=$templatetopic\n", 2);

    # Figure out what names of TWiki topics should be
    my $puzzletopic = $id."Puzzle";
    my $roundtopic = $round."Round";
    if(!defined($templatetopic) || $templatetopic eq "") {
	$templatetopic = "GenericPuzzleTopicTemplate";
    }
    
    my $drive_uri = undef;

    if(_add_puzzle_db($id, $round, $puzzle_uri, $drive_uri) <= 0) {
	    debug_log("add_puzzle: couldn't add to db!\n",0);
	    return(-101);
    }

    my $round_uri = get_round($round)->{"drive_uri"};
    slack_say_something ("slackannouncebot","general","NEW PUZZLE $id ADDED! \n Puzzle URL: $puzzle_uri \n Round: $round \n Google Docs Folder: $round_uri");

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

    slack_say_something ("slackannouncebot", "general","PUZZLE $idin HAS BEEN SOLVED! \n Way to go team! :doge:");
    
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
    
	my $roundtopic = $new_round."Round";

	my $rval = _add_round_db($new_round);
	if($rval < 0) {
		return $rval;
	}

        slack_say_something ("puzzannouncebot","general","New Round Added! $new_round");

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


##########
#TEMPLATES
##########

sub get_template_list {
	debug_log("get_template_list\n",6);
	my @templates;
	chdir $PB::Config::TWIKI_DATA_PATH.'/'.$PB::Config::TWIKI_WEB;
	open FILE, "ls *PuzzleTopicTemplate.txt|";
	#    open FILE, $PB::Config::TEMPLATES_FILE;
	#    flock FILE, $EXCLUSIVE_LOCK;
	while (<FILE>){
		chomp;
		s/\.txt$//;
		push @templates, $_;
	}
	#    flock FILE, $UNLOCK;
	close FILE;
        
	return @templates;
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
    
    my $ldap = Net::LDAP->new ("localhost") or die "$@";
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
	
	if ($part eq "puzz"){
		return assign_solver_puzzle($val,$id);
	}else{
		#I don't know who you are.
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
}

sub _assign_solver_puzzle_db {    
	my $puzzname = shift;
	my $solver = shift;
    
	my $sql = "INSERT INTO `puzzle_solver` (`puzzle_id`, `solver_id`) VALUES ((SELECT `id` FROM `puzzle` WHERE `name` LIKE ?), (SELECT `id` FROM `solver` WHERE `name` LIKE ?))";
	my $c = $dbh->do($sql,undef,$puzzname,$solver);
	if(defined($c)) {
		debug_log("_get_client_index_db: dbh->do returned $c\n",2);
		_send_data_version();
		return(1);
	} else {
		debug_log("_get_client_index_db: dbh->do returned error: ".$dbh->errstr."\n",0);
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

    chdir $PB::Config::PB_GOOGLE_PATH;

    print STDERR "Running slackcat.py from $PB::Config::PB_GOOGLE_PATH\n";

    # Prepare command
    my $cmd = "./slackcat.py -c $channel -n $username -t '$message' |";
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


1;

