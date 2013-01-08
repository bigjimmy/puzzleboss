package PB::REST::Version;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';
use CGI::Application::Plugin::ErrorPage 'error';

use Data::Dumper;

sub list_GET : Runmode {
    my $self = shift;
    my $version = PB::API::get_log_index();
    my $json = $self->json_body({"version" => $version});
    return($json);
}

sub list_POST : Runmode {
    my $self = shift;
    return("");
}

sub full_GET : Runmode {
    my $self = shift;
    my $current_index = $self->param('id');
    my $diffref;
    if($self->query->param('full') && ($self->query->param('full') eq "1")) {
	$diffref = PB::API::get_full_log_diff($current_index);
    } else {
	$diffref = PB::API::get_log_diff($current_index);
    }
    my $json = $self->json_body($diffref);
    return($json);
}

sub full_POST : Runmode {
    my $self = shift;
    return("");
}

sub part_GET : Runmode {
    my $self = shift;
    my $current_index = $self->param('id');
    my $to_index = $self->param('part');
    my $diffref;
    if($self->query->param('full') eq "1") {
	$diffref = PB::API::get_full_log_diff($current_index, $to_index);
    } else {
	$diffref = PB::API::get_log_diff($current_index, $to_index);
    }
    my $json = $self->json_body($diffref);
    return($json);
}

sub part_POST : Runmode {
    my $self = shift;
    return("");
}


1;
