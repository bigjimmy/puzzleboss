package PB::REST::Client;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';

my $error_status = 404;

sub list_GET : Runmode {
    my $self = shift;
    my $version = PB::API::get_client_index();
    if($version < 0) {
	my $errmsg = "PB::REST::Client: error getting client index";
	print STDERR $errmsg;
	$error_status = 500;
	die $errmsg;
    } else {
	my $json = $self->json_body({"clientindex" => $version});
	return($json);
    }
}

sub error : ErrorRunmode {
    my $self = shift;
    my $error = shift;
    $self->header_add( -status => $status );
    return $self->json_body({ 'status' => 'error',
			      'error' => $error,
			    });
}

1;
