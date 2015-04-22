#!/usr/bin/perl -wT
#
# getblocks.pl
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2004 Hans Spaans  <cj.spaans@nexit.nl>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.org/

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
 
use Spamikaze;

my $mta_bl_location = "/tmp/spamikazepostfix";
my $mta_bl_template =
"{IP}\t550 \"{IP} has been used by spammers, see http://spamikaze.is-a-geek.org/listing.php?{IP}\"";
my $mta_bl_domain =
"{DOMAIN}\t550 Your domain has been blacklisted in Spamikaze due to excessive spamming and/or a non working abuse desk.";

my $mta_bl_template_wl = "{EMAIL}";

sub main {
	my $ip;

	open( fileOUT, ">$mta_bl_location.new" )
	  || die ("Can't open $mta_bl_location for writing: $!");
	flock( fileOUT, 2 );
	seek( fileOUT, 0, 2 );

	foreach $ip ($Spamikaze::db->get_listed_addresses()) {
		$_ = $mta_bl_template;
		s/\{IP\}/$ip/g;
		print fileOUT $_, "\n";
	}
	close(fileOUT);

	if ( !rename "$mta_bl_location.new", "$mta_bl_location" ) {
		warn "rename $mta_bl_location.new to $mta_bl_location failed: $!\n";
	}
}

&main();
