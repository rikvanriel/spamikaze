#!/usr/bin/perl -wT

# removal from the DNSBL
#
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

require "/home/sys_scripts/config.pl";
our $dbuser;
our $dbpwd;
our $dbbase;

my $dbh;
my $country;
my $iaddr;
my $c_id;

sub hostnames 
{
	my $id;
	my $dom;
    my $e_id = 720;
	
	my $sql = "SELECT id, CONCAT_WS(\".\", octa, octb, octc, octd), hostname
    				FROM spammers WHERE fqdn_id = 0";
	my $sth = $dbh->prepare($sql) || die "Prepare failed: $DBI::errstr";
	$sth->execute();

	while (($id, $dom, $hostname) = $sth->fetchrow_array){

        $iaddr = inet_aton($dom);
        $hostname = gethostbyaddr($iaddr, AF_INET);
        
        if (!$hostname){
            my $emptysql = "UPDATE spammers SET fqdn_id = 720 WHERE id = ?";
            my $emptysth = $dbh->prepare($emptysql) || die "Prepare failed: $DBI::errstr";
            $emptysth->execute($id);
        }
        
		$country = $reg->inet_atocc($dom)   ."\n";
        if ($country ne "")
        {
            my $csql = "SELECT id FROM country WHERE country = ?";
            my $csth = $dbh->prepare( $csql );
            $c_id = $csth->execute($country);
            $csth->bind_columns( undef, \$cid);
            while ($csth->fetch() ){
                my $usql = "UPDATE spammers SET c_id = ?, hostname = LCASE(?) WHERE id = ?";
                my $usth = $dbh->prepare( $usql );
                $usth->execute($cid, $hostname, $id);
                if ($hostname){
                    print $hostname,"\n";
                }
            }
        }

	}
	
}

sub connect
{
    $dbh = DBI->connect( 'dbi:mysql:' . $dbbase,
       $dbuser, $dbpwd, { RaiseError => 1 }) || die
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
