package PB::REST::Puzzles;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';
use CGI::Application::Plugin::ErrorPage 'error';

use Data::Dumper;

sub list_GET : Runmode {
	my $self = shift;
	my $roundfilter = $self->query->param('roundfilter') || '.*';
	my @puzzles = PB::API::get_puzzle_list($roundfilter);
	my $json = $self->json_body(\@puzzles);
	return($json);
}

sub list_POST : Runmode {
	my $self = shift;
	return("puzzle list post\n");
}

sub full_GET : Runmode {
	my $self = shift;
	my $id = $self->param('id');
	$puzzleref = PB::API::get_puzzle($id);
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
	#    print STDERR "PB::REST::Puzzles::full_POST: have puzzle $id: dump ".Dumper($puzzleref)."\n";
	return("");
}

sub part_GET : Runmode {
	my $self = shift;
	my $id = $self->param('id');
	my $part = $self->param('part');
	my $puzzleref = PB::API::get_puzzle($id);
	if(exists($puzzleref->{$part})) {
		my $partdata = $puzzleref->{$part};
		my $json = $self->json_body( {
			'id' => $id,
			'part' => $part,
			'data' => $partdata,
			});
		return($json);
	} 
}

sub part_POST : Runmode {
    my $self = shift;
    my $id = $self->param('id');
    my $part = $self->param('part');
    my $json = $self->query->param('POSTDATA');
    my $partref = $self->from_json($json);
    if(exists($partref->{'data'})) {
	#print STDERR "PB::REST::Puzzles::part_POST: have data for puzzle $id $part = $partref->{'data'}";
	PB::API::update_puzzle_part($id,$part,$partref->{'data'});
    } else {
	print STDERR "don't have data for puzzle $id $part -- dump of posted data: ".Dumper($partref);
    }
    return("");
}

1;
