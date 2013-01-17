package PB::REST::Solvers;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';

my $error_status = 404;

sub list_GET : Runmode {
    my $self = shift;
    my $solversref = PB::API::get_solver_list();
    my $json = $self->json_body($solversref);
    return($json);
}

sub list_POST : Runmode {
    my $self = shift;
    my $errmsg = "PB::REST::Puzzles::list_POST: POST to puzzle list is not implemented";
    print STDERR $errmsg;
    $error_status = 501;
    die $errmsg;
}

sub full_GET : Runmode {
    my $self = shift;
    my $id = $self->param('id');
    $solverref = PB::API::get_solver($id);
    my $json = $self->json_body($solverref);
    return($json);
}

sub part_GET : Runmode {
	my $self = shift;
	my $id = $self->param('id');
	my $part = $self->param('part');
	my $solverref = PB::API::get_solver($id);
	if(!defined($solverref) || (ref($solverref) eq 'ARRAY' && @$solverref == 0) || (ref($solverref) eq 'HASH' && (keys %$solverref) == 0)) {
	    my $errmsg = "PB::REST::Solvers::part_GET: could not find solver $id";
	    print STDERR $errmsg;
	    $error_status = 404;
	    die $errmsg;
	}
	if(exists($solverref->{$part})) {
		my $partdata = $solverref->{$part};
		my $json = $self->json_body( {
			'id' => $id,
			'part' => $part,
			'data' => $partdata,
			});
		return($json);
	} else {
	    my $errmsg = "PB::REST::Solvers::part_GET: could not find part $part in solver $id";
	    print STDERR $errmsg;
	    $error_status = 404;
	    die $errmsg;
	}
}

sub part_POST : Runmode {
	my $self = shift;
	my $solvername = $self->param('id');
	my $part = $self->param('part');
	my $json = $self->query->param('POSTDATA');
	my $partref = $self->from_json($json);
	if(exists($partref->{'data'})) {	
		if(PB::API::update_solver_part($solvername,$part,$partref->{'data'}) < 0) {
			my $errmsg = "PB::REST::Solvers::part_POST: could not update $part for $solvername";
			print STDERR $errmsg;
			$error_status = 404;
			die $errmsg;
		}
	} else {
		my $errmsg = "PB::REST::Solvers::part_POST: did not specify data for solver $id part $part in json $json";
		print STDERR $errmsg;
		$error_status = 400;
		die $errmsg;
	}
	return $self->json_body({'status'=>'ok'});
}

sub error : ErrorRunmode {
    my $self = shift;
    my $error = shift;
    $self->header_add( -status => $status );
    my $json = $self->query->param('POSTDATA');
    my $partref = $self->from_json($json);
    my $data = $partref->{'data'} || "";
    return $self->json_body({ 'status' => 'error',
			      'error' => $error,
			      'id' => $self->param('id'),
			      'part' => $self->param('part'),
			      'data' => $data,
			    });
}

1;
