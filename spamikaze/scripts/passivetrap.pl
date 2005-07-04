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
use Net::DNS;
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
	if ($mail =~ /^From:\s+\<?(majordomo|listar|ecartis|mailman)/mi) {
		return 1;
	}
	if ($mail =~ /^From:\s+\<?(\w+-owner|owner-|\w+-request)/mi) {
		return 1;
	}
	if ($mail =~ /^From:?\s+\<?(bounce-.*@.*(lyris|list|mail))/mi) {
		return 1;
	}
	if ($mail =~ /^Your (mail to|message|email).*could not be delivered/m) {
		return 1;
	}

	return 0;
}

sub received_to_ip
{
	my ( $rcvd ) = @_;

	if ($rcvd =~ /[\[\(](?:IPv6.*?:)?(\d{1,3}(\.\d{1,3}){3})[\]\)]/g) {
		return $1;
	} elsif ($rcvd =~ /\[IPv6:((3ffe|2001|2002)(:[\da-f]{0,4}){3,7})/ig) {
		return $1;
	} elsif ($rcvd =~ /(\d{1,3}(\.\d{1,3}){3})/g) {
		return $1;
	} else {
		return '';
	}
}

sub parsereceived
{
	my ( $rcvd ) = @_;

	my $ip = &received_to_ip($rcvd);

	return $ip;
}

sub whitelisted
{
	my ( $revip ) = @_;
	$revip =~ s/(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})/$4.$3.$2.$1/;
	my $res = new Net::DNS::Resolver;
	my $zone;

	foreach $zone (@Spamikaze::whitelist_zones) {
		my $query = $res->query($revip . "." . $zone, "A");
		if (defined $query) {
			return 1;
		}
	}
	return 0;
}

sub process_mail
{
	my ( $mail ) = @_;

	if (&from_daemon($mail)) {
		return 0;
	}

	while ($mail =~ /Received:(.*?)(?=\n\w)/sg) {
		my $ip = parsereceived($1);
		if ($ip && !Spamikaze::MXBackup($ip) && !whitelisted($ip)) {
			$Spamikaze::db->storeip($ip);
			return 1;
		}
	}

	return 0;
}

sub process_dir
{
	my ( $dir ) = @_;
	my $count = 0;
	my $file;

	opendir INCOMING, "$dir" || die "$ARGV[-1] : can't opendir $dir\n";
	my @files = readdir INCOMING;
	closedir INCOMING;
	
	foreach $file (@files) {
		my $mailfile = "$dir/$file";
		my $email;

		# skip directories and other non-files
		unless (-f $mailfile) {
			next;
		}

		# skip temporary files the MTA isn't ready with yet
		if ($file =~ /^te?mp/ or $file =~ /^\./) {
			next;
		}

		open MAIL, "<$mailfile" or next;
		read MAIL, $email, 10000;
		close MAIL;

		if (!unlink $mailfile) {
			die "cannot unlink $mailfile: $!\n";
		}

		&process_mail($email);
		$count++;
	}
	return $count;
}

sub maildir_daemon
{
	my ( $dir ) = @_;

	chdir $dir || die "$ARGV[-1] : couldn't chdir to $dir\n";

	while (1) {
		my $count = &process_dir($dir);
		# print "processed $count messages\n";
		sleep 3;
	}
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
