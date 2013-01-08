package PB::REST::Solvers;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';
use CGI::Application::Plugin::ErrorPage 'error';

sub list_GET : Runmode {
    my $self = shift;
    my $solversref = PB::API::get_solver_list();
    my $json = $self->json_body($solversref);
    return($json);
}

sub list_POST : Runmode {
    my $self = shift;
    return("solver list post\n");
}

sub full_GET : Runmode {
    my $self = shift;
    my $id = $self->param('id');
    $solverref = PB::API::get_solver($id);
    my $json = $self->json_body($solverref);
    return($json);
}

sub part_POST : Runmode {
	my $self = shift;
	my $solvername = $self->param('id');
	my $part = $self->param('part');
	my $json = $self->query->param('POSTDATA');
	my $partref = $self->from_json($json);
	if(exists($partref->{'data'})) {
		PB::API::update_solver_part($solvername,$part,$partref->{'data'});
	} else {
		print STDERR "don't have data for solver $id $part -- dump of posted data: ".Dumper($partref);
	}
	return("");
}

1;
