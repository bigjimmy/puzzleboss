package PB::Meteor;

use strict;
use PB::Config;

use IO::Socket;

sub debug_log {
    my $message = shift;
    my $level = shift;
    print STDERR $message if($PB::Config::DEBUG>$level);
}

sub message {
    my $channel = shift;
    my $message = shift;
    my $remote = IO::Socket::INET->new(
	Proto => "tcp",
	PeerAddr => $PB::Config::METEOR_CONTROL_HOST,
	PeerPort => $PB::Config::METEOR_CONTROL_PORT,
	) or debug_log("PB::Meteor cannot connect to meteor server at $PB::Config::METEOR_CONTROL_HOST on port $PB::Config::METEOR_CONTROL_PORT",0);
    print $remote "ADDMESSAGE $channel $message\n";
    my $response = <$remote>;
    if($response =~ m/OK/) {
	print $remote "QUIT\n";
	close $remote;
	debug_log("PB::Meteor response OK for channel $channel message $message\n",2);
	return(1);
    } else {
	debug_log("PB::Meteor error: $response\n",0);
	return(-1);
    }
}

1;

