#!/usr/bin/perl -wT
#
# named.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2003 Rik van Riel <riel@surriel.com>
# Copyright (C) 2004 Hans Spaans  <cj.spaans@nexit.nl>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#        http://spamikaze.surriel.com/
#
# generates named zone files from the spamikaze database, run this
# from a cronjob every few minutes so removals from the list are fast

use strict;
use warnings;

unshift (@INC, "/home/webapps/spamikaze/spamikaze/spamikaze/scripts");
unshift (@INC, "/opt/spamikaze/scripts");

# Use the new pm, this will load the config.pl and
# set the variables for the db.
require Spamikaze;

# $mta_bl_location  // Path and file of your blocklist.
# $mta_bl_template  // Template string for the blocklist.

#
# CONFIGURE THIS FOR YOUR SETUP
#
my $zone_header = '$TTL 300
@	IN	SOA	spamikaze.yourdomain.tld.	root.spamikaze.yourdomain.tld.  ({TIMESTAMP} 600 300 86400 300)
	IN	NS	spamikaze.yourdomain.tld.
	IN	NS	your.other.nameserver.tld.
$ORIGIN spamikaze.yourdomain.tld.
2.0.0.127	IN	A	127.0.0.2
		IN	TXT	"spamikaze.yourdomain.tld test entry"
';

my $mta_bl_location = "/tmp/psbl.zone";
my $mta_bl_a        = "{IP}\t300\tIN\tA\t127.0.0.2";
my $mta_bl_txt      =
  "\t\t\tIN\tTXT\t\"http://spamikaze.yourdomain.tld/listing.php?{IP}\"";

sub main {
	my $ip;
	my $sql;
	my $sth;
	my @row;

	open( ZONEFILE, ">$mta_bl_location.new" )
	  or dienice("Can't open $mta_bl_location for writing: $!");
	flock( ZONEFILE, 2 );
	seek( ZONEFILE, 0, 2 );

	my $epoch = time();
	$zone_header =~ s/\{TIMESTAMP\}/$epoch/;
	print ZONEFILE $zone_header;

	my $dbh = Spamikaze::DBConnect();

	if ( Spamikaze::GetDBType() eq 'mysql' ) {
		$sql = "SELECT CONCAT_WS('.', octa, octb, octc, octd) AS ip
                FROM ipnumbers WHERE visible = 1 ORDER BY ip";
		$sth = $dbh->prepare($sql);
		$sth->execute();
		$sth->bind_columns( undef, \$ip );

		while ( $sth->fetch() ) {
			my $txt_record = $mta_bl_txt;
			my $a_record   = $mta_bl_a;
			my $revip      = $ip;
			$revip =~ s/(\d+)\.(\d+)\.(\d+)\.(\d+)/$4.$3.$2.$1/;

			$a_record   =~ s/\{IP\}/$revip/;
			$txt_record =~ s/\{IP\}/$ip/;
			print ZONEFILE $a_record,   "\n";
			print ZONEFILE $txt_record, "\n";
		}
	}
	elsif ( Spamikaze::GetDBType() eq 'Pg' ) {
		$sql = "SELECT DISTINCT octa, octb, octc, octd
                FROM ipnumbers WHERE visible = '1'
                ORDER BY octa, octb, octc, octd";
		$sth = $dbh->prepare($sql);
		$sth->execute();

		while ( @row = $sth->fetchrow_array() ) {
			my $ip         = "$row[0].$row[1].$row[2].$row[3]";
			my $txt_record = $mta_bl_txt;
			my $a_record   = $mta_bl_a;
			my $revip      = $ip;
			$revip =~ s/(\d+)\.(\d+)\.(\d+)\.(\d+)/$4.$3.$2.$1/;

			$a_record   =~ s/\{IP\}/$revip/;
			$txt_record =~ s/\{IP\}/$ip/;
			print ZONEFILE $a_record,   "\n";
			print ZONEFILE $txt_record, "\n";
		}
	}

	close ZONEFILE;

	$sth->finish();

	if ( !rename "$mta_bl_location.new", "$mta_bl_location" ) {
		warn "rename $mta_bl_location.new to $mta_bl_location failed: $!\n";
	}

}

&main;

