#!/usr/bin/perl -w
#
# named.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2003 Rik van Riel <riel@surriel.com>
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
use DBI;

require '/path/config.pl';
our $dbuser;
our $dbpwd;
our $dbbase;
our $dbport;
our $dbtype;
our $dbhost;


# $mta_bl_location  // Path and file of your blocklist.
# $mta_bl_template  // Template string for the blocklist.

#
# CONFIGURE THIS FOR YOUR SETUP
#
my $zone_header =
'$TTL 300
@	IN	SOA	spamikaze.yourdomain.tld.	root.spamikaze.yourdomain.tld.  ({TIMESTAMP} 600 300 86400 300)
	IN	NS	spamikaze.yourdomain.tld.
	IN	NS	your.other.nameserver.tld.
$ORIGIN spamikaze.yourdomain.tld.
2.0.0.127	IN	A	127.0.0.2
		IN	TXT	"spamikaze.yourdomain.tld test entry"
';

my $mta_bl_location	= "/tmp/psbl.zone";
my $mta_bl_a		= "{IP}\t300\tIN\tA\t127.0.0.2";
my $mta_bl_txt		= "\t\t\tIN\tTXT\t\"http://spamikaze.yourdomain.tld/listing.php?{IP}\"";

sub main
{
    my $ip;
	my $sql;
	my $sth;
	my @row;

    open(ZONEFILE, ">$mta_bl_location.new")
            or dienice("Can't open $mta_bl_location for writing: $!");
    flock(ZONEFILE, 2);
    seek(ZONEFILE, 0, 2);

    my $epoch = time();
    $zone_header =~ s/\{TIMESTAMP\}/$epoch/;
    print ZONEFILE $zone_header;
    
    my $dbh = DBI->connect( "dbi:$dbtype:dbname=$dbbase;host=$dbhost;port=$dbport",
                            "$dbuser", "$dbpwd", { RaiseError => 1 }) || die
                            "Database connection not made: $DBI::errstr";
                            
	if ( $dbtype eq 'mysql' ) {
        $sql = "SELECT DISTINCT CONCAT_WS('.',  octa, octb, octc, octd) AS ip
                FROM spammers WHERE visible = 1 ORDER BY ip";
    	$sth = $dbh->prepare( $sql );
    	$sth->execute($ticks);
    	$sth->bind_columns( undef, \$ip);

    	while( $sth->fetch() )
    	{
				my $txt_record = $mta_bl_txt;
				my $a_record = $mta_bl_a;
				my $revip = $ip;
				$revip =~ s/(\d+)\.(\d+)\.(\d+)\.(\d+)/$4.$3.$2.$1/;

				$a_record =~ s/\{IP\}/$revip/;
				$txt_record =~ s/\{IP\}/$ip/;
				print ZONEFILE $a_record, "\n";
				print ZONEFILE $txt_record, "\n";
    	}
    } elsif ( $dbtype eq 'Pg' ) {
        $sql = "SELECT DISTINCT octa, octb, octc, octd
                FROM spammers WHERE visible = true
                ORDER BY octa, octb, octc, octd";
    	$sth = $dbh->prepare( $sql );
    	$sth->execute($ticks);

    	while( @row = $sth->fetchrow_array() )
    	{
				my $ip = "$row[0].$row[1].$row[2].$row[3]";
				my $txt_record = $mta_bl_txt;
				my $a_record = $mta_bl_a;
				my $revip = $ip;
				$revip =~ s/(\d+)\.(\d+)\.(\d+)\.(\d+)/$4.$3.$2.$1/;

				$a_record =~ s/\{IP\}/$revip/;
				$txt_record =~ s/\{IP\}/$ip/;
				print ZONEFILE $a_record, "\n";
				print ZONEFILE $txt_record, "\n";
    	}
	}

    close ZONEFILE;
    
    $sth->finish();
    $dbh->disconnect();

		if ( ! rename "$mta_bl_location.new", "$mta_bl_location" ) {
			warn "rename $mta_bl_location.new to $mta_bl_location failed: $!\n";
		}

    system("rndc reload");
}

&main;

