#!/usr/bin/perl -w

#   getblocks.pl
#   copyright 2003 Hans Wolters (h-wolters@nl.linux.org)
#   <insert GPL 2 or later in here>

use strict;
unshift (@INC,"/path/spamikaze/");


my $mta_bl_location     = "/var/www/spamikaze/postfix";
my $mta_bl_template     = "{IP}\t550 {IP} has been used by spammers, see http://spamikaze.is-a-geek.org/remove.php";
my $mta_bl_domain       = "{DOMAIN}\t550 Your domain has been blacklisted in Spamikaze due to excessive spamming and/or a non working abuse desk.";


my $mta_bl_template_wl  = "{EMAIL}";

sub main
{
    my $ip;
	my $email;

    my $dbh = Spamikaze::DBConnect;

    my $sql = "SELECT 
                DISTINCT CONCAT_WS('.',  octa, octb, octc, octd) AS ip
               FROM spammers WHERE visible = 1 ORDER BY octa, octb, octc, octd";
    my $sth = $dbh->prepare( $sql );
    $sth->execute();
    $sth->bind_columns( undef, \$ip);

    open(fileOUT, ">$mta_bl_location")
            || die("Can't open $mta_bl_location for writing: $!");
    flock(fileOUT, 2);
    seek(fileOUT, 0, 2);

    my $bldomain;
    foreach $bldomain (@BLACKLISTDOMAINS) {
        $_ = $mta_bl_domain;
        s/\{DOMAIN\}/$bldomain/;
        print fileOUT $_, "\n";
    }

    while( $sth->fetch() )
    {
        $_ = $mta_bl_template;
        s/\{IP\}/$ip/g;
        print fileOUT $_, "\n";
    }
    close(fileOUT);
    
    $sth->finish();
    $dbh->disconnect();

}

main;
