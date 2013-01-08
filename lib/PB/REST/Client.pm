package PB::REST::Client;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';

sub list_GET : Runmode {
    my $self = shift;
    my $version = PB::API::get_client_index();
    my $json = $self->json_body({"clientindex" => $version});
    return($json);
}


1;
