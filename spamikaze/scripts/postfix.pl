#!/usr/bin/perl -wT
#
# getblocks.pl
# Copyright 2003 Hans Wolters (h-wolters@nl.linux.org)
# Copyright 2004 Hans Spaans  <cj.spaans@nexit.nl>
#   <insert GPL 2 or later in here>

use strict;
use warnings;

unshift (@INC, "/opt/spamikaze/scripts");

# Use the new pm, this will load the config.pl and
# set the variables for the db.
require Spamikaze;

my $mta_bl_location = "/tmp/spamikazepostfix";
my $mta_bl_template =
"{IP}\t550 \"{IP} has been used by spammers, see http://spamikaze.is-a-geek.org/listing.php?{IP}\"";
my $mta_bl_domain =
"{DOMAIN}\t550 Your domain has been blacklisted in Spamikaze due to excessive spamming and/or a non working abuse desk.";

my $mta_bl_template_wl = "{EMAIL}";

sub main {
	my $ip;
	my $email;

	open( fileOUT, ">$mta_bl_location.new" )
	  || die ("Can't open $mta_bl_location for writing: $!");
	flock( fileOUT, 2 );
	seek( fileOUT, 0, 2 );

	my $dbh = Spamikaze::DBConnect();

	if ( Spamikaze::GetDBType() eq 'mysql' ) {

		my $sql = "SELECT 
                DISTINCT CONCAT_WS('.',  octa, octb, octc, octd) AS ip
               FROM ipnumbers WHERE visible = 1 ORDER BY octa, octb, octc, octd";
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		$sth->bind_columns( undef, \$ip );

		#    my $bldomain;
		#    foreach $bldomain (@BLACKLISTDOMAINS) {
		#        $_ = $mta_bl_domain;
		#        s/\{DOMAIN\}/$bldomain/;
		#        print fileOUT $_, "\n";
		#    }

		while ( $sth->fetch() ) {
			$_ = $mta_bl_template;
			s/\{IP\}/$ip/g;
			print fileOUT $_, "\n";
		}

		$sth->finish();

	}
	elsif ( Spamikaze::GetDBType() eq 'Pg' ) {

		my $sql = "SELECT DISTINCT octa, octb, octc, octd
                FROM ipnumbers WHERE visible = '1'
                ORDER BY octa, octb, octc, octd";
		my $sth = $dbh->prepare($sql);
		$sth->execute();

		while ( my @row = $sth->fetchrow_array() ) {

			my $ip         = "$row[0].$row[1].$row[2].$row[3]";
			my $txt_record = $mta_bl_template;
			$txt_record    =~ s/\{IP\}/$ip/g;

			print fileOUT $txt_record, "\n";

		}

		$sth->finish();

	}

	close(fileOUT);

	$dbh->disconnect();

	if ( !rename "$mta_bl_location.new", "$mta_bl_location" ) {
		warn "rename $mta_bl_location.new to $mta_bl_location failed: $!\n";
	}


}

&main();
