#!/usr/bin/perl -wT
#
# Passivetrap.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2003 Rik van Riel <riel@surriel.com>
# Copyright 2004 Hans Spaans      <cj.spaans@nexit.nl>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.surriel.com/

use strict;

# unshift the path where passivetrap.pl and
# config.pl is located on the @INC.

unshift (@INC,"/home/webapps/spamikaze/spamikaze/spamikaze/scripts");
unshift (@INC, "/opt/spamikaze/scripts");

# Use the new pm, this will load the config.pl and
# set the variables for the db.
require Spamikaze;

sub from_daemon
{
	my ( $mail ) = @_;
	return 0;
}

sub received_to_ip_zmailer
{
	my ( $rcvd ) = @_;

	if ($rcvd =~ /[\[\(](?:IPv6.*?:)?(\d{1,3}(\.\d{1,3}){3})[\]\)]/g) {
		return $1;
	} elsif ($rcvd =~ /\[IPv6:((3ffe|2001|2002)(:[\da-f]{0,4}){3,7})/ig) {
		return $1;
	} else {
		return '';
	}
}

sub parsereceived
{
	my ( $rcvd ) = @_;

	my $ip = &received_to_ip_zmailer($rcvd);

	return $ip;
}

sub storeip
{
    my ( $ip )  = @_;
    my $error   = 0;
    my @iplist  = split /\./, $ip;
    my $ts      = time();
    my $sql     = "INSERT INTO ipnumbers (octa, octb, octc, octd, spamtime)
                    VALUES (?, ?, ? , ?, ?)";
    my $visip   = "UPDATE ipnumbers SET visible = 1 WHERE
                        octa = ? AND octb = ? AND octc = ? AND octd = ?";
                        
    # Set the dbh from the new pm.

    my $dbh         = Spamikaze::DBConnect();

    unless ($#iplist == 3) {
	$error = 1;
    }

    foreach my $num (@iplist) {
            $error = 1 if ($num < 0 or $num > 255 or $num =~ /[^\d]/);
    }

    if ($error < 1) {
        my $sth = $dbh->prepare( $sql );
        $sth->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3], $ts);
        $sth->finish();

        # needed to set all earlier entries for this ipnumber to visible.
        my $sthupdate = $dbh->prepare( $visip );
        $sthupdate->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3]);
        $sthupdate->finish();
    }        
    $dbh->disconnect();

}

sub main
{
	my $mail;

	read STDIN,$mail,15000 or die;

	if (&from_daemon($mail)) {
		print "from daemon\n";
		exit 0;
	}

	while ($mail =~ /Received:(.*?)(?=\n\w)/sg) {
		my $ip = parsereceived($1);
		if ($ip && !Spamikaze::MXBackup($ip) ) {
			storeip($ip);
			print "$ip\n";
			exit 0;
		}
	}

}

&main;
