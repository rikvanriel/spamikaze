#!/usr/bin/perl

# passivetrap.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2003 Rik van Riel <riel@surriel.com>
# Copyright (C) 2004 Hans Spaans  <cj.spaans@nexit.nl>
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

sub from_daemon
{
	my ( $mail ) = @_;
	my $ignorebounces = $Spamikaze::ignorebounces;

	unless ($ignorebounces eq 'true' or $ignorebounces == 1) {
		return 0;
	}

	if ($mail =~ /^From:?\s+\<\>/m) {
		return 1;
	}
	if ($mail =~ /^Return-Path:?\s+\<\>/mi) {
		return 1;
	}
	if ($mail =~ /^From:?\s+\<?MAILER.DAEMON/mi) {
		return 1;
	}
	if ($mail =~ /^From:\s+\<?postmaster/mi) {
		return 1;
	}

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


    my $sql     = "INSERT INTO ipentries (id_ip, date_logged) SELECT 
                    ipnumbers.id, UNIX_TIMESTAMP() FROM ipnumbers WHERE 
                    octa = ? and octb = ? and octc = ? and octd = ?";

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
        $sth->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3]);
        $sth->finish();

        my $rv = $sth->rows;

        if ($rv < 1){

            # the ipnumber isn't known, store it and get the id to
            # store it into the ipentries table.

            my $sqlipnumber = "INSERT INTO ipnumbers (octa, octb, octc, octd)
                               VALUES ( ?, ?, ?, ?)";
                               
            my $sthipnumber = $dbh->prepare( $sqlipnumber );
            $sthipnumber->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3]);
            $sthipnumber->finish();

            $sth = $dbh->prepare( $sql );
            $sth->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3]);
            $sth->finish();
        }

        # needed to set all earlier entries for this ipnumber to visible.
        my $sthupdate = $dbh->prepare( $visip );
        $sthupdate->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3]);
        $sthupdate->finish();
    }        
    $dbh->disconnect();

}

sub process_mail
{
	my ( $mail ) = @_;

	if (&from_daemon($mail)) {
		print "from daemon\n";
		return 0;
	}

	while ($mail =~ /Received:(.*?)(?=\n\w)/sg) {
		my $ip = parsereceived($1);
		if ($ip && !Spamikaze::MXBackup($ip) ) {
			storeip($ip);
			print "$ip\n";
			return 1;
		}
	}

	return 0;
}

sub maildir_daemon
{
	my ( $dir ) = @_;
	chdir $dir || die "$ARGV[-1] : couldn't chdir to $dir...\n";

	print "maildir mode still not implemented...\n";
	exit 1;
}

sub main
{
	# Take email from standard input if no arguments specified;
	# this way passivetrap stays compatible with the last version.

	if ($#ARGV == -1) {
		my $mail;
		read STDIN,$mail,15000 or die;

		&process_mail($mail);

		exit 0;
	}

	# If we're called with the -d argument, process data from a
	# maildir, which is basically our spool directory.

	if ($ARGV[0] eq '-d') {
		&maildir_daemon($ARGV[1]);
	}

	# This isn't a situation we recognise.  Bail out and
	# warn the user...

	print "usage: /path/to/passivetrap.pl [ -d directory ]\n";
	print "see also http://spamikaze.nl.linux.org/doc/\n";
	exit 1;
}

&main;
