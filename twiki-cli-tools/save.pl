#!/usr/bin/perl -w 

use strict;
use warnings;

use lib qw(../lib);

use PB::TWiki;

use Getopt::Long;

my %opt = ();
GetOptions(\%opt, 
	   'topic=s',
	   'parenttopic=s',
	   'templatetopic=s',
	   'prname=s',
	   'puzurl=s',
	   'gssurl=s',
    );


PB::TWiki::twiki_save($opt{'topic'}, \%opt);

