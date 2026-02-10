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

my $news_header_notspam_tmpl =
"From: spamikaze <FROM>
Subject: spamtrap mail REASON
Newsgroups: NNTPBASE.notspam

";
my $news_header_notspam;

sub post_notspam
{
	my ( $self, $spam, $reason ) = @_;

	unless ($Spamikaze::nntp_enabled) { return };

	my $nntp = new News::NNTPClient("$Spamikaze::nntp_server",
					Timeout=>10);
	$nntp->mode_reader();

	my $header = $news_header_notspam;
	$header =~ s/REASON/$reason/m;

	$nntp->group("$Spamikaze::nntp_groupbase.notspam");

	my @message = split /\n/, $header . $spam;
	$nntp->post(@message);
	$nntp->quit();
}

my $news_header_spam_tmpl =
"From: spamikaze <FROM>
Subject: IPADDRESS spamtrap mail
Newsgroups: NNTPBASE.OCTA,NNTPBASE

";
my $news_header_spam;

sub post_spam
{
	my ( $self, $ip, $spam ) = @_;

	unless ($Spamikaze::nntp_enabled) { return };

	my $nntp = new News::NNTPClient("$Spamikaze::nntp_server");
	$nntp->mode_reader();
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

	# Derive headers from templates so new() is safe to call more than once
	($news_header_spam = $news_header_spam_tmpl) =~ s/FROM/$Spamikaze::nntp_from/m;
	$news_header_spam =~ s/NNTPBASE/$Spamikaze::nntp_groupbase/mg;
	($news_header_notspam = $news_header_notspam_tmpl) =~ s/FROM/$Spamikaze::nntp_from/m;
	$news_header_notspam =~ s/NNTPBASE/$Spamikaze::nntp_groupbase/m;

	return $self;
}

BEGIN {
	# do nothing
}

1;
