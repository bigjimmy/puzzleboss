package PB::Register;
use base 'CGI::Application';

use strict;
use warnings;

use CGI::Application::Plugin::AutoRunmode;
use CGI::Application::Plugin::Forward;
#use CGI::Application::Plugin::Redirect;

use PB::Config;
use PB::API;

use Net::LDAP;
use Mail::Sendmail qw(sendmail %mailcfg);
use Data::Random qw(rand_chars);
use MLDBM qw(DB_File);
use Fcntl;

my $errormessage = "";

sub registration : StartRunmode {
    my $self = shift;
    my $q = $self->query();

    my $nextrm = "registration";
    my $html = $q->start_html($PB::Config::TEAM_NAME.' New User Registration').
	$q->h1($PB::Config::TEAM_NAME.' New User Registration');

#    my $firstname = $q->param('firstname');
#    my $q->param('lastname') = $q->param('lastname');
#    my $email = $q->param('email');
#    my $password = $q->param('password');

    my $notifyempty = 0;
    if($q->param('rm')) {
	# if runmode was set then the user has already submitted once
	$notifyempty = 1;
    }
    
    my $entriesok = 1;
    if(! ($q->param('firstname') && $q->param('lastname') && $q->param('email') && $q->param('password') && $q->param('password2')) ) {
	$entriesok = 0;
    }
    
    if($q->param('changes')) {
	# user was in verify mode but wants to make changes
	$entriesok = 0;
    }

    my $formproblems = validate_registration_form_data($q, $notifyempty);
    if($formproblems ne "") {
	$entriesok = 0;
	$html .= $formproblems;
    }
    
    # set username
    if($q->param('firstname') && $q->param('lastname')) {
	$q->param('username', $q->param('firstname').$q->param('lastname'));
    }
    
    if($entriesok) {
	$nextrm = "validation";
	# print entries for verification before submitting
	$html .= $q->p."Please verify the registration information before proceeding.".$q->start_form(-method => 'POST').
	    $q->dl.
	    $q->dt."First Name:".$q->dd.$q->textfield(-name=>'firstname', -readonly => 'readonly').
	    $q->dt."Last Name:".$q->dd.$q->textfield(-name=>'lastname', -readonly => 'readonly').
	    $q->dt."E-mail Address:".$q->dd.$q->textfield(-name=>'email', -size=>50, -readonly => 'readonly').
	    $q->dt."Password:".$q->dd.$q->password_field(-name=>'password', -readonly => 'readonly').
	    $q->dt."Re-enter Password:".$q->dd.$q->password_field(-name=>'password2', -readonly => 'readonly').
	    $q->dt."Username (read-only):".$q->dd.$q->textfield(-name => 'username', -readonly => 'readonly').
	    $q->p.$q->submit(-name=>'verifyregister', value=>'Everything looks good. Proceed with registration.').
	    $q->p.$q->submit(-name=>'changes', value=>'I want to make changes, please!').
	    $q->hidden(-name => 'rm', -value => $nextrm, -override=>1).
	    $q->end_form;
    } else {
	# get entries
	$html .= $q->p."Please use your real first and last name (unless most people on the team don't know you by that name) and an e-mail address that you can access (for verification).".$q->start_form(-method => 'POST').
	    $q->dl.
	    $q->dt."First Name:".$q->dd.$q->textfield(-name=>'firstname').
	    $q->dt."Last Name:".$q->dd.$q->textfield(-name=>'lastname').
	    $q->dt."E-mail Address:".$q->dd.$q->textfield(-name=>'email').
	    $q->dt."Password:".$q->dd.$q->password_field(-name=>'password').
	    $q->dt."Re-enter Password:".$q->dd.$q->password_field(-name=>'password2').
	    $q->p.$q->submit(-name=>'register', -value=>'Register for an account').
	    $q->hidden(-name => 'username').
	    $q->hidden(-name => 'rm', -value => $nextrm, -override=>1).
	    $q->end_form;
    }
    
    return($html);
}

sub validation : Runmode {
    my $self = shift;
    my $q = $self->query();
    my $html = $q->start_html($PB::Config::TEAM_NAME.' New User Registration');
    
    # If changes is set then the user requested to go back to registration form
    if($q->param('changes')) {
	# user was in verify mode but wants to make changes -- return to registration
	return $self->forward('registration');
    } 

    # If we are here the user has given confirmed their entries, or they are trying to hack us
    # Better re-validate entries just to be sure...
    if((my $formproblems = validate_registration_form_data($q, 1)) ne "") {
        # bad forms get kicked back up to registration 
#	$html .= "bad registration data: $formproblems";
	$errormessage = $formproblems;
	return $self->forward('error');
    } else {
	# good data, ready to go!
	# except first we should untaint the data and protect ourselves one more time
	my $errmsg = "";
	$q->param('firstname') =~ m/^([A-Z][a-zA-Z]+)$/ or $errmsg.="Bad firstname. ";
	my $firstname = $1;
	$q->param('lastname') =~ m/^([A-Z][a-zA-Z]*)$/ or $errmsg.="Bad lastname. ";
	my $lastname = $1;
	$q->param('username') =~ m/^([A-Z][a-zA-Z]+[A-Z][a-zA-Z]*)$/ or $errmsg.="Bad username. ";
	my $username = $1;
	# email address first part chars: http://www.remote.org/jochen/mail/info/chars.html
	# hostname chars RFC1123
	$q->param('email') =~ m/^([0-9a-zA-Z&'*+\-\.\/=?^_{}~]+\@[a-z0-9][a-z0-9\-\.]*[a-z0-9])$/ or $errmsg.="Bad e-mail. ";
	my $email = $1;
	$q->param('password') =~ m/^([0-9a-zA-Z\!\#\%\(\)\*\+\,\-\.\/\~\:\=\?\@\[\\\]\^\_\{\}]+)$/ or $errmsg.="Bad password. ";
	my $password = $1;
	$q->param('password2') =~ m/^([0-9a-zA-Z\!\#\%\(\)\*\+\,\-\.\/\~\:\=\?\@\[\\\]\^\_\{\}]+)$/ or $errmsg.="Bad password2. ";
	my $password2 = $1;
	
	# a few more sanity checks
	if($password ne $password2) {
	    $errmsg .= "Password mismatch.";
	}
	if($username ne $firstname.$lastname) {
	    $errmsg .= "Name/Username mismatch.";
	}
	if($errmsg ne "") {
	    $errormessage =  $errmsg;
	    return $self->forward('error');
	}
	
	
	# connect to LDAP to check to make sure user doesn't already exist
	my $ldap = Net::LDAP->new( "$PB::Config::REGISTER_LDAP_HOST" );

        # bind to a directory with dn and password
        my $mesg = $ldap->bind( "cn=$PB::Config::REGISTER_LDAP_ADMIN_USER,$PB::Config::REGISTER_LDAP_DC",
			    password => $PB::Config::REGISTER_LDAP_ADMIN_PASS
	    );

	my $result = $ldap->search( # perform a search
                               base   => "$PB::Config::REGISTER_LDAP_DC",
                               filter => "(uid=$username)",
			       attrs => ['uid'],
	    );
	
	#foreach my $entry ($result->entries) { $html .= "<li>have LDAP entry: [".$entry->ldif."]</li>/"; }
	my $matchcount = $result->count();

	if($matchcount > 0) {
	    $html .= "Username $username already exists!  If you have lost your password, please see the puzzlebitch or Joshua Randall to get it reset. ";
	} else {
	    # username does not already exist, check for email
	    my $emailresult = $ldap->search( # perform a search
					base   => "$PB::Config::REGISTER_LDAP_DC",
					filter => "(email=$email)",
					attrs => ['uid'],
		);
	    my $emailmatchcount = $emailresult->count();
	    
	    if($emailmatchcount > 0) {
		my $ldapuid = $emailresult->entry(0)->get_value('uid');
		$html .= "E-mail $email already exists for username $ldapuid!";
	    } else {
		# no duplication, we are ok to proceed to email validate this new user

		# generate email validation code
		my $validation_code = join('',rand_chars( set => 'alphanumeric', size => '32' ));
		my $time = time();
		
		# store data in DB by validation code for lookup later
		my %hash;
		if( ! tie(%hash, 'MLDBM', "$PB::Config::REGISTER_DATA_PATH/validation.db", O_CREAT|O_RDWR, 0660) ) {
		    $errormessage="could not open tie to $PB::Config::REGISTER_DATA_PATH/validation.db";
		    return $self->forward('error');
		}
		my $aref = $hash{$validation_code};
		$aref->{firstname} = $firstname;
		$aref->{lastname} = $lastname;
		$aref->{username} = $username;
		$aref->{email} = $email;
		$aref->{password} = $password;
		$aref->{timestamp} = $time;
		$hash{$validation_code} = $aref;
		untie %hash;

		# send email to confirm email address
		my %mail = (
		    To => $email,
		    From => $PB::Config::REGISTER_EMAIL_FROM,
		    Subject => "$PB::Config::TEAM_NAME user registration",
		    'content-type' => 'text/plain',
		    );
		$mail{body} = <<EOB;
You, or someone on your behalf, has used this email address to register for an account on $PB::Config::GOOGLE_DOMAIN

The validation code for that request is: $validation_code

Please either enter that code into the registration page or visit $PB::Config::REGISTER_URI?rm=confirm_validation&validationcode=$validation_code to complete your registration.

EOB
                $mailcfg{smtp} = [qw(localhost)];
		if(sendmail %mail) {
		    $html .= $q->p."A validation code has been sent to your email address: [$email].".
			$q->p."Please check your mail and either follow the link in the email or enter the code here.".
			$q->start_form(-method => 'POST').
			$q->dl.
			$q->dt."Validation code:".$q->dd.$q->textfield(-name=>'validationcode', -size=>40).
			$q->p.$q->submit(-name=>'register', -value=>'Confirm validation code.').
			$q->hidden(-name => 'rm', -value => 'confirm_validation', -override=>1).
			$q->end_form;
		} else {
		    $html .= $q->p."A confirmation problem with this site has prevented us from sending you the confirmation email. Please contact puzzlebitch or Joshua Randall for assistance. [$Mail::Sendmail::error]";
		}

	    }
	}
	$mesg = $ldap->unbind;  # take down LDAP session
    }
    return($html);
}

sub confirm_validation : Runmode {
    my $self = shift;
    my $q = $self->query();
    my $html = $q->start_html($PB::Config::TEAM_NAME.' User Registration: Validation Code');

    my $firstname;
    my $lastname;
    my $username;
    my $email;
    my $password;
    my $time;
          
    # lookup this validation code in the tied hash db file
    my $validation_code = $q->param('validationcode');
    
    my %hash;
    if(! tie(%hash, 'MLDBM', "$PB::Config::REGISTER_DATA_PATH/validation.db", O_CREAT|O_RDWR, 0660)) {
	$errormessage = "could not open tie to $PB::Config::REGISTER_DATA_PATH/validation.db";
	return $self->forward('error');
    }
    if(exists($hash{$validation_code})) {
	my $aref = $hash{$validation_code};
	$firstname = $aref->{firstname};
	$lastname = $aref->{lastname};
	$username = $aref->{username};
	$email = $aref->{email};
	$password = $aref->{password};
	$time = $aref->{timestamp};
	$html .= $q->p."Creating $PB::Config::GOOGLE_DOMAIN user account $username for $firstname $lastname.";
    } else {
	$html .= "Sorry, the validation code you entered was not recognized.".
	    $q->start_form(-method => 'POST').
	    $q->dl.
	    $q->dt."Validation code:".$q->dd.$q->textfield(-name=>'validationcode', -size=>40).
	    $q->p.$q->submit(-name=>'register', -value=>'Confirm validation code.').
	    $q->hidden(-name => 'rm', -value => 'confirm_validation', -override=>1).
	    $q->end_form;
	return($html);
    }
    untie %hash;
    
    # ok, let's create them!
    my $ldap_rval = PB::API::ldap_add_user($username, $firstname, $lastname, $email, $password);
    if($ldap_rval != 0) {
	$html.=$q->p."Error adding user to LDAP.";
    } else {
	$html.=$q->p."User added to $PB::Config::REGISTER_LDAP_O LDAP.";
    }

    # add to google apps for education
    my $google_rval = PB::API::google_add_user($username, $firstname, $lastname, $password);
    if($google_rval != 0) {
	$html.=$q->p."Error adding user to google apps for education domain.";
    } else {
	$html.=$q->p."User added to google apps for education domain ($PB::Config::REGISTER_LDAP_DOMAIN).";
    }
    
    # now add to twiki
    my $twiki_rval = PB::API::twiki_add_user($username, $firstname, $lastname, $email, $password);
    if($twiki_rval != 0) { 
	$html.=$q->p."Error adding user to TWiki (this may just be because your UserTopic already existed)";
    } else {
	$html.=$q->p.'User added to <a href="$PB::Config::TWIKI_URI">TWiki</a>.';
    }

    my $pbdb_rval = PB::API::add_solver($username);
    if(!($pbdb_rval < 0)) {
	$html.=$q->p."User added to solver database.";
    } else {
	$html.=$q->p."Error adding user to solver database.";
    }
    
    $html.=$q->p.'If all was successful, you should now be able to login to the TWiki: <a href="'.$PB::Config::TWIKI_URI.'">'.$PB::Config::TWIKI_URI.'</a>';
    return($html);
}


sub error : Runmode {
    my $self = shift;
    my $q = $self->query();
    my $html = "";

    $html .= $q->start_html($PB::Config::TEAM_NAME.' User Registration: Error');
    $html .= $q->p."An error occurred: $errormessage\n";

    return($html);
}

sub validate_registration_form_data {
    my $q = shift;
    my $notifyempty = shift;
    my $html = "";
    
    if($q->param('firstname') && $q->param('firstname') ne "") {
	if($q->param('firstname') =~ m/^[^A-Z]/) {
	    $q->param('firstname', ucfirst($q->param('firstname')));
	    $html .= $q->p."First letter of first name must be uppercase (I have fixed this for you).";
	}
	if($q->param('firstname') =~ m/[^a-zA-Z]/) {
	    my $fn = $q->param('firstname');
	    $fn =~ s/[^a-zA-Z]//g;
	    $q->param('firstname', $fn);
	    $html .= $q->p."Only letters are allowed in first name (no spaces, punctuation, or numbers -- these have been removed).";
	}
    } else {
	$html .= $q->p."Please enter your first name." if($notifyempty);
    }
	
    if($q->param('lastname') && $q->param('lastname') ne "") {
	if($q->param('lastname') =~ m/^[^A-Z]/) {
	    $q->param('lastname', ucfirst($q->param('lastname')));
	    $html .= $q->p."First letter of last name must be uppercase (I have fixed this for you).";
	}
	if($q->param('lastname') =~ m/[^a-zA-Z]/) {
	    my $ln = $q->param('lastname');
	    $ln =~ s/[^a-zA-Z]//g;
	    $q->param('lastname', $ln);
	    $html .= $q->p."Only letters are allowed in last name (no spaces, punctuation, or numbers -- these have been removed).";
	}
    } else {
	$html .= $q->p."Please enter your last name." if($notifyempty);
    }
    
    if($q->param('email') && $q->param('email') ne "") {
	if(! ($q->param('email') =~ m/^([0-9a-zA-Z\&\'\*\+\-\.\/\=\?\^\_\{\}\~]+)\@([a-z0-9][a-z0-9\-\.]*[a-z0-9])$/)) {
	    $html .= $q->p."Please enter valid E-mail address. ";
	    if($q->param('email') =~ m/^([^@]+)\@([^@]+)$/) {
		my $emailfirstpart = $1;
		my $emailhostpart = $2;
		if($emailfirstpart =~ s/[^0-9a-zA-Z&'*+\-\.\/=?^_{}~]//g > 0) {
		    $html .= "Illegal character in first part (before @). ";
		}
		if($emailhostpart =~ m/[A-Z]/) {
		    $emailhostpart = lc($emailhostpart);
		    $html .= "Switching email hostname to lowercase.";
		}
		$q->param('email', $emailfirstpart."@".$emailhostpart);
	    } else {
		if($q->param('email') =~ m/\@.*\@/) {
		    $html .= "Multiple AT-symbols not supported.";
		} elsif(!($q->param('email') =~ m/\@/)) {
		    $html .= "Did not find an AT-symbol in your e-mail address. Please correct!";
		}
	    }
	}
    } else {
	$html .= $q->p."Please enter your E-mail address." if($notifyempty);
    }

    if($q->param('password') && $q->param('password') ne "" && $q->param('password2') && $q->param('password2') ne "") {
	if($q->param('password') ne $q->param('password2')) {
	    $html .= $q->p."Passwords must match, please re-enter!";
	    $q->param('password', "");
	    $q->param('password2', "");
	} else {
	    if(length($q->param('password')) < 8) {
		$html .= $q->p."Password must be at least 8 characters long";
		$q->param('password', "");
		$q->param('password2', "");
	    } 
	    if($q->param('password') =~ m/[^0-9a-zA-Z\!\#\%\(\)\*\+\,\-\.\/\~\:\=\?\@\[\\\]\^\_\{\}]/) {
		$html .= $q->p."Password contains disallowed characters. Please limit your password to the character class [0-9a-zA-Z\!\#\%\(\)\*\+\,\-\.\/\~\:\=\?\@\[\\\]\^\_\{\}]";
		$q->param('password', "");
		$q->param('password2', "");
	    }
	}
    } else {
	$html .= $q->p."Please enter your password twice." if($notifyempty);
    }

    return($html);
}



1;
