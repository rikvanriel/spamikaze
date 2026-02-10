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
#     http://spamikaze.org/
use strict;
use warnings;
use FindBin;
use Net::DNS;
use lib "$FindBin::Bin";
use POSIX "sys_wait_h";

use Sys::Syslog qw(:standard :macros);
use Spamikaze;

sub from_daemon
{
	my ( $mail ) = @_;
	my $ignorebounces = $Spamikaze::ignorebounces;

	unless (defined($ignorebounces) and ($ignorebounces eq 'true' or $ignorebounces == 1)) {
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
	if ($mail =~ /^From:?[\s\w\+\-\'\"]+\<?postmaster/mi) {
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
	if ($mail =~ /^X-AskVersion:.*paganini.net/m) {
		return 1;
	}
	if ($mail =~ /^using a program called Qurb which automatically/m) {
		return 1;
	}
	if ($mail =~ /^Your (mail to|message|email).*could not be delivered/m) {
		return 1;
	}
	if ($mail =~ /Message from InterScan Messaging Security Suite/m) {
		return 1;
	}
	if ($mail =~ /^ScanMail for Microsoft Exchange has detected/m) {
		return 1;
	}
	if ($mail =~ /^X-ChoiceMail-Registration-Request/m) {
		return 1;
	}
	if ($mail =~ /^Subject:.*automat(ic|ed) reply/mi) {
		return 1;
	}
	if ($mail =~ /out of (the )?office/mi) {
		return 1;
	}
	if ($mail =~ /From?\s+(eSafe|MAILsweeper|av-gateway)@/m) {
		return 1;
	}
	if ($mail =~ /this is an automated (response|reply)/mi) {
		return 1;
	}
	if ($mail =~ /^Precedence:\s+(bulk|junk)/mi) {
		return 1;
	}
	if ($mail =~ /^Hi! This is the ezmlm program./m) {
		return 1;
	}
	if ($mail =~ /^Auto-Submitted:\sauto-replied/mi) {
		return 1;
	}
	if ($mail =~ /^From:?\s+Symantec_Anti-?(Spam|Virus)\@/mi) {
		return 1;
	}
	if ($mail =~ /^The following addresses had permanent fatal errors/mi) {
		return 1;
	}
	if ($mail =~ /VIRUS_WARNING|WORM_FOUND/m) {
		return 1;
	}
	if ($mail =~ /(Automatische Antwort|Abwesenheitsnotiz:)/m) {
		return 1;
	}
	if ($mail =~ /^Delivered-To:\s+Autoresponder/mi) {
		return 1;
	}
	if ($mail =~ /^Error 24: This message does not conform to our/mi) {
		return 1;
	}
	if ($mail =~ /Diagnostic-Code: X-Notes/mi) {
		return 1;
	}
	if ($mail =~ /The mail message.*contains a virus/mi) {
		return 1;
	}
	if ($mail =~ /^Your recent message to.*invalid/mi) {
		return 1;
	}
	if ($mail =~ /AppleID\@apple.com/mi) {
		return 1;
	}
	if ($mail =~ /TO BECOME A MEMBER OF THE GROUP/mi) {
		return 1;
	}
	if ($mail =~ /^This receipt verifies that the message has been/mi) {
		return 1;
	}
	if ($mail =~ /Message-ID:X-YMail-OSG/mi) {
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

sub process_mail
{
	my ( $mail ) = @_;

	my $from = '';
	if ($mail =~ /^From:\s*(.*)$/mi) {
		$from = $1;
	}

	if (&from_daemon($mail)) {
		syslog(LOG_INFO, "from=%s ip=none: not stored, mail is from daemon", $from);
		Spamikaze::archive_notspam($mail, 'from daemon');
		return 0;
	}

	my $last_ip = 'none';
	my $reason = 'no IP found in Received headers';

	while ($mail =~ /Received:(.*?)(?=\n\w)/sg) {
		my $ip = parsereceived($1);
		next unless $ip;
		$last_ip = $ip;

		my $skip = Spamikaze::MXBackup($ip);
		if ($skip) {
			$reason = $skip;
			next;
		}

		$skip = Spamikaze::whitelisted($ip);
		if ($skip) {
			$reason = $skip;
			next;
		}

		syslog(LOG_INFO, "from=%s ip=%s: stored in blocklist", $from, $ip);
		$Spamikaze::db->storeip($ip, 'received spamtrap mail');
		Spamikaze::archive_spam($ip, $mail);
		return 1;
	}

	syslog(LOG_INFO, "from=%s ip=%s: not stored, %s", $from, $last_ip, $reason);
	Spamikaze::archive_notspam($mail, 'no valid IP address');
	return 0;
}

sub process_dir
{
	my ( $dir ) = @_;
	my $count = 0;
	my $file;

	opendir(INCOMING, "$dir") || die "$ARGV[-1] : can't opendir $dir\n";
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
			# a sibling worker processed the spam before us
			next;
		}

		&process_mail($email);
		$count++;

		# too busy? ensure more helpers get forked
		if ($count > 50) {
			return $count;
		}
	}
	return $count;
}

sub maildir_daemon
{
	my ( $dir ) = @_;
	my $numworkers = 0;
	my $targetworkers = 1;

	chdir($dir) || die "$ARGV[-1] : couldn't chdir to $dir\n";

	while (1) {
		#
		# parent process
		# start a worker process if desired
		#
		while ($numworkers < $targetworkers) {
			my $pid = fork;
			if (!defined $pid) {
				# fork failed, back off
				last;
			} elsif ($pid) {
				#
				# parent process
				#
				$numworkers++;
			} else {
				#
				# child process
				# return the number of emails processed
				#
				my $count = &process_dir($dir);
				exit $count;
			}
		}

		#
		# parent process
		# wait for worker processes to exit
		# evaluate how many worker processes are required
		#
		my $child;
		while (($child = waitpid(-1, WNOHANG)) > 0) {
			# $? is the raw wait status; >> 8 extracts the exit code
			my $nummails = $? >> 8;
			$numworkers--;

			# not keeping up? start more workers
			# not much work? reduce the number of workers
			if ($nummails > 50 && $targetworkers < 250) {
				$targetworkers++;
			} elsif ($nummails < 40 && $targetworkers > 1) {
				$targetworkers /= 2;
			}
		}

		if ($child == 0) {
			# wait a little for a child to exit
			sleep 1;
		} elsif ($child == -1 && $targetworkers == 1) {
			# idle? sleep a little longer
			sleep 3;
		}
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
	print "see also http://spamikaze.org/\n";
	exit 1;
}

&main;
