#!/usr/bin/perl

# expire.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.nl.linux.org/
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin";
 
use Spamikaze;

our @DONTEXPIRE = ('127.0.0.2');

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
            $bonustime = $spamtime + $Spamikaze::firsttime;
            if ($bonustime <= time()){
                # print $total, "\t";
                $sthexpire->execute($octa, $octb, $octc, $octd);
                # print "$octa.$octb.$octc.$octd\n";
            }
        }
        elsif (($total < $Spamikaze::maxspamperip) && (mxdontexpire($ip) < 1))
        {
            $bonustime = $spamtime + ($Spamikaze::extratime * $total) +
			$Spamikaze::firsttime;
            if ($bonustime <= time()){
                # print $total, "\t";
                $sthexpire->execute($octa, $octb, $octc, $octd);
                # print "$octa.$octb.$octc.$octd\n";
            }
        }
        $sthexpire->finish();
        #sleep(1);
    }

    $sth->finish();
    $dbh->disconnect();
}

&main;

