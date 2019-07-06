#!/usr/bin/perl

# spamikazemonitor.pl
#
# Copyright (C) 2019 Rik van Riel <riel@surriel.com>
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
use Time::Local;

use Spamikaze;

sub getunixtime {
	my ( $timestring ) = @_;

	my ($date, $time) = split (/ /, $timestring);
	my ($year, $mon, $mday) = split ('-', $date);
	my ($hour, $min, $sec) = split (':', $time);

	return timelocal($sec, $min, $hour, $mday, $mon-1, $year);
}

# throw an error if there are no recent spamtrap hits
sub checkrecentevents {
	my %events = $Spamikaze::db->get_latest($Spamikaze::web_listlatest);
	my $hourago = time() - 3600;
	my $time;

	foreach $time (keys %events) {
		my ( $ip, $eventtype ) = split ' ', $events{$time}, 2;
		if ($eventtype =~ /received spamtrap mail/) {
			# we received a spamtrap mail in the past hour
			my $unixtime = &getunixtime($time);
			if ($unixtime > $hourago) {
				return;
			}
		}
	}
	print $Spamikaze::web_listname, ": no recent spamtrap mail received!\n";
}

sub checknntp {
	unless ($Spamikaze::nntp_enabled) {
		return;
	}

	my $nntp = new News::NNTPClient("$Spamikaze::nntp_server", 119,
					Timeout=>10);
	$nntp->mode_reader();
	$nntp->quit();
}

sub main {
	&checkrecentevents;
	&checknntp;
}

&main;
