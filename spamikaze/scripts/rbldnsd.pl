#!/usr/bin/perl 

# dnsrbld.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2003 Rik van Riel <riel@surriel.com>
# Copyright (C) 2004 Hans Spaans  <cj.spaans@nexit.nl>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#        http://spamikaze.nl.linux.org/
#
# generates a rbldnsd zone file with IP addresses from the spamikaze database
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";

use Spamikaze;

my $zone_header = '';

sub usage {
	print "rbldnsd.pl <file>\n";
	exit 1;
}

sub build_header {
	my $dnsbl_url_base = $Spamikaze::dnsbl_url_base;
	my $primary_ns = $Spamikaze::dnsbl_primary_ns;
	my $secondary_nses = $Spamikaze::dnsbl_secondary_nses;
	my $ttl = $Spamikaze::dnsbl_ttl;

	$zone_header .= ":127.0.0.2:$dnsbl_url_base\$\n";
	$zone_header .= "\$SOA 3000 $primary_ns root.$primary_ns 0 $ttl $ttl 86400 $ttl\n";
	$zone_header .= "\$NS 86400 $primary_ns $secondary_nses\n";
	$zone_header .= "127.0.0.2\n";
}

sub main {
	my $ip;
	my $sql;
	my $sth;
	my @row;

	if ($#ARGV != 0) {
		&usage;
	}

	my $outfile = $ARGV[0];

	open( TEXTFILE, ">$outfile.new" )
	  or dienice("Can't open $outfile for writing: $!");
	flock( TEXTFILE, 2 );
	seek( TEXTFILE, 0, 2 );

	my $dbh = Spamikaze::DBConnect();

	&build_header();
	print TEXTFILE $zone_header;

	if ( Spamikaze::GetDBType() eq 'mysql' ) {
		$sql = "SELECT CONCAT_WS('.', octa, octb, octc, octd) AS ip
                FROM ipnumbers WHERE visible = 1 ORDER BY ip";
		$sth = $dbh->prepare($sql);
		$sth->execute();
		$sth->bind_columns( undef, \$ip );

		while ( $sth->fetch() ) {
			print TEXTFILE $ip, "\n";
		}
	}
	elsif ( Spamikaze::GetDBType() eq 'Pg' ) {
		$sql = "SELECT DISTINCT octa, octb, octc, octd
                FROM ipnumbers WHERE visible = '1'
                ORDER BY octa, octb, octc, octd";
		$sth = $dbh->prepare($sql);
		$sth->execute();

		while ( @row = $sth->fetchrow_array() ) {
			$ip         = "$row[0].$row[1].$row[2].$row[3]";

			print TEXTFILE $ip,   "\n";
		}
	}
	close TEXTFILE;

	$sth->finish();

	if ( !rename "$outfile.new", "$outfile" ) {
		warn "rename $outfile.new to $outfile failed: $!\n";
	}

}

&main;
