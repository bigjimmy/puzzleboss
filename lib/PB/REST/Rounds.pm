package PB::REST::Rounds;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';
use CGI::Application::Plugin::ErrorPage 'error';

sub list_GET : Runmode {
	my $self = shift;
	my @rounds = PB::API::get_round_list();
	my $json = $self->json_body(\@rounds);
	return($json);
}

sub full_POST : Runmode {
	my $self = shift;
	my $roundid = $self->param('id');
	#    my $header = $self->query->header();
	#    my $json = $self->query->param('POSTDATA');
	#    my $roundref = $self->from_json($json);

	$roundid =~ s/\-/Dash/g;
	$roundid =~ s/\_/Underscore/g;

	print STDERR "PB::REST::Rounds::full_POST: request to create round $roundid\n"; #dump ".Dumper($roundref)."\n";
	if($roundid =~ /^([A-Z][[:alnum:]]+)$/) {
		# ok round id, try to add it
		my $rval = PB::API::add_round($roundid);
		if($rval == 0) {
			# success!
			my %status;
			$status{roundid} = $roundid;
			$status{status} = "success";
			my $json = $self->json_body(\%status);
			return $json;
		} else {
			# error adding round
			PB::API::debug_log("Rounds.pm: full_POST: error adding round\n",1);
			my %status;
			$status{error} = "could not add $roundid, error $rval";
			$status{status} = "error";
			my $json = $self->json_body(\%status);
			return($json);
		}
	} else {
		my $fixuproundid = $roundid;
		$fixuproundid =~ s/[^[:alnum:]]//g; # must be alphanumeric
		$fixuproundid = ucfirst($fixuproundid); # must start with uppercase letter
		PB::API::debug_log("Rounds.pm: full_POST: roundid $roundid not valid, try $fixuproundid\n",3);
		my %status;
		$status{error} = "roundid contained invalid characters. try: $fixuproundid";
		$status{roundid} = $fixuproundid;
		$status{status} = "error";
		my $json = $self->json_body(\%status);
		return($json);
	}
}

1;
