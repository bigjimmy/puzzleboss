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
    uri => 2,
    gssuri => 3,
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
    if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
	return _get_puzzle_list_files($roundfilter);
    } else {
	return _get_puzzle_list_db($roundfilter);
    }
}

sub _get_puzzle_list_files {
    my $roundfilter = shift || '.*';
    my @puzzles;
    debug_log("_get_puzzle_list_files() opening $PB::Config::PUZZLES_FILE (will filter with $roundfilter)\n",5);
    if(open FILE, $PB::Config::PUZZLES_FILE) {
	flock FILE, $EXCLUSIVE_LOCK;
	while (<FILE>){
	    chomp;
	    push @puzzles, $_;
	}
	flock FILE, $UNLOCK;
	close FILE;
    }
    if($roundfilter eq '.*') {
	return @puzzles;
    } else {
	my $roundfilterregex = qr/$roundfilter/;
	# process puzzles to limit them to only those matching roundfilter regex
	my @matchingpuzzles;
	foreach my $puzzid (@puzzles) {
	    if(PB::API::get_puzzle($puzzid)->{round} =~ m/$roundfilter/) {
		push @matchingpuzzles, $puzzid;
	    }
	}
	return @matchingpuzzles;
	return @puzzles; #TODO What the fuck is this doing here beneath the line above??
    }
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


sub _add_puzzle_to_puzzlelist_file {
    my $id = shift;

    if (-e "$PB::Config::PB_DATA_PATH/$id.dat"){
	#can't add this entry -- it already exists!
	debug_log("_add_puzzle_to_puzzlelist_file: puzzle already exists\n",0);
	return -1;
    }
    
    # Add to puzzle list file
    my @puzzles;
    push @puzzles, $PB::Config::PUZZLES_FILE;
    if(open FILE, $PB::Config::PUZZLES_FILE) {
	flock FILE, $EXCLUSIVE_LOCK;
	while (<FILE>){
	    chomp;
	    if ($_ ne $id){
		push @puzzles, "$_\n";
	    }
	}
	flock FILE, $UNLOCK;
	close FILE;
    }
    push @puzzles, "$id\n";
    
    if ((my $rval = _write_fields_files(@puzzles)) < 0 ){
	debug_log("_add_puzzle_to_puzzlelist_file: Can't write fields puzzle list ($rval)!!\n",0);
	return -1;
    } else {
	debug_log("_add_puzzle_to_puzzlelist_file: Puzzle list written\n",2);
    }
}


sub _add_puzzle_files {
    my $id = shift;
    my $round = shift;
    my $uri = shift;
    my $gssuri = shift;
 
    # Add to puzzle list
    _add_puzzle_to_puzzlelist_file($id);
    
    # Add puzzle data file
    my @output;
    push @output, "$PB::Config::PB_DATA_PATH/$id.dat";
    push @output, "$id\n";
    push @output, "$round\n";
    push @output, "$uri\n";
    push @output, "$gssuri\n";
    push @output, "\n"; #comments
    push @output, "New\n"; #status
    push @output, "\n"; #working location
    push @output, "\n"; #answer;
    push @output, "\n"; #past solvers
    push @output, "\n"; #wrong answers

    return(_write_fields_files(@output));
}

sub _add_puzzle_db {
    my $id = shift;
    my $round = shift;
    my $uri = shift;
    my $gssuri = shift;

    # convert gssuri to null (undef) if not set
    if($gssuri eq '') {
	$gssuri = undef;
    }
    my $sql = "INSERT INTO `puzzle` (`name`, `round_id`, `puzzle_uri`, `drive_uri`, `status`) VALUES (?, (SELECT id FROM `round` WHERE `round`.`name`=?), ?, ?, 'New');";
    my $c = $dbh->do($sql, undef, $id, $round, $uri, $gssuri);
    
    if(defined($c)) {
	debug_log("_add_puzzle_db: dbh->do returned $c\n",2);
	_send_data_version();
	return(1);
    } else {
	debug_log("_add_puzzle_db: dbh->do returned error: ".$dbh->errstr."\n",0);
	return(-1);
    }
}

sub _add_puzzle_google {
    my $id = shift;
    my $round = shift;
    my $uri = shift;
    my $templatetopic = shift;
    my $puzzletopic = shift;

    # create google spreadsheet for this puzzle
    debug_log("add_puzzle: creating google spreadsheet\n",0);
    my $google = _google_create_spreadsheet($id, $round, $PB::Config::TWIKI_WEB, $PB::Config::TWIKI_URI."/twiki/bin/view/".$PB::Config::TWIKI_WEB."/".$puzzletopic, $uri);
    my $gssuri = $google->{'spreadsheet'};
    debug_log("add_puzzle: have google spreadsheet $gssuri\n",0);
    my $folderuri = $google->{'subfolder'};
    debug_log("add_puzzle: have google folder $folderuri\n",0);
    
    # create google document for this puzzle
    #debug_log("add_puzzle: creating google document\n",0);
    #$google = _google_create_document($id, $round, $PB::Config::TWIKI_WEB);
    #my $gduri = $google->{'document'};
    #debug_log("add_puzzle: have google document $gduri\n",0);
    #my $gdfolderuri = $google->{'subfolder'};
    #debug_log("add_puzzle: have google folder $gdfolderuri\n",0);

    # TODO update URI in data store
    return $gssuri;
}

sub _add_puzzle_twiki {
    my $id = shift;
    my $round = shift;
    my $uri = shift;
    my $templatetopic = shift;
    my $puzzletopic = shift;
    my $roundtopic = shift;
    my $gssuri = shift;
    my $gduri = shift;
    my $folderuri = shift;

    # Add puzzle to TWiki
    debug_log("add_puzzle: creating twiki topic $puzzletopic $roundtopic $templatetopic $id\n",0);
    if(    PB::TWiki::twiki_save($puzzletopic, {
	onlynewtopic => 1,
	parenttopic => $roundtopic,
	templatetopic => $templatetopic,
	prname => $id,
	puzurl => $uri,
	gssurl => $gssuri,
	gdurl => $gduri,
	googlepuzzleurl => $folderuri,
				 }) >= 0) {
	if(_twiki_update_round($roundtopic, $puzzletopic, $id) >= 0) {
	    # update log
	    _write_log_files("puzzles/$id:$remoteuser added puzzle $id to round $round");
	    return(0);
	} else {
	    _write_log_files("puzzles/$id:$remoteuser added puzzle $id to round $round (ERROR, failed to update $roundtopic)");
	    return(-3);
	}
    } else {
	_write_log_files("puzzles/$id:$remoteuser added puzzle $id to round $round (ERROR, failed to save topic $puzzletopic)");
	return(-4);
    }
    return(-2);
    
}

sub add_puzzle {
    my $id = shift;
    my $round = shift;
    my $uri = shift;
    my $templatetopic = shift;

    #clean up id
    $id =~ s/^.+\:\ //g;
    $id =~ s/\W//g;
    $id =~ s/\-//g;
    $id =~ s/\_//g;
    $id =~ s/\ //g;

    debug_log("add_puzzle()\n",2);

    # Figure out what names of TWiki topics should be
    my $puzzletopic = $id."Puzzle";
    my $roundtopic = $round."Round";
    if(!defined($templatetopic) || $templatetopic eq "") {
	$templatetopic = "GenericPuzzleTopicTemplate";
    }
    
    #_add_puzzle_twiki($id, $round, $uri, $templatetopic, $puzzletopic, $roundtopic);
    #my $gssuri = _add_puzzle_google($id, $round, $uri, $templatetopic, $puzzletopic);
    my $gssuri = "";


    # Add to backend data store files
    if($PB::Config::PB_DATA_WRITE_FILES > 0) {
	if(_add_puzzle_files($id, $round, $uri, $gssuri) <= 0) {
	    debug_log("add_puzzle: Can't write fields for puzzle data!!\n",0);
	    return(-1);
	}
    }    
    
    # Add to database
    if($PB::Config::PB_DATA_WRITE_DB > 0) {
	if(_add_puzzle_db($id, $round, $uri, $gssuri) <= 0) {
	    debug_log("add_puzzle: couldn't add to db!\n",0);
	    return(-101);
	}
    }    
    
    return 0; # success
}


sub _google_create_spreadsheet {
    my $puzzle = shift;
    my $round = shift;
    my $hunt = shift;
    my $twikiurl = shift;
    my $puzzurl = shift;
    my $domain = $PB::Config::GOOGLE_DOMAIN;
    my $google_spreadsheet_uri = "";

    # Backup environment
    my %ENVBACKUP;

    # Kill environment
    foreach my $key (keys %ENV) {
	$ENVBACKUP{$key} = delete $ENV{$key};
    }

    $ENV{JAVA_HOME} = "/usr/java/jdk1.6.0_18";
    $ENV{CLASSPATH} = ".:$PB::Config::PB_GOOGLE_PATH:/canadia/google/gdata/java/lib/gdata-core-1.0.jar:/canadia/google/gdata/java/lib/gdata-docs-3.0.jar:/canadia/google/gdata/java/lib/gdata-spreadsheet-3.0.jar:/canadia/google/gdata/java/sample/util/lib/sample-util.jar:/canadia/google/commons-cli-1.2/commons-cli-1.2.jar:/canadia/google/javamail-1.4.3/mail.jar:/canadia/google/jaf-1.1.1/activation.jar:/canadia/google/gdata/java/deps/google-collect-1.0-rc1.jar:/canadia/google/gdata/java/deps/jsr305.jar";

    chdir $PB::Config::PB_GOOGLE_PATH;

    print STDERR "Running java from $PB::Config::PB_GOOGLE_PATH\n";
    # Prepare command
    my $cmd = "./AddPuzzleSpreadsheet.sh --puzzle '$puzzle' --round '$round' --hunt '$hunt' --twikiurl '$twikiurl' --puzzleurl '$puzzurl' --domain '$domain' --adminpass $PB::Config::TWIKI_USER_PASS|";
    #my $cmdout="";


    my %output;

    # Execute command
    if(open ADDPUZZSSPS, $cmd) {
	# success, check output
	while(my $line = <ADDPUZZSSPS>) {
	    chomp $line;
	    my ($key,$value) = split /\=/,$line,2;
	    debug_log("_google_create_spreadsheet: have key $key value $value\n", 3);
	    $output{$key} = $value;
	}
    } else {
	# failure
	debug_log("_google_create_spreadsheet: could not open command\n",1);
	return -100;
    }
    close ADDPUZZSSPS;
    if(($?>>8) != 0) {
	debug_log("_google_create_spreadsheet: exit value ".($?>>8)."\n",1);
	return ($?>>8);
    }

    # Restore environement
    foreach(keys %ENVBACKUP) {
	$ENV{$_} = delete $ENVBACKUP{$_};
    }

    
    return(\%output);
}

sub _google_create_document {
    my $puzzle = shift;
    my $round = shift;
    my $hunt = shift;
    my $domain = $PB::Config::GOOGLE_DOMAIN;
    my $templatefile = $PB::Config::GOOGLE_PUZZLE_DOCUMENT_TEMPLATE;
    my $google_document_uri = "";

    # Backup environment
    my %ENVBACKUP;

    # Kill environment
    foreach my $key (keys %ENV) {
	$ENVBACKUP{$key} = delete $ENV{$key};
    }

    $ENV{JAVA_HOME} = "/usr/java/jdk1.6.0_18";
    $ENV{CLASSPATH} = ".:$PB::Config::PB_GOOGLE_PATH:/canadia/google/gdata/java/lib/gdata-core-1.0.jar:/canadia/google/gdata/java/lib/gdata-docs-3.0.jar:/canadia/google/gdata/java/lib/gdata-spreadsheet-3.0.jar:/canadia/google/gdata/java/sample/util/lib/sample-util.jar:/canadia/google/commons-cli-1.2/commons-cli-1.2.jar:/canadia/google/javamail-1.4.3/mail.jar:/canadia/google/jaf-1.1.1/activation.jar:/canadia/google/gdata/java/deps/google-collect-1.0-rc1.jar:/canadia/google/gdata/java/deps/jsr305.jar";

    chdir $PB::Config::PB_GOOGLE_PATH;

    print STDERR "Running java from $PB::Config::PB_GOOGLE_PATH\n";
    # Prepare command
    my $cmd = "./AddPuzzleDocument.sh --puzzle '$puzzle' --round '$round' --hunt '$hunt'  --domain '$domain' --templatefile '$templatefile' --adminpass $PB::Config::TWIKI_USER_PASS|";
    #my $cmdout="";


    my %output;

    # Execute command
    if(open ADDPUZZSSPS, $cmd) {
	# success, check output
	while(my $line = <ADDPUZZSSPS>) {
	    chomp $line;
	    my ($key,$value) = split /\=/,$line,2;
	    debug_log("_google_create_document: have key $key value $value\n", 3);
	    $output{$key} = $value;
	}
    } else {
	# failure
	debug_log("_google_create_document: could not open command\n",1);
	return -100;
    }
    close ADDPUZZSSPS;
    if(($?>>8) != 0) {
	debug_log("_google_create_document: exit value ".($?>>8)."\n",1);
	return ($?>>8);
    }

    # Restore environement
    foreach(keys %ENVBACKUP) {
	$ENV{$_} = delete $ENVBACKUP{$_};
    }

    
    return(\%output);
}

sub puzzle_solved {
    my $idin = shift;
    debug_log("puzzle_solved():  $idin has been solved\n", 5);

    #We want to send off notifications to users still tooling on this puzzle
    #Also perhaps to watercooler?
    #TODO: UNIMPLEMENTED!
    
    #We want to send solvers working on this puzzle to the pool.
    my $puzzref = get_puzzle($idin);
    my @cursolvers = split(",", $puzzref->{"cursolvers"});
    foreach my $solver (@cursolvers){
	assign_solver_puzzle("", $solver);
    }
    
}


sub get_puzzle {
    my $idin = shift;
    chomp $idin;
    
    debug_log("get_puzzle: $idin\n",6);

    if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
        return _get_puzzle_files($idin);
    } else {
        return _get_puzzle_db($idin);
    }
}

sub _get_puzzle_files {
    my $idin = shift;
    
    if ($idin eq '*'){
	return _get_puzzles_files(get_puzzle_list());
    } else {
	return _get_puzzles_files($idin)->[0];
    }
}

sub _get_puzzles_files {
    my @puzzlist = @_;
    
    debug_log("_get_puzzles_files: ".join(',',@puzzlist)."\n",6);
    my $id="";
    my $linkid="";
    my $round="";
    my $uri="";
    my $gssuri="";
    my $comments="";
    my $status="";
    my $xyzloc="";
    my $answer="";
    my $cursolvers="";
    my $solvers="";
    my $wrong_answers="";
    
    my @outpuzzles;
    foreach my $idin (@puzzlist){
	my $puzzfile = $PB::Config::PB_DATA_PATH."/".$idin.".dat";
	debug_log("get_puzzle: opening puzzfile $puzzfile\n",6);
	if (-e $puzzfile){
	    if(open FILE, "<$puzzfile") {
		flock FILE, $EXCLUSIVE_LOCK;
		
		$id = <FILE>;
		chomp $id;
		if($idin eq $id) {
		    $round = <FILE>;
		    chomp $round;
		    #$uri = <FILE>;
		    #people asked for PB links to be to wiki
		    $uri = "$PB::Config::TWIKI_URI/twiki/bin/view/$PB::Config::TWIKI_WEB/$id"."Puzzle";
		    <FILE>;
		    chomp $uri;
		    $gssuri = <FILE>;
		    chomp $gssuri;
		    $comments = <FILE>;
		    chomp $comments;
		    $status = <FILE>;
		    chomp $status;
		    $xyzloc = <FILE>;
		    chomp $xyzloc;
		    $answer = <FILE>;
		    chomp $answer;
		    $solvers = <FILE>;
		    chomp $solvers;
		    $wrong_answers = <FILE>;
		    chomp $wrong_answers;
		} else {
		    debug_log("get_puzzle: DATA ERROR\n",1);
			return -1;
		}	    
		flock FILE, $UNLOCK;
		close FILE;
	    } else {
		debug_log("get_puzzle: error opening puzzle file $puzzfile\n",2);
		return -1;
	    }
	    
	    $cursolvers = _get_puzz_solvers_files($id);
	    if(!$id) {
		$id="";
	    }
	    if(!$round) {
		$round="";
	    }
	    if(!$uri) {
		$uri="";
	    }
	    if(!$gssuri) {
		$gssuri="";
	    }
	    if(!$comments) {
		$comments="";
	    }
	    if(!$status) {
		$status="";
	    }
	    if(!$xyzloc) {
		$xyzloc="";
	    }
	    if(!$answer) {
		$answer="";
	    }
	    if(!$cursolvers) {
		$cursolvers="";
	    }
	    if(!$solvers) {
		$solvers="";
	    }
	    if(!$wrong_answers) {
		$wrong_answers="";
	    }
	    my %puzzle = (
		id => $id,
		name => $id,
		linkid => "<a href=\"$uri\" target=\"$id\">$id</a>",
		round => $round,
		uri => $uri,
		gssuri => $gssuri,
		comments => $comments,
		status => $status,
		xyzloc => $xyzloc,
		answer => $answer,
		cursolvers => $cursolvers,
		solvers => $solvers,
		wrong_answers => $wrong_answers,
		);
	    push @outpuzzles, \%puzzle;
	} else {
	    debug_log("get_puzzle: could not open data file $puzzfile\n",1);
	    return(-1);
	}
    }
    return \@outpuzzles;
    return(-2);
}

sub _get_puzz_solvers_files {
    my $id = shift;
    debug_log("get_puzz_solvers: $id\n",6);
    my $solvers;
    if(open MAPFILE, $PB::Config::SOLV_MAP_FILE) {
	flock MAPFILE, $EXCLUSIVE_LOCK;
	while (<MAPFILE>){
	    my @fields = split;
	    if ($fields[0] eq $id){
		$solvers .= "$fields[1],";
	    }
	}
	flock MAPFILE, $UNLOCK;
	close MAPFILE;
    }
    return $solvers;
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
	
	if ($part eq "status" && $val eq "Solved"){
	    #is there an answer?
	    my $puzzref = get_puzzle($id);
	    if ($puzzref->{"answer"} ne ""){
		puzzle_solved($id);
	    }
	}elsif ($part eq "answer" && $val ne ""){
	    #am I solved status?
	    my $puzzref = get_puzzle($id);
	    if ($puzzref->{"status"} eq "Solved"){
		puzzle_solved($id);
	    }
	}


	if($PB::Config::PB_DATA_WRITE_FILES > 0) {
		my $rval = _update_puzzle_part_files($id, $part, $val);
		if(looks_like_number($rval) && $rval < 0) {
			return $rval;
		}
	}
    
	if($PB::Config::PB_DATA_WRITE_DB > 0) {
		my $rval = _update_puzzle_part_db($id, $part, $val);
		if(looks_like_number($rval) && $rval < 0) {
			return $rval;
		}
	}
}

sub _update_puzzle_part_files {
    my $id = shift;
    my $part = shift;
    my $val = shift;

    if(exists($PUZZDATA{$part})) {
	my $rval = _update_puzzle_record_files($id,$val,$PUZZDATA{$part});
	if( looks_like_number($rval) && $rval < 0) {
	    return($rval);
	} else {
	    _write_log_files("puzzles/$id/$part:$remoteuser updated $id, $part = $val");
	    return($PUZZDATA{$part});
	}
    } else {
	return(-10);
    }
}

sub _update_puzzle_part_db {
    my $id = shift;
    my $part = shift;
    my $val = shift;

    # TODO: fix SQL injection attack vector through $part
    my $sql = 'UPDATE `puzzle_view` SET `'.$part.'` = ? WHERE `name` LIKE ? LIMIT 1';
    my $c = $dbh->do($sql, undef, $val, $id);
    
    if(defined($c)) {
	debug_log("_update_puzzle_part_db: id=$id part=$part val=$val dbh->do returned $c\n",2);
	_send_data_version();
	return(1);
    } else {
	debug_log("_update_puzzle_part_db: id=$id part=$part val=$val dbh->do returned error: ".$dbh->errstr."\n",0);
	return(-1);
    }
}


sub _update_puzzle_record_files {
    my $id = shift;
    my $val = shift;
    my $field = shift;

    if (!(-e "$PB::Config::PB_DATA_PATH/$id.dat")){
	#i don't know about this record.
	return -1;
    }
    
    if(open FILE, "$PB::Config::PB_DATA_PATH/$id.dat") {
	flock FILE, $EXCLUSIVE_LOCK;
	my $count = 0;
	my @output;
	push @output, "$PB::Config::PB_DATA_PATH/$id.dat";
	while (<FILE>){
	    if ($field != $count){
		push @output, $_;
	    }else {
		push @output, "$val\n";
	    }
	    $count++;
	}
	flock FILE, $UNLOCK;
	close FILE;

	if(_write_fields_files(@output) >0) {
	    return($id);
	} else {
	    return(-1);
	}
    } else {
	debug_log("_update_puzzle_record_files: could not open puzzle file $PB::Config::PB_DATA_PATH/$id.dat\n",2);
	return(-3);
    }
    return(-2);
}


#######
#ROUNDS
#######
    
sub _twiki_update_roundlist {
    my $roundtopic = shift;

    debug_log("_twiki_update_roundlist()\n",1);

    debug_log("roundtopic is tainted: [$roundtopic]\n",1) if(tainted($roundtopic));

    # Change dir to twiki
    chdir $PB::Config::TWIKI_BIN_PATH;

    # Backup and kill environment
    my %ENVBACKUP;
    foreach my $var (keys %ENV) {
	$ENVBACKUP{$var} = delete $ENV{$var};
    }

    # Prepare command to get roundlist topic
    my $cmd = "./view -user $PB::Config::TWIKI_USER -raw text -topic $PB::Config::TWIKI_WEB.$PB::Config::ROUNDLIST_TOPIC |";
    my $cmdout="";

    # Execute command
    if(open VIEWPS, $cmd) {
	# success, check output
	while(<VIEWPS>) {
	    $cmdout .= $_;
	}
    } else {
	# failure
	debug_log("_twiki_update_roundlist: could not open command\n",1);
	return -1;
    }
    close VIEWPS;
    if(($?>>8) != 0) {
	debug_log("_twiki_update_roundlist: exit value $? (attempting to view $PB::Config::TWIKI_WEB.$PB::Config::ROUNDLIST_TOPIC)\n",1);
	return -2;
    }

    # Restore environement
    foreach(keys %ENVBACKUP) {
	$ENV{$_} = delete $ENVBACKUP{$_};
    }

    # round item
    my $roundtext = "   \* [[$roundtopic]]\n";
    debug_log("_twiki_update_roundlist: adding $roundtext\n",5);
    
    # add puzzle item into cmdout
    my $topictext = $cmdout;
    if( $topictext =~ s/\<\!\-\-\ END_ROUND_LIST/$roundtext\<\!\-\- END_ROUND_LIST/s ) {
	# added the round, good to continue
	debug_log("_twiki_update_roundlist: added $roundtext to roundlist in topic text.\n", 9);
    } else {
	# could not find "<!-- END ROUND LIST" in topictext
	debug_log("_twiki_update_roundlist: could not find <!-- END ROUND LIST in topictext!\n",1);
    }

    debug_log("_twiki_update_round: topictext=[$topictext]\n",9);
    return(PB::TWiki::twiki_save($PB::Config::ROUNDLIST_TOPIC,
				 {
				     topicparent => "WebHome",
				     text => $topictext,
				 }
	   )
	);
}

sub _twiki_update_round {
    my $roundtopic = shift;
    my $puzzletopic = shift;
    my $puzname = shift;

    debug_log("_twiki_update_round()\n",1);

    # Change dir to twiki
    chdir $PB::Config::TWIKI_BIN_PATH;

    # Backup and kill environment
    my %ENVBACKUP;
    foreach my $var (keys %ENV) {
	$ENVBACKUP{$var} = delete $ENV{$var};
    }

    # Prepare command to get round
    my $cmd = "./view -user $PB::Config::TWIKI_USER -raw text -topic $PB::Config::TWIKI_WEB.$roundtopic|";
    my $cmdout="";

    # Execute command
    if(open VIEWPS, $cmd) {
	# success, check output
	while(<VIEWPS>) {
	    $cmdout .= $_;
	}
    } else {
	# failure
	debug_log("_twiki_update_round: could not open command\n",1);
	return -1;
    }
    close VIEWPS;
    if(($?>>8) != 0) {
	debug_log("_twiki_update_round: exit value $?\n",1);
	return -1;
    }

    # Restore environement
    foreach(keys %ENVBACKUP) {
	$ENV{$_} = delete $ENVBACKUP{$_};
    }


    # puzzle item
    my $roundtext = "   \* [[".$puzname."Puzzle][".$puzname."]]\n";
    debug_log("_twiki_update_round: adding $roundtext\n",1);
    
    # add puzzle item into cmdout
    $cmdout =~ s/\<\!\-\-\ END_PUZZLE_LIST/$roundtext\<\!\-\- END_PUZZLE_LIST/s;
    my $topictext = $cmdout;
    
    debug_log("Calling twiki_save for topic $PB::Config::TWIKI_WEB.$roundtopic",5);
    return(PB::TWiki::twiki_save($roundtopic,{
				     topicparent => "WebHome",
				     text => $topictext,
				 }));
}

sub _google_create_round {
    my $round = shift;
    my $hunt = shift;
    my $domain = $PB::Config::GOOGLE_DOMAIN;
    my $google_folder_uri = "";

    # Backup environment
    my %ENVBACKUP;

    # Kill environment
    foreach my $var (keys %ENV) {
	$ENVBACKUP{$var} = delete $ENV{$var};
    }

    $ENV{JAVA_HOME} = "/usr/java/jdk1.6.0_18";
    $ENV{CLASSPATH} = ".:$PB::Config::PB_GOOGLE_PATH:/canadia/google/gdata/java/lib/gdata-core-1.0.jar:/canadia/google/gdata/java/lib/gdata-docs-3.0.jar:/canadia/google/gdata/java/lib/gdata-spreadsheet-3.0.jar:/canadia/google/gdata/java/sample/util/lib/sample-util.jar:/canadia/google/commons-cli-1.2/commons-cli-1.2.jar:/canadia/google/javamail-1.4.3/mail.jar:/canadia/google/jaf-1.1.1/activation.jar:/canadia/google/gdata/java/deps/google-collect-1.0-rc1.jar:/canadia/google/gdata/java/deps/jsr305.jar";

    chdir $PB::Config::PB_GOOGLE_PATH;

    print STDERR "Running java from $PB::Config::PB_GOOGLE_PATH\n";
    # Prepare command
    my $cmd = "./AddRound.sh --round '$round' --hunt '$hunt' --domain '$domain' --adminpass $PB::Config::TWIKI_USER_PASS|";
    my $cmdout="";

    # Execute command
    if(open ADDPUZZSSPS, $cmd) {
	# success, check output
	while(<ADDPUZZSSPS>) {
	    $cmdout .= $_;
	}
    } else {
	# failure
	debug_log("_google_create_folder: could not open command\n",1);
	return -100;
    }
    close ADDPUZZSSPS;
    if(($?>>8) != 0) {
	debug_log("_google_create_folder: exit value ".($?>>8)."\n",1);
	return ($?>>8);
    }

    # Restore environement
    foreach(keys %ENVBACKUP) {
	$ENV{$_} = delete $ENVBACKUP{$_};
    }

    # Get uri from output
    $google_folder_uri = $cmdout;
    chomp $google_folder_uri;
    
    return($google_folder_uri);
}

sub get_round_list {
    debug_log("get_round_list\n",6);
    if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
        return _get_round_list_files();
    } else {
        return _get_round_list_db();
    }
}

sub _get_round_list_files {
    debug_log("_get_round_list_files\n",6);
    my @rounds;
    if(open FILE, $PB::Config::ROUNDS_FILE) {
	flock FILE, $EXCLUSIVE_LOCK;
	while (<FILE>){
	    chomp;
	    push @rounds, $_;
	}
	flock FILE, $UNLOCK;
	close FILE;
    }
    return @rounds;
}

sub _get_round_list_db {
    debug_log("_get_round_list_db\n",6);
    
    my $sql = "SELECT name FROM `round`";
    my $res = $dbh->selectcol_arrayref($sql);
    
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

sub _add_round_files {
    my $new_round = shift;

    my @rounds;
    push @rounds, $PB::Config::ROUNDS_FILE;
    if(open FILE, $PB::Config::ROUNDS_FILE) {
	flock FILE, $EXCLUSIVE_LOCK;
	while (<FILE>){
	    chomp;
	    if ($_ ne $new_round){
		push @rounds, "$_\n";
	    }
	}
	flock FILE, $UNLOCK;
	close FILE;
    }
    push @rounds, "$new_round\n";
    
    my $rval = _write_fields_files(@rounds);
    
    return $rval;
}

sub _add_round_twiki {
    my $new_round = shift;
    my $roundtopic = shift;
    my $gfuri = shift;

    # add to twiki
    my $templatetopic = "RoundTopicTemplate";
    return PB::TWiki::twiki_save($roundtopic, {
	onlynewtopic => 1,
	parenttopic => "WebHome",
	templatetopic => $templatetopic,
	prname => $new_round,
	roundgoogleurl => $gfuri,
				 })
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
	#    $gfuri = _google_create_round($new_round, $PB::Config::TWIKI_WEB);
	#    debug_log("add_round: have google folder $gfuri\n",0);
    
	my $roundtopic = $new_round."Round";
	#    my $rval=_add_round_twiki($new_round, $roundtopic, $gfuri);
	#    if($rval < 0) {
	#	debug_log("add_round: error adding round to twiki: $rval\n",0);
	#	return $rval;
	#    }

	if($PB::Config::PB_DATA_WRITE_FILES > 0) {
		my $rval = _add_round_files($new_round);
		if($rval < 0) {
			return $rval;
		}
	}
    
	if($PB::Config::PB_DATA_WRITE_DB > 0) {
		my $rval = _add_round_db($new_round);
		if($rval < 0) {
			return $rval;
		}
	}
    
	_write_log_files("rounds:$remoteuser added round $new_round");
	# add round to roundlist
	#my $rval = _twiki_update_roundlist($roundtopic);
	#return($rval);
	return 0; # success
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
	if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
		return ldap_get_user_list();
	} else {
		return _get_solver_list_db();
	}
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

	if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
		return _get_solver_files($idin);
	} else {
		return _get_solver_db($idin);
	}
}

sub _get_solver_files {
	my $idin = shift;
	# TODO: actually use files
	my @solvers;
	if ($idin eq '*') {
		foreach my $solver (@{ldap_get_user_list()}) {
			push @solvers, {id => $solver, name => $solver };
		}
	}
	return \@solvers;
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
	my $idin = shift;
	chomp $idin;
    
	debug_log("add_solver: $idin\n",6);

	if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
		return _add_solver_files($idin);
	} else {
		return _add_solver_db($idin);
	}
}

sub _add_solver_files {
	my $idin = shift;
	# NOT IMPLEMENTED
	return 1;
}

sub _add_solver_db {
	my $id = shift;

	my $sql = "INSERT INTO `solver` (`name`) VALUES (?);";
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
	return 0;
}

sub google_add_user {
	my $username = shift;
	my $firstname = shift;
	my $lastname = shift;
	my $password = shift;
	my $domain = $PB::Config::GOOGLE_DOMAIN;

	# Backup environment
	my %ENVBACKUP;

	# Kill environment
	foreach my $var (keys %ENV) {
		$ENVBACKUP{$var} = delete $ENV{$var};
	}

	$ENV{JAVA_HOME} = "/usr/java/jdk1.6.0_18";
	$ENV{CLASSPATH} = ".:$PB::Config::PB_GOOGLE_PATH:/canadia/google/gdata/java/lib/gdata-core-1.0.jar:/canadia/google/gdata/java/lib/gdata-docs-3.0.jar:/canadia/google/gdata/java/lib/gdata-spreadsheet-3.0.jar:/canadia/google/gdata/java/sample/util/lib/sample-util.jar:/canadia/google/commons-cli-1.2/commons-cli-1.2.jar:/canadia/google/javamail-1.4.3/mail.jar:/canadia/google/jaf-1.1.1/activation.jar:/canadia/google/gdata/java/deps/google-collect-1.0-rc1.jar:/canadia/google/gdata/java/deps/jsr305.jar";

	chdir $PB::Config::PB_GOOGLE_PATH;

	print STDERR "Running java from $PB::Config::PB_GOOGLE_PATH\n";
	# Prepare command
	my $cmd = "./AddDomainUser.sh --firstname '$firstname' --lastname '$lastname' --username '$username' --password '$password' --domain '$domain' --adminpass $PB::Config::TWIKI_USER_PASS|";
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

	# Restore environement
	foreach(keys %ENVBACKUP) {
		$ENV{$_} = delete $ENVBACKUP{$_};
	}

	return(0);
}


sub twiki_add_user {
	my $username = shift;
	my $firstname = shift;
	my $lastname = shift;
	my $email = shift;
	my $password = shift;
    
	debug_log("_twiki_add_user()\n",2);

	# Change dir to twiki
	chdir $PB::Config::TWIKI_BIN_PATH;

	# Backup environment
	my %ENVBACKUP;

	# Kill environment
	foreach my $var (keys %ENV) {
		$ENVBACKUP{$var} = delete $ENV{$var};
	}
    
	# Prepare command
	my $cmd = "./offlineregister $username $firstname $lastname $email $password |";
	my $cmdout="";

	# Execute command
	if(open SAVEPS, $cmd) {
		# success, check output
		while(<SAVEPS>) {
			$cmdout .= $_;
		}
	} else {
		# failure
		debug_log("_twiki_add_user: could not open command\n",1);
		return -1;
	}
	close SAVEPS;
	if(($?>>8) != 0) {
		debug_log("_twiki_add_user: exit value $?\n",1);
		return -1;
	}

	# Restore environement
	foreach(keys %ENVBACKUP) {
		$ENV{$_} = delete $ENVBACKUP{$_};
	}


	# Check for failure
	if($cmdout =~ m/oops/s) {
		debug_log("_twiki_add_user: OOPS!\n$cmdout\n",1);
		return -1;
	} else {
		# Success
		return(0);
	}
}

sub ldap_get_user_list {
    debug_log("ldap_get_user_list() using LDAP\n",2);
    
    my $ldap = Net::LDAP->new ("localhost") or die "$@";
    my $mesg = $ldap->search ( base => "ou=people,dc=wind-up-birds,dc=org",
			       scope   => "sub",
			       filter  => "sn=*",
			       attrs   =>  ['uid']
	);
    my @entries = $mesg->entries;
    my @rawdata;
    foreach my $e (@entries){
	push @rawdata, $e->get_value('uid');
    }
    
    my @sortdata = sort(@rawdata);
    
    my @outdata;
    foreach my $d (@sortdata){
	push @outdata, $d;
    }
    
    return \@outdata;
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
    if($PB::Config::PB_DATA_WRITE_FILES > 0) {
	my $rval = _assign_solver_puzzle_files($puzzname, $solver);
	if($rval < 0) {
	    return $rval;
	}
    }
    
    if($PB::Config::PB_DATA_WRITE_DB > 0) {
	my $rval = _assign_solver_puzzle_db($puzzname, $solver);
	if($rval < 0) {
	    return $rval;
	}
    }
}

sub _assign_solver_puzzle_files {    
    my $id = shift;
    my $new_solver = shift;

    my @modpuzz;
    push @modpuzz, $id;
    # make sure the new_solver is nice and whitespace-free
    $new_solver =~ s/\s//g;
    
    debug_log("_assign_solver_puzzle_files: $id $new_solver\n",2);
    if (!(-e "$PB::Config::PB_DATA_PATH/$id.dat")){
	#i don't know about this record.
	return -1;
    }

    # first remove this guy from whereever he currently is.
    push @modpuzz, update_remove_solver($id,$new_solver);

    my @records;
    push @records, $PB::Config::SOLV_MAP_FILE;
    if(open MAPFILE, $PB::Config::SOLV_MAP_FILE) {
       flock MAPFILE, $EXCLUSIVE_LOCK;
    
       while (<MAPFILE>){
	 push @records, $_;
       }
       flock MAPFILE, $UNLOCK;
       close MAPFILE;
    }
    push @records, "$id\t$new_solver\n";

    if (_write_fields_files(@records) < 0){
	return -1;
    }

    # Now remove him from the pool, if he was there
    #pool_remove_solver($new_solver);

    my $past_solvers_updated = 1;
    #now put this dude in the solvers line for this puzz.
       my @output;
       push @output, "$PB::Config::PB_DATA_PATH/$id.dat";
    if(open PUZZFILE, "$PB::Config::PB_DATA_PATH/$id.dat") {
       flock PUZZFILE, $EXCLUSIVE_LOCK;
       my $count = 0;
    while (<PUZZFILE>){
	if ($count == $PUZZDATA{past_solvers}){
	    my @fields = split;
	    my $solvers = "$new_solver\n";
	    foreach my $field (@fields){
		if ($field ne $new_solver){
		    $solvers = $field." $solvers";
		} else {
                    $past_solvers_updated = 0;
                }
	    }
	    push @output, $solvers;
	}else{
	    push @output, $_;
	}
	$count++;
    }
    flock PUZZFILE, $UNLOCK;
    close PUZZFILE;
    }
    if (_write_fields_files(@output) > 0 ){
	if($past_solvers_updated > 0) {
            _write_log_files("puzzles/$id/solvers:$remoteuser added solver $new_solver to $id");
        }
        _write_log_files("puzzles/$id/cursolvers:$remoteuser says $new_solver is working on $id");
	return @modpuzz;
    }else{
	return -1;
    }
    return(-2);
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
    if($PB::Config::PB_DATA_WRITE_FILES > 0) {
	#my $rval = _assign_solver_location_files($puzzname, $solver);
	#if($rval < 0) {
	#    return $rval;
	#}
	return 0;
    }
    
    if($PB::Config::PB_DATA_WRITE_DB > 0) {
	my $rval = _assign_solver_location_db($puzzname, $solver);
	if($rval < 0) {
	    return $rval;
	}
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
    if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
        return _get_log_index_files();
    } else {
        return _get_log_index_db();
    }
}

sub _get_log_index_files {
    debug_log("_get_log_index_files\n",6);
    # We need this when a pb central is first starting up, to find out where we started.
    my $curr_pos = 0;
    if(open LI, $PB::Config::LOG_INDEX) {
	flock LI, $EXCLUSIVE_LOCK;
	$curr_pos = <LI>;
	flock LI, $UNLOCK;
	close LI;
    }
    return($curr_pos);
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
    if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
        return _get_log_diff_files($log_pos, $curr_pos);
    } else {
        return _get_log_diff_db($log_pos, $curr_pos);
    }
}

sub _get_log_diff_files { 
    my $from_pos = shift;
    my $to_pos = shift;
    debug_log("_get_log_diff_files: $from_pos - $to_pos\n",6);
    my @changes;

    my %reentry_vehicle =(
	from => $from_pos,
	to => $to_pos,
	diff => \@changes);
    
    
    if ($from_pos == $to_pos) {
	return (\%reentry_vehicle);
    } else {
	if(open LOG, $PB::Config::LOG_FILE) {
	    my %rigs_to_update;
	    flock LOG, $EXCLUSIVE_LOCK;
	    my $count = 1;
	  LOGLINE: foreach my $line (<LOG>) { # slurp the whole thing into mem
	      if ($count++ > $from_pos){
		  chomp $line;
		  if(!$count >= $to_pos) {
		      last LOGLINE;
		  }
		  my ($update, $msg) = split /:/,$line,2;
		  $rigs_to_update{$update} = 1;
	      }
	  }
	    flock LOG, $UNLOCK;
	    close LOG;
	  @changes = keys %rigs_to_update;
	    $reentry_vehicle{"diff"} = \@changes;
	    return (\%reentry_vehicle);
	}
    }
    return(-2);
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
  if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
      return _get_full_log_diff_files($log_pos, $curr_pos);
  } else {
      return _get_full_log_diff_db($log_pos, $curr_pos);
  }
}

sub _get_full_log_diff_files { 
  my $from_pos = shift;
  my $to_pos = shift;
  debug_log("_get_full_log_diff_files: $from_pos - $to_pos\n",6);
  my @entries;
  my @messages;

  my %reentry_vehicle =(
      from => $from_pos,
      to => $to_pos,
      entries => \@entries,
      messages => \@messages);
  
  
  if ($from_pos == $to_pos) {
      return (\%reentry_vehicle);
  } else {
      if(open LOG, $PB::Config::LOG_FILE) {
	  flock LOG, $EXCLUSIVE_LOCK;
	  my $count = 1;
	  LOGLINE: foreach my $line (<LOG>) { # slurp the whole thing into mem
	      if ($count++ > $from_pos){
		  chomp $line;
		  if(!$count >= $to_pos) {
		      last LOGLINE;
		  }
		  my ($update, $msg) = split /\:/, $line, 2;
		  push @entries, $update;
		  push @messages, $msg;
	      }
	  }
	  flock LOG, $UNLOCK;
	  close LOG;
	  $reentry_vehicle{"entries"} = \@entries;
	  $reentry_vehicle{"messages"} = \@messages;
	  return (\%reentry_vehicle);
      }
  }
  return(-2);
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



sub attempt_answer {
    my $puzzid = shift;
    my $answer = shift;
    my $solver = $ENV{'REMOTE_USER'};
    debug_log("attempt_answer:$solver thinks the answer to $puzzid is $answer\n",2);
    my @records;
    push @records, $PB::Config::ANSWER_ATTEMPT_FILE;
    if(open AAFILE, $PB::Config::ANSWER_ATTEMPT_FILE) {
	flock AAFILE, $EXCLUSIVE_LOCK;
	while (<AAFILE>){
	    push @records, $_;
	}
	flock AAFILE, $UNLOCK;
	close AAFILE;
    }
    push @records, "$puzzid\t$answer\t$solver\n";
    return(_write_fields_files(@records));
}


####################
#CONVENIENCE METHODS
####################

sub _write_log_files {
    my $logitem = shift;
    
    if($PB::Config::PB_DATA_WRITE_FILES <= 0) {
	return -1;
    }

    open LOG, ">>$PB::Config::LOG_FILE";
    flock LOG, $EXCLUSIVE_LOCK;
    print LOG "$logitem\n";
    flock LOG, $UNLOCK;
    close LOG;
    my $dataversion = 0;
    if(open LI, "<$PB::Config::LOG_INDEX") {
	flock LI, $EXCLUSIVE_LOCK;
	$dataversion = <LI>;
	flock LI, $UNLOCK;
	close LI;
    }
    
    $dataversion++;
    
    open LI, ">$PB::Config::LOG_INDEX" or die "could not write to log_index !´$PB::Config::LOG_INDEX!\n";
    flock LI, $EXCLUSIVE_LOCK;
    print LI $dataversion;
    flock LI, $UNLOCK;
    close LI;
    
    # update through meteor
    if(PB::Meteor::message($PB::Config::METEOR_VERSION_CHANNEL,$dataversion) > 0) {
	return(1);
    } else {
	return(-3);
    }
}

sub _write_fields_files {
    my $file = shift;
    my @fields = @_;
    debug_log("_write_fields_files: file $file fields @fields\n",4);
    if(open FILE, ">$file") {
	if(flock FILE, $EXCLUSIVE_LOCK) {
	    foreach (@fields){
		print FILE $_;
	    }
	    flock FILE, $UNLOCK;
	    close FILE;
	    return(1);
	} else {
	    debug_log("_write_fields_files: could not lock file [$file]\n",1);
	    return(-1);
	}
    } else {
	debug_log("_write_fields_files: could not open file [$file]\n",1);
	return(-1);
    }
    return(-2);
}


##############
# Client index
##############
sub _get_client_index_files {
    debug_log("get_client_index\n",6);
    my $index = 0;
    if(open CI, "<$PB::Config::CLIENT_INDEX") {
	flock CI, $EXCLUSIVE_LOCK;
	$index = <CI>;
	flock CI, $UNLOCK;
	close CI;
    }
    $index++;
    open CI, ">$PB::Config::CLIENT_INDEX" or die "cannot open client index file for writing ($PB::Config::CLIENT_INDEX)\n";
    flock CI, $EXCLUSIVE_LOCK;
    print CI $index;
    flock CI, $UNLOCK;
    close CI;
    return($index);
}

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
  if($PB::Config::PB_DATA_READ_DB_OR_FILES eq "FILES") {
      return _get_client_index_files();
  } else {
      return _get_client_index_db();
  }
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
    if(PB::Meteor::message($PB::Config::METEOR_VERSION_CHANNEL, $dataversion) <= 0) {
	debug_log("PB::API::_send_data_version() error sending version $dataversion over meteor\n",0);
	$ret = -1;
    }

    return $ret;
}



1;

