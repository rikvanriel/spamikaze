# Spamikaze::NEWS.pm
#
# Copyright (C) 2015 Rik van Riel <riel@surriel.com>
#
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.org/

#
# Methods to archive spam on an NNTP server.
#
package Spamikaze::NNTP;
use strict;
use warnings;
use Env qw( HOME );
use News::NNTPClient;

my $news_header_notspam =
"From: spamikaze <FROM>
Subject: spamtrap mail REASON
Newsgroups: NNTPBASE.notspam

";

sub post_notspam
{
	unless ($Spamikaze::nntp_enabled) { return };

	my $nntp = new News::NNTPClient("$Spamikaze::nntp_server");
	$nntp->mode_reader();

	my ( $self, $spam, $reason ) = @_;
	my $header = $news_header_notspam;
	$header =~ s/REASON/$reason/m;

	$nntp->group("$Spamikaze::nntp_groupbase.notspam");

	my @message = split /\n/, $header . $spam;
	$nntp->post(@message);
	$nntp->quit();
}

my $news_header_spam =
"From: spamikaze <FROM>
Subject: IPADDRESS spamtrap mail
Newsgroups: NNTPBASE.OCTA,NNTPBASE

";

sub post_spam
{
	unless ($Spamikaze::nntp_enabled) { return };

	my $nntp = new News::NNTPClient("$Spamikaze::nntp_server");
	$nntp->mode_reader();

	my ( $self, $ip, $spam ) = @_;
	my $header = $news_header_spam;
	$ip =~ /^(\d{1,3})\./;
	my $octa = $1;
	$header =~ s/IPADDRESS/$ip/m;
	$header =~ s/OCTA/$octa/m;

	$nntp->group("$Spamikaze::nntp_groupbase.$octa");

	my @message = split /\n/, $header . $spam;
	$nntp->post(@message);
	$nntp->quit();
}

sub new
{
	my $class = shift;
	my $self = {};
	bless $self, $class;

	# set up the nntp headers
	$news_header_spam =~ s/FROM/$Spamikaze::nntp_from/m;
	$news_header_spam =~ s/NNTPBASE/$Spamikaze::nntp_groupbase/mg;
	$news_header_notspam =~ s/FROM/$Spamikaze::nntp_from/m;
	$news_header_notspam =~ s/NNTPBASE/$Spamikaze::nntp_groupbase/m;

	return $self;
}

BEGIN {
	# do nothing
}

1;
