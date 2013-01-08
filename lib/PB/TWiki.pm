package PB::TWiki;
use strict;
use warnings;

use PB::Config;

use WWW::Mechanize;
use HTTP::Request::Common;

sub debug_log {
    my $message = shift;
    my $level = shift;
    print STDERR $message if($PB::Config::TWIKI_DEBUG>$level);
}

my $mech = WWW::Mechanize->new( 
    agent => "PB::TWiki/0.01",
    );
push @{ $mech->requests_redirectable }, 'POST';

my $saveuri = $PB::Config::TWIKI_BIN_URI.'/save/'.$PB::Config::TWIKI_WEB;

sub twiki_save {
    my $topic = shift;
    my $saveopts = shift;
    $saveopts->{'topic'} = "$PB::Config::TWIKI_WEB.".$topic;
    $saveopts->{'user'} = $PB::Config::TWIKI_USER;
    $saveopts->{'action_save'} = 1;
#    $saveopts->{'onlynewtopic'} = 1;
    my $savepost = POST $saveuri, $saveopts;
#    [ 
#      topic => "$PB::Config::TWIKI_WEB.".$topic,
#      user => $PB::Config::TWIKI_USER,
#      action_save => 1,
#      onlynewtopic => 1,
#      topicparent => $parenttopic,
#      templatetopic => $templatetopic,
#      prname => $prname'},
#      puzurl => $opt{'puzurl'},
#      gssurl => $opt{'gssurl'},
#    ];
    debug_log("prepared POST request to $saveuri with content [".$savepost->content()."]\n", 5);
    
    $mech->request($savepost);
    
# if an authorization form is found, submit it
    if($mech->form_with_fields( "username", "password" )) {
	debug_log("found authorization form, submitting credentials for $PB::Config::TWIKI_USER\n", 5);
	$mech->submit_form( with_fields => { 
	    "username" => $PB::Config::TWIKI_USER,
	    "password" => $PB::Config::TWIKI_USER_PASS,
			    });
	if(my $form = $mech->form_with_fields( "SAMLResponse" )) {
	    $mech->click();
	}
	
	debug_log("attempting to re-POST save data\n", 5);
	$mech->request($savepost);
    } else {
	# no authorization form found, post may already have been successful
	debug_log("authorization form not found, we have probably already been successful with save\n",5);
    }
    
    if($mech->uri() =~ m/bin\/oops/) {
	# got OOPS (error) page, output error and exit with error
	my $errortext =  $mech->content( format => 'text' );
	$errortext =~ s/^.*TWikiAttention[[:space:]]*//;
	$errortext =~ s/\.[^[:alpha:]]*Copyright.*$//;
	$errortext =~ s/Please\ go\ back.*//i;
	$errortext =~ s/[[:space:]]/\ /g;
	
	debug_log($errortext."\n", 1);
	return(-1);
    } else {
	debug_log("have uri ".$mech->uri()."\n", 3);
	if($mech->uri() =~ m/\/view/) {
	    debug_log("success!\n", 2);
	    return(0);
	} else {
	    my $errortext =  $mech->content( format => 'text' );
	    $errortext =~ s/[[:space:]]/\ /g;
	    debug_log($errortext."\n", 1);
	    return(-2);
	}
    }
}
#print STDERR "dumping contents to STDOUT\n";
#print $mech->content();

#print STDERR "dumping all text to STDOUT\n";
#print $mech->content( format => 'text' );

#print STDERR "dumping all headers\n";
#$mech->dump_headers(STDERR);

#print STDERR "dumping all forms\n";
#$mech->dump_forms();

#print STDERR "dumping results of submission\n";
#$mech->dump_all(STDERR);

