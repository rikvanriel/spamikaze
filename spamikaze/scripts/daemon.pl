#!/usr/bin/perl

# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.nl.linux.org/

use warnings;
use strict;
use DBI;
use POSIX qw(setsid);

unshift (@INC, "/opt/spamikaze/spamikaze/spamikaze/scripts");
unshift (@INC, "/opt/spamikaze/scripts");
require Spamikaze;

my $ticks = 5 * 24 * 60 * 60;  # 15 days ?
my $bonustime;
my $extratime = 30 * 24 * 60 * 60;
my $maxspamsperip = 5;


# flush the buffer.
$| = 1;


# daemonize the program
&daemonize;

# our infinite loop
while(1) {

    my $ip;
    my $total;
    my $spamtime;
    my $octa;
    my $octb;
    my $octc;
    my $octd;
    my $hostname;


    my $dbh = Spamikaze::DBConnect();

    my $aantal = $dbh->do( "DELETE FROM ipentries WHERE date_logged < 
                            (UNIX_TIMESTAMP(NOW()) - 31536000) LIMIT 250" );

    if ($aantal > 0){  print "\n", $aantal;}

    my $sql = "SELECT
                COUNT(*) AS total,
                octa, octb, octc, octd,
                MAX(date_logged) AS spamtime
               FROM
                ipentries,  ipnumbers
               WHERE
                ipnumbers.id = ipentries.id_ip AND
                visible = 1
               GROUP BY octa, octb, octc, octd
               ORDER BY spamtime ASC LIMIT 500";

    
    my $sth = $dbh->prepare( $sql );
    $sth->execute();
    $sth->bind_columns( undef, \$total, \$octa, \$octb, \$octc, \$octd, \$spamtime);
    
    my $expiresql = "UPDATE ipnumbers SET visible = 0 WHERE
                        octa = ? AND octb = ? AND octc = ? AND octd = ?";

    while( $sth->fetch() ) {
        my $sthexpire = $dbh->prepare( $expiresql );
        
        $ip = "$octa.$octb.$octc.$octd";
        if ($total == 1 && mxdontexpire($ip) < 1) {
            $bonustime = $spamtime + $ticks;
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
    }
    $sth->finish();
    
    $dbh->disconnect();
    # wait for 60 seconds
    sleep(120);
}


sub mxdontexpire{

    my $ip = $_[0];
    my $mxdexpire;

    foreach $mxdexpire (@DONTEXPIRE) {
        if ($ip =~ /^$mxdexpire/) {
            return 1;
        }
    }
    return 0;
}


sub daemonize {

	print ".\n";
    defined(my $pid = fork)   or die "Can't fork: $!";
    exit if $pid;
    setsid                    or die "Can't start a new session: $!";
    umask 0;
}
