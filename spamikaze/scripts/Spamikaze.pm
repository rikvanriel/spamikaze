# Spamikaze.pm
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2004 Hans Spaans  <cj.spaans@nexit.nl>
# Copyright (C) 2004 Rik van Riel <riel@surriel.com>
#
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.nl.linux.org/


package Spamikaze;
use strict;
use warnings;
use DBI;
use Config::IniFiles;
use Env qw( HOME );
use Net::DNS;

my $dbuser;
my $dbpwd;
my $dbbase;
my $dbport;
my $dbtype;
my $dbhost;
my @MXBACKUP;
my $ignoreBOGON;
my $ignoreRFC1918;
our $ignorebounces;

# expire.pl
our $firsttime;
our $extratime;
our $maxspamperip;

# named.pl
our $dnsbl_domain;
our $dnsbl_zone_file;
our $dnsbl_url_base;
our $dnsbl_address;
our $dnsbl_ttl;
our $dnsbl_primary_ns;
our $dnsbl_secondary_nses;

# cgi scripts
our $web_header;
our $web_footer;
our $web_listname;
our $web_listingurl;
our $web_removalurl;

my @RFC1918Addresses =
  ( '10\.', '172\.1[6-9]\.', '172\.2[0-9]\.', '172\.3[0-2]\.', '192\.168\.' );

my $VERSION = "Spamikaze.pm Version .2\n";

BEGIN {

	my $configfile;

	if ( defined $ENV{HOME} and -f "$ENV{HOME}/.spamikaze/config" ) {

		$configfile = "$ENV{HOME}/.spamikaze/config";

	}
	elsif ( -f "/etc/spamikaze/config" ) {

		$configfile = "/etc/spamikaze/config";

	}
	else {

		print "ERROR: Missing ~/.spamikaze/config or /etc/spamikaze/config\n";
		exit 1;

	}

	my $cfg = new Config::IniFiles( -file => $configfile );

	$dbhost = $cfg->val( 'Database', 'Host' );
	$dbport = $cfg->val( 'Database', 'Port' );
	$dbtype = $cfg->val( 'Database', 'Type' );
	$dbuser = $cfg->val( 'Database', 'Username' );
	$dbpwd  = $cfg->val( 'Database', 'Password' );
	$dbbase = $cfg->val( 'Database', 'Name' );

	@MXBACKUP = split ( ' ', $cfg->val( 'Mail', 'BackupMX' ) );
	$ignoreRFC1918 = $cfg->val( 'Mail', 'IgnoreRFC1918' );
	$ignoreBOGON   = $cfg->val( 'Mail', 'IgnoreBOGON' );
	$ignorebounces = $cfg->val( 'Mail', 'IgnoreBounces' );

	$firsttime = $cfg->val ( 'Expire', 'FirstTime' );
	$extratime = $cfg->val ( 'Expire', 'ExtraTime' );
	$maxspamperip = $cfg->val ( 'Expire', 'MaxSpamPerIp' );
	# convert listing times from hours to seconds
	$firsttime *= 3600;
	$extratime *= 3600;

	$dnsbl_domain = $cfg->val ('DNSBL', 'Domain' );
	$dnsbl_zone_file = $cfg->val ('DNSBL', 'ZoneFile' );
	$dnsbl_url_base = $cfg->val ('DNSBL', 'UrlBase' );
	$dnsbl_address = $cfg->val ('DNSBL', 'Address' );
	$dnsbl_ttl = $cfg->val ('DNSBL', 'TTL' );
	$dnsbl_primary_ns = $cfg->val ('DNSBL', 'PrimaryNS' );
	$dnsbl_secondary_nses = $cfg->val ('DNSBL', 'SecondaryNSes' );

	$web_header = $cfg->val ('Web', 'Header' );
	$web_footer = $cfg->val ('Web', 'Footer' );
	$web_listname = $cfg->val ('Web', 'ListName' );
	$web_listingurl = $cfg->val ('Web', 'ListingURL' );
	$web_removalurl = $cfg->val ('Web', 'RemovalURL' );

	#
	# We need to check values !!!
	#

}

sub Version {
	return $VERSION;
}

sub DBConnect {
	my $dbh =
	  DBI->connect( "dbi:$dbtype:dbname=$dbbase;host=$dbhost;port=$dbport",
		"$dbuser", "$dbpwd", { RaiseError => 1 } )
	  || die "Database connection not made: $DBI::errstr";
	return $dbh;
}

sub GetDBType {

	return $dbtype;

}

sub MXBackup {
	my ($ip) = @_;
	my $mxhosts;

	#
	# We don't want localhost in our database
	#
	if ( $ip =~ /^127\./ ) {

		return 1;

	}

	#
	# Check if the spammer doesn't somehow managed to send from a
	# BOGON IP-address. The BOGON test includes RFC1918 test so
	# we can ignore RFC1918 if we test for BOGON.
	#
	if ( $ignoreBOGON eq 'true' or $ignoreBOGON == 1) {

		my $reversed_ip = $ip;
		$reversed_ip =~ s/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/$4.$3.$2.$1/;
		my $resolver = Net::DNS::Resolver->new;
		my $query    = $resolver->search("$reversed_ip.bogons.cymru.com.");

		if ($query) {

			foreach my $rr ( $query->answer ) {

				next unless $rr->type eq "A";
				return 1;

			}

		}
		else {

			if ( !$resolver->errorstring =~ /NXDOMAIN/ ) {

				warn "query failed: ", $resolver->errorstring, "\n";

			}

		}

	}
	elsif ( $ignoreRFC1918 eq 'true' or $ignoreRFC1918 == 1 ) {

		foreach my $ipaddress (@RFC1918Addresses) {

			if ( $ip =~ /^$ipaddress/ ) {

				return 1;

			}

		}

	}

	foreach $mxhosts (@MXBACKUP) {

		if ( $ip =~ /^$mxhosts/ ) {

			return 1;

		}

	}

	return 0;
}

1;
