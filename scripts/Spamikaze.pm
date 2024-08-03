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
#     http://spamikaze.org/


package Spamikaze;
use strict;
use warnings;
use DBI;
use Config::IniFiles;
use Env qw( HOME );
use Net::DNS;
use Try::Tiny;

use Spamikaze::MySQL_2;
use Spamikaze::PgSQL_3;

my $dbuser;
my $dbpwd;
my $dbbase;
my $dbport;
my $dbtype;
my $dbhost;
my $dbmod;
our $db;

my @MXBACKUP;
my $ignoreRFC1918;
our $ignorebounces;
our @whitelist_zones;

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
our $web_listlatest;
our $web_siteurl;

# nntp archival
our $nntp;
our $nntp_enabled;
our $nntp_server;
our $nntp_groupbase;
our $nntp_from;

# pipe to a helper program
our $pipe;
our $pipe_program;

my @RFC1918Addresses =
  ( '10\.', '172\.1[6-9]\.', '172\.2[0-9]\.', '172\.3[0-2]\.', '192\.168\.' );

my $VERSION = "Spamikaze.pm Version .2\n";

sub ConfigLoad {

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
	try
	{
		ConfigRead($configfile);
	} catch {
		print "Failed to parse config file: $_";
		exit 1;
	}

}


sub ConfigRead {
	my ($configfile) = @_;
	my $cfg = new Config::IniFiles( -file => $configfile );

	$dbhost = $cfg->val( 'Database', 'Host' );
	$dbport = $cfg->val( 'Database', 'Port' );
	$dbtype = $cfg->val( 'Database', 'Type' );
	$dbuser = $cfg->val( 'Database', 'Username' );
	$dbpwd  = $cfg->val( 'Database', 'Password' );
	$dbbase = $cfg->val( 'Database', 'Name' );
	$dbmod  = $cfg->val( 'Database', 'Schema' );

	@MXBACKUP = split ( ' ', $cfg->val( 'Mail', 'BackupMX' ) );
	@whitelist_zones = split ( ' ', $cfg->val ( 'Mail', 'WhitelistZones' ) );
	$ignoreRFC1918 = $cfg->val( 'Mail', 'IgnoreRFC1918' );
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
	$web_listlatest = $cfg->val ('Web', 'ListLatest' );
	$web_siteurl = $cfg->val ('Web', 'SiteURL' );

	$nntp_enabled = $cfg->val ('NNTP', 'Enabled' );
	$nntp_server = $cfg->val ('NNTP', 'Server' );
	$nntp_groupbase = $cfg->val ('NNTP', 'Groupbase' );
	$nntp_from = $cfg->val ('NNTP', 'From' );

	$pipe_program = $cfg->val ('Pipe', 'Program' );

	#
	# We need to check values !!!
	#

}

sub Version {
	return $VERSION;
}

sub DBConnect {
	try {
		my $dbh = DBI->connect( "dbi:$dbtype:dbname=$dbbase;host=$dbhost;port=$dbport",
			"$dbuser", "$dbpwd", { RaiseError => 1, AutoCommit => 0 } );
		return $dbh;
	} catch {
		print "Failed to connect to the database: $_";
		exit 1;
	}
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

	if ( $ignoreRFC1918 eq 'true' or $ignoreRFC1918 == 1 ) {
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

sub SplitIP {
	my ( $ip ) = @_;
	my ($octa, $octb, $octc, $octd);

	if ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
		$octa = $1;
		$octb = $2;
		$octc = $3;
		$octd = $4;
	}
	return ($octa, $octb, $octc, $octd);
}

sub ValidIP {
	my ( $ip ) = @_;
	my ($octa, $octb, $octc, $octd) = SplitIP($ip);

	if (!defined($octa)) {
		# not of the form ddd.ddd.ddd.ddd
		return 0;
	}

	# all numbers are in range
	if ($octa >= 0 && $octa < 256 &&
			$octb >= 0 && $octb < 256 &&
			$octc >= 0 && $octc < 256 &&
			$octd >= 0 && $octd < 256) {
		return 1;
	}

	# invalid
	return 0;
}

sub whitelisted
{
	my ( $revip ) = @_;
	$revip =~ s/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/$4.$3.$2.$1/;
	my $res = new Net::DNS::Resolver;
	my $zone;

	foreach $zone (@Spamikaze::whitelist_zones) {
		try {
			my $query = $res->query($revip . "." . $zone, "A");
			if (defined $query) {
				return 1;
			}
		} catch {
			print "query to $zone failed: @_";
		}
	}
	return 0;
}

sub archive_spam
{
	my ($ip, $mail) = @_;

	if ($nntp_enabled) {
		try {
			$Spamikaze::nntp->post_spam($ip, $mail);
		} catch {
			print "archiving spam to NNTP failed: $_";
		}
	}

	if ($pipe_program) {
		try {
			$Spamikaze::pipe->pipe_mail($mail);
		} catch {
			print "archiving spam to pipe failed: $_";
		}
	}
}

sub archive_notspam
{
	my ($mail, $reason) = @_;
	if ($nntp_enabled) {
		try {
			$Spamikaze::nntp->post_notspam($mail, $reason);
		} catch {
			print "archiving non-spam to NNTP failed: $_";
		}
	}
}

BEGIN {
	&ConfigLoad();

	# On SIGHUP we reload the configuration
	$SIG{HUP} = \&ConfigLoad;

	my $tmp = "Spamikaze::" . $dbmod;
	$db = new $tmp;

	if ($nntp_enabled) {
		require Spamikaze::NNTP;
		$nntp = new Spamikaze::NNTP;
	}

	if ($pipe_program) {
		require Spamikaze::Pipe;
		$pipe = new Spamikaze::Pipe;
	}
}

1;
