package PB::REST::Version;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';

use Data::Dumper;

my $error_status = 404;

sub list_GET : Runmode {
    my $self = shift;
    my $version = PB::API::get_log_index();
    if($version < 0) {
	my $errmsg = "PB::REST::Version::list_GET: not found (perhaps no data is present in the database?)";
	print STDERR $errmsg;
	$error_status = 404;
	die $errmsg;
    }
    my $json = $self->json_body({"version" => $version});
    return($json);
}

sub list_POST : Runmode {
    my $self = shift;
    my $errmsg = "PB::REST::Version::list_POST: POST to version list is not implemented";
    print STDERR $errmsg;
    $error_status = 501;
    die $errmsg;
}

sub full_GET : Runmode {
    my $self = shift;
    my $current_index = $self->param('id');
    my $diffref;
    if($self->query->param('full') && ($self->query->param('full') eq "1")) {
	$diffref = PB::API::get_full_log_diff($current_index);
	if(ref($diffref) ne 'HASH') {
	    my $errmsg = "PB::REST::Version::full_GET: PB::API::get_full_log_diff($current_index): $diffref";
	    print STDERR $errmsg;
	    $error_status = 404;
	    die $errmsg;
	}
    } else {
	$diffref = PB::API::get_log_diff($current_index);
	if(ref($diffref) ne 'HASH') {
	    my $errmsg = "PB::REST::Version::full_GET: PB::API::get_log_diff($current_index): $diffref";
	    print STDERR $errmsg;
	    $error_status = 404;
	    die $errmsg;
	}
    }
    my $json = $self->json_body($diffref);
    return($json);
}

sub full_POST : Runmode {
    my $self = shift;
    my $errmsg = "PB::REST::Version::full_POST: POST not implemented";
    print STDERR $errmsg;
    $error_status = 501;
    die $errmsg;
}

sub part_GET : Runmode {
    my $self = shift;
    my $current_index = $self->param('id');
    my $to_index = $self->param('part');
    my $diffref;
    if($self->query->param('full') eq "1") {
	$diffref = PB::API::get_full_log_diff($current_index, $to_index);
	if(ref($diffref) ne 'HASH') {
	    my $errmsg = "PB::REST::Version::part_GET: PB::API::get_full_log_diff($current_index, $to_index): $diffref";
	    print STDERR $errmsg;
	    $error_status = 404;
	    die $errmsg;
	}
    } else {
	$diffref = PB::API::get_log_diff($current_index, $to_index);
	if(ref($diffref) ne 'HASH') {
	    my $errmsg = "PB::REST::Version::part_GET: PB::API::get_log_diff($current_index, $to_index): $diffref";
	    print STDERR $errmsg;
	    $error_status = 404;
	    die $errmsg;
	}
    }
    my $json = $self->json_body($diffref);
    return($json);
}

sub part_POST : Runmode {
    my $self = shift;
    my $errmsg = "PB::REST::Version::part_POST: POST not implemented";
    print STDERR $errmsg;
    $error_status = 501;
    die $errmsg;
}

sub error : ErrorRunmode {
    my $self = shift;
    my $error = shift;
    $self->header_add( -status => $status );
    return $self->json_body({ 'status' => 'error',
			      'error' => $error,
			      'id' => $self->param('id'),
			      'part' => $self->param('part'),
			    });
}

1;
