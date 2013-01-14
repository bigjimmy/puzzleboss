package PB::REST::Rounds;
use base 'CGI::Application';

use CGI::Application::Plugin::AutoRunmode;
use PB::Config;
use PB::API;

use CGI::Application::Plugin::JSON ':all';

my $error_status = 404;

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
			return $self->json_body({ 'status'=>'ok',
						  'roundid'=>$roundid
						});
		} else {
		    # error adding round
		    PB::API::debug_log("Rounds.pm: full_POST: error adding round\n",1);
		    my $errmsg = "could not add $roundid, error $rval";
		    print STDERR $errmsg;
		    $error_status = 404;
		    die $errmsg;
		}
	} else {
		my $fixuproundid = $roundid;
		$fixuproundid =~ s/[^[:alnum:]]//g; # must be alphanumeric
		$fixuproundid = ucfirst($fixuproundid); # must start with uppercase letter
		PB::API::debug_log("Rounds.pm: full_POST: roundid $roundid not valid, try $fixuproundid\n",3);
#		$status{roundid} = $fixuproundid;
		my $errmsg = "roundid contained invalid characters. try: $fixuproundid";
		print STDERR $errmsg;
		$error_status = 404;
		die $errmsg;
	}
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
