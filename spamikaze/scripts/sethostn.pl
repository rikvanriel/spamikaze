#!/usr/bin/perl -wT

# Copyright (C) 2003 Hans Wolters, <h-wolters@nl.linux.org>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.surriel.com/

use DBI;
use Socket;

require "/home/sys_scripts/config.pl";
our $dbuser;
our $dbpwd;
our $dbbase;

my $dbh;
my $country;
my $hostname;
my $iaddr;
my $c_id;

sub hostnames 
{
	my $id;
	my $dom;

    # select all the unknow hostnames.
    
	my $sql = "SELECT id, hostname	FROM spammers WHERE 
                hostname != \"\" AND fqdn_id = 0";
	my $sth = $dbh->prepare($sql) || die "Prepare failed: $DBI::errstr";
	$sth->execute();

    my $hsql = "SELECT id, LCASE(LOCATE(hostname, ?))
                FROM fqdn WHERE (LOCATE(hostname, ?)) > 0";

	while (($id, $hostname) = $sth->fetchrow_array){

        my $fqdn_hostname;
        my $fqdn_id;
        
        my $fqdn_id_sql = "SELECT id, LCASE(LOCATE(hostname, ?))       
                            FROM fqdn WHERE (LOCATE(hostname, ?)) > 0";
        my $fqdn_id_sth = $dbh->prepare($fqdn_id_sql) || die "Prepare failed: $DBI::errstr";
        $fqdn_id_sth->execute($hostname, $hostname);

        while (($fqdn_id, $fqdn_hostname) = $fqdn_id_sth->fetchrow_array){
                
            if ($fqdn_id != 720){
                print $id,"\t",$fqdn_id,"\n";
                my $husql = "UPDATE spammers SET fqdn_id = ?, hostname = \"\" WHERE id = ?";
                my $husth = $dbh->prepare( $husql );
                $husth->execute($fqdn_id, $id) || die "Execute failed: $DBI::errstr";
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
