#!/usr/bin/perl -w

#   expire.pl
#   copyright 2003 Hans Wolters (h-wolters@nl.linux.org)
#   <insert GPL 2 or later in here>

use strict;
use warnings;

unshift (@INC, "/home/webapps/spamikaze/spamikaze/spamikaze/scripts");
unshift (@INC, "/opt/spamikaze/scripts");
require Spamikaze;

our @DONTEXPIRE;

my $firsttime = 15 * 24 * 60 * 60;  # 15 days ?
my $bonustime;
my $extratime = 30 * 24 * 60 * 60;
my $maxspamsperip = 10;

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
                    COUNT(ipentries.id) AS total,
                    octa, octb, octc, octd,
                    MAX(date_logged) AS spamtime
               FROM
                    ipentries,  ipnumbers
               WHERE
                    ipnumbers.id = ipentries.id_ip AND
                    visible = 1
               GROUP BY octa, octb, octc, octd
               ORDER BY date_logged ASC";

    my $sth = $dbh->prepare( $sql );
    $sth->execute();
    $sth->bind_columns( undef, \$total, \$octa, \$octb, \$octc, \$octd, \$spamtime);

    my $expiresql = "UPDATE ipnumbers SET visible = 0 WHERE 
                        octa = ? AND octb = ? AND octc = ? AND octd = ?";

    while( $sth->fetch() )
    {
        my $sthexpire = $dbh->prepare( $expiresql );
        $ip = "$octa.$octb.$octc.$octd";
        if ($total == 1 && mxdontexpire($ip) < 1) {
            $bonustime = $spamtime + $firsttime;
            if ($bonustime <= time()){
                print $total, "\t";
                $sthexpire->execute($octa, $octb, $octc, $octd);
                print "$octa.$octb.$octc.$octd\n";
            }
        }
        elsif (($total < $maxspamsperip) && (mxdontexpire($ip) < 1))
        {
            $bonustime = $spamtime + ($extratime * $total);
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
