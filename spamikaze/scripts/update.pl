#!/usr/bin/perl -w
#   update.pl
#   Read the TODO-database before your run this.
#   copyright 2003 Hans Wolters (h-wolters@nl.linux.org)
#   <insert GPL 2 or later in here>

use strict;

unshift (@INC, "/home/sys_scripts/");
unshift (@INC, "/opt/spamikaze/scripts");

use Spamikaze;
my $dbh = Spamikaze::DBConnect;

my $octa;
my $octb;
my $octc;
my $octd;
my @row;
my @newrow;

sub main(){
    
    my $sql = "insert ignore into ipnumbers 
                        (octa, octb, octc, octd, visible) 
                        select 
                            octa, octb, octc, octd, visible 
                        from 
                            spammers";
    my $sth = $dbh->prepare( $sql);
    $sth->execute();

    #get all the new ipnumbers and loop through them.
    $sql     = "SELECT octa, octb, octc, octd, id 
                            FROM ipnumbers";
    $sth     = $dbh->prepare( $sql);
    $sth->execute();

    my ($counter, $a, $b, $c, $d, $id);
    while( @row = $sth->fetchrow_array() )
    {
        $counter++;
        
        $a = $row[0];
        $b = $row[1];
        $c = $row[2];
        $d = $row[3];
        $id = $row[4];
        
        my $timestamp;
        my $sql = "SELECT spamtime FROM spammers WHERE
                        octa = ? AND
                        octb = ? AND
                        octc = ? AND
                        octd = ?";

        my $sth = $dbh->prepare( $sql );
        $sth->execute($a, $b, $c, $d);        
        $sth->bind_columns( undef, \$timestamp );
    
        while ( @newrow = $sth->fetchrow() )
        {
            insertnew($timestamp, $id);
        }
    }
    print $counter;
}    


sub insertnew(){

    my ($a, $b);
    $a =  $_[0];
    $b =  $_[1];

    my $sql = "INSERT IGNORE INTO ipentries
               (date_logged, id_ip) VALUES
               ( ?, ? )";

    my $sth = $dbh->prepare($sql);
    $sth->execute( $a, $b);

    print $a," - ", $b, "\n";
}

main();
