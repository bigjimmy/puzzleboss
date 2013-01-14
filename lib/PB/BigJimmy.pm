package PB::BigJimmy;

use strict;
use PB::Config;

use LWP::UserAgent;

sub debug_log {
    my $message = shift;
    my $level = shift;
    print STDERR $message if($PB::Config::DEBUG>$level);
}

sub send_version {
    my $version = shift;
    
    my $version_post_uri = $PB::Config::BIGJIMMY_BOT_CONTROL_URI."version";

    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(
	POST => $version_post_uri,
	);
    
    $req->authorization_basic($PB::Config::BIGJIMMY_BOT_CONTROL_USER, $PB::Config::BIGJIMMY_BOT_CONTROL_PASS);

    $req->content('{"version":"'.$version.'"}');
    my $res = $ua->request($req);
    
    if ($res->is_success) {
	return 1;
    } else {
	debug_log("PB:BigJimmy error, http status: [".$res->status_line."] from [".$version_post_uri."]\n",0);
	return -1;
    }
}

1;
