#!/usr/bin/perl -w

#   expire.pl
#   copyright 2003 Hans Wolters (h-wolters@nl.linux.org)
#   <insert GPL 2 or later in here>

use strict;
use DBI;

unshift (@INC, "/home/webapps/spamikaze/spamikaze/spamikaze/scripts");
unshift (@INC, "/opt/spamikaze/scripts");
require Spamikaze;

our @DONTEXPIRE;
my $bonustime;

sub mxdontexpire
{
        
    my $ip = $_[0];
    my $mxdexpire;

    foreach $mxdexpire (@DONTEXPIRE) 
    {
        if ($ip =~ /^$mxdexpire/) {
            return 1;
        }
    }
    return 0;
}

sub main
{
    my $ip;
    my $total;
    my $spamtime;
    my $octa;
    my $octb;
    my $octc;
    my $octd;
    my $hostname;

    my $dbh = Spamikaze::DBConnect();

    my $sql = "SELECT 
                    COUNT(spammers.id) as total,
                    octa, octb, octc, octd,
                    spamtime, fqdn.hostname
               FROM 
                    spammers, fqdn
               WHERE 
                    fqdn_id = fqdn.id AND
                    visible = 1 AND 
                    fqdn.hostname != \"\" 
               GROUP BY octa, octb, octc, octd 
               ORDER BY octa, octb, octc, octd";

    my $sth = $dbh->prepare( $sql );
    $sth->execute();
    $sth->bind_columns( undef, \$total, \$octa, \$octb, \$octc, \$octd, \$spamtime, \$hostname);

    my $expiresql = "UPDATE spammers SET visible = 0 WHERE 
                        octa = ? AND octb = ? AND octc = ? AND octd = ?";

    while( $sth->fetch() )
    {
        my $sthexpire = $dbh->prepare( $expiresql );
        $ip = "$octa.$octb.$octc.$octd";
        if ($total == 1 && mxdontexpire($ip) < 1) {
            $bonustime = $spamtime + $Spamikaze::{firsttime};
            if ($bonustime <= time()){
                print $total, "\t";
                $sthexpire->execute($octa, $octb, $octc, $octd);
                print "$octa.$octb.$octc.$octd\n";
            }
        }
        elsif (($total < $Spamikaze::{maxspamsperip}) && (mxdontexpire($ip) < 1))
        {
            $bonustime = $spamtime + ($Spamikaze::{extratime} * $total);
            if ($bonustime <= time()){
                print $total, "\t";
                $sthexpire->execute($octa, $octb, $octc, $octd);
                print "$octa.$octb.$octc.$octd\n";
            }
        }
        $sthexpire->finish();
        #sleep(1);
    }

    $sth->finish();
    $dbh->disconnect();
}

&main;
