#   Spamikaze.pm
#   copyright 2003 Hans Wolters (h-wolters@nl.linux.org)
#   copyright 2004 Hans Spaans  (cj.spaans@nexit.nl)
#   <insert GPL 2 or later in here>

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
my @RFC1918Addresses = ( '10\.', '172.1[6-9]\.', '172.2[0-9]\.', '172.3[0-2]', '192.168.' );


my $VERSION = "Spamikaze.pm Version .1\n";

BEGIN
{

	my $configfile;

	if ( -f "$ENV{HOME}/.spamikaze/config" ) {

		$configfile	= "$ENV{HOME}/.spamikaze/config";

	} elsif ( -f "/etc/spamikaze/config" ) {

		$configfile	= "/etc/spamikaze/config";

	} else {

		print "ERROR: Missing ~/.spamikaze/config or /etc/spamikaze/config\n";
		exit 1;

	}
	
	my $cfg		= new Config::IniFiles( -file => $configfile );

	$dbhost 	= $cfg->val( 'Database', 'Node' );
	$dbport 	= $cfg->val( 'Database', 'Port' );
	$dbtype 	= $cfg->val( 'Database', 'Type' );
	$dbuser 	= $cfg->val( 'Database', 'Username' );
	$dbpwd		= $cfg->val( 'Database', 'Password' );
	$dbbase 	= $cfg->val( 'Database', 'Name' );
	@MXBACKUP	= split( ' ', $cfg->val( 'Mail', 'BackupMX' ) );
	$ignoreRFC1918	= $cfg->val( 'Mail', 'IgnoreRFC1918' );
	$ignoreBOGON	= $cfg->val( 'Mail', 'IgnoreBOGON' );
	#
	# We need to check values !!!
	#

}

sub Version 
{ 
    return $VERSION; 
}

sub DBConnect
{
    my $dbh = DBI->connect("dbi:$dbtype:dbname=$dbbase;host=$dbhost;port=$dbport",
                        "$dbuser", "$dbpwd", { RaiseError => 1 }) || die
                        "Database connection not made: $DBI::errstr";
    return $dbh;
}

sub MXBackup
{
	my ( $ip ) = @_;
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
	if ( $ignoreBOGON eq 'true' ) {

		my $reversed_ip = $ip;
		$reversed_ip =~ s/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/$4.$3.$2.$1/;
		my $resolver = Net::DNS::Resolver->new;
		my $query    = $resolver->search("$reversed_ip.bogons.cymru.com");
	
		if ($query) {

			foreach my $rr ($query->answer) {

				next unless $rr->type eq "A";
				return 1;

			}

		} else {

			if ( ! $resolver->errorstring =~ /NXDOMAIN/ ) {

				warn "query failed: ", $resolver->errorstring, "\n";
			
			}

		}

	} elsif ( $ignoreRFC1918 eq 'true' ) {

		foreach my $ipaddress (@RFC1918Addresses) {

			if ($ip =~ /^$ipaddress/) {

				return 1;

			}
			
		}

	}

	
	foreach $mxhosts (@MXBACKUP) {

		if ($ip =~ /^$mxhosts/) {

			return 1;

		}

	}

	return 0;
}

1;
