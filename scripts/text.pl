#!/usr/bin/perl 

# text.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2003 Rik van Riel <riel@surriel.com>
# Copyright (C) 2004 Hans Spaans  <cj.spaans@nexit.nl>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#        http://spamikaze.org/
#
# generates a plain text file with IP addresses from the spamikaze database
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
 
use Spamikaze;

sub usage {
	print "text.pl <file>\n";
	exit 1;
}

sub main {
	my $ip;
	my $sql;
	my $sth;

	if ($#ARGV != 0) {
		&usage;
	}

	my $outfile = $ARGV[0];

	open( TEXTFILE, ">$outfile.$$" )
	  or die("Can't open $outfile.$$ for writing: $!");
	flock( TEXTFILE, 2 );
	seek( TEXTFILE, 0, 2 );

	foreach $ip ($Spamikaze::db->get_listed_addresses()) {
		print TEXTFILE "$ip\n";
	}

	close TEXTFILE;

	if ( !rename "$outfile.$$", "$outfile" ) {
		warn "rename $outfile.new to $outfile failed: $!\n";
	}

}

&main;
