#!/usr/bin/perl -wT

# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.surriel.com/

use DBI;
use Socket;
use IP::Country::Fast;
my $reg = IP::Country::Fast->new();

require "/path/config.pl";
our $dbuser;
our $dbpwd;
our $dbbase;
our $dbport;
our $dbtype;
our $dbhost;

my $dbh;
my $country;

sub hostnames 
{
	my $id;
	my $dom;
	
	my $sql = "SELECT id, CONCAT_WS(\".\", octa, octb, octc, octd) 
				FROM spammers WHERE country =\'\'";
	my $sth = $dbh->prepare($sql) || die "Prepare failed: $DBI::errstr";

	$sth->execute();

	my $usql = "UPDATE spammers SET country = ? WHERE id = ?";
	my $usth = $dbh->prepare( $usql );

	while (($id, $dom) = $sth->fetchrow_array){

		$country = $reg->inet_atocc($dom)   ."\n";
		$usth->execute($country, $id);
	}
	
}

sub connect
{
        
    $dbh = DBI->connect( "dbi:$dbtype:dbname=$dbbase;host=$dbhost;port=$dbport",
                         "$dbuser", "$dbpwd", { RaiseError => 1 }) || die
                         "Database connection not made: $DBI::errstr";
}

sub disconnect
{
	$dbh->disconnect();
}

sub main
{
	&connect();
	&hostnames();
	&disconnect();

}

&main;
