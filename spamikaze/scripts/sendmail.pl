#!/usr/bin/perl -w

# sendmail.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.surriel.com/

use strict;
unshift (@INC, "/path/spamikaze/");
unshift (@INC, "/opt/spamikaze/scripts");

# $ticks            // Unix timestamp ticks.
# $mta_bl_location  // Path and file of your blocklist.
# $mta_bl_template  // Template string for the blocklist.

my $mta_bl_location     = "/tmp/test";
my $mta_bl_template     = "{IP}\tREJECT";
my $mta_bl_template_wl  = "{EMAIL}";

sub main
{
    my $ip;
    my $email;

    my $dbh = Spamikaze::DBConnect;

    my $sql = "SELECT DISTINCT CONCAT_WS('.',  octa, octb, octc, octd) AS ip
               FROM spammers WHERE visible = 1 ORDER BY octa, octb, octc, octd";

    my $sth = $dbh->prepare( $sql );

    $sth->execute($ticks);
    $sth->bind_columns( undef, \$ip);

    open(fileOUT, ">$mta_bl_location")
            or dienice("Can't open $mta_bl_location for writing: $!");
    flock(fileOUT, 2);
    seek(fileOUT, 0, 2);

    my $sql_whitelist = "SELECT email FROM whitelist";
    my $sth_whitelist = $dbh->prepare ($sql_whitelist);
    $sth_whitelist->execute();
    $sth_whitelist->bind_columns (undef, \$email);

    while ($sth_whitelist->fetch() )
    {
        $_ = $mta_bl_template_wl;
        s/\{EMAIL\}/$email/;
        print fileOUT $_, "\tOK\n";
    }
    $sth_whitelist->finish();


    while( $sth->fetch() )
    {
        $_ = $mta_bl_template;
        s/\{IP\}/$ip/;
        print fileOUT $_, "\n";
    }
    close(fileOUT);
    
    $sth->finish();
    $dbh->disconnect();

    exec ('/usr/bin/makemap hash /etc/mail/access < /etc/mail/access');
}

&main;

