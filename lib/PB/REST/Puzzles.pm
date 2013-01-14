package PB::REST::Puzzles;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';

use Data::Dumper;

my $error_status = 404;

sub list_GET : Runmode {
	my $self = shift;
	my $roundfilter = $self->query->param('roundfilter') || '.*';
	my @puzzles = PB::API::get_puzzle_list($roundfilter);
	my $json = $self->json_body(\@puzzles);
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
	$puzzleref = PB::API::get_puzzle($id);
	if(!defined($puzzleref) || (ref($puzzleref) eq 'ARRAY' && @$puzzleref == 0) || (ref($puzzleref) eq 'HASH' && (keys %$puzzleref) == 0)) {
	    my $errmsg = "PB::REST::Puzzles::full_GET: could not find puzzle $id";
	    print STDERR $errmsg;
	    $error_status = 404;
	    die $errmsg;
	}
	my $json = $self->json_body($puzzleref);
	return($json);
}

sub full_POST : Runmode {
	my $self = shift;
	my $id = $self->param('id');
	#    my $header = $self->query->header();
	my $json = $self->query->param('POSTDATA');
	my $puzzleref = $self->from_json($json);
	# TODO implement me
	my $errmsg = "PB::REST::Puzzles::full_POST: NOT IMPLEMENTED";
	print STDERR $errmsg;
	$error_status = 501;
	die $errmsg;
}

sub part_GET : Runmode {
	my $self = shift;
	my $id = $self->param('id');
	my $part = $self->param('part');
	my $puzzleref = PB::API::get_puzzle($id);
	if(!defined($puzzleref) || (ref($puzzleref) eq 'ARRAY' && @$puzzleref == 0) || (ref($puzzleref) eq 'HASH' && (keys %$puzzleref) == 0)) {
	    my $errmsg = "PB::REST::Puzzles::part_GET: could not find puzzle $id";
	    print STDERR $errmsg;
	    $error_status = 404;
	    die $errmsg;
	}
	if(exists($puzzleref->{$part})) {
		my $partdata = $puzzleref->{$part};
		my $json = $self->json_body( {
			'id' => $id,
			'part' => $part,
			'data' => $partdata,
			});
		return($json);
	} else {
	    my $errmsg = "PB::REST::Puzzles::part_GET: could not find part $part in puzzle $id";
	    print STDERR $errmsg;
	    $error_status = 404;
	    die $errmsg;
	}
}

sub part_POST : Runmode {
	my $self = shift;
	my $id = $self->param('id');
	my $part = $self->param('part');
	my $json = $self->query->param('POSTDATA');
	my $partref = $self->from_json($json);
	if(exists($partref->{'data'})) {
		if(PB::API::update_puzzle_part($id,$part,$partref->{'data'}) < 0) {
			my $errmsg = "PB::REST::Puzzles::part_POST: could not update $part for $id";
			print STDERR $errmsg;
			$error_status = 404;
			die $errmsg;
		}
	} else {
		my $errmsg = "PB::REST::Puzzles::part_POST: did not specify data for puzzle $id part $part in json $json";
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
