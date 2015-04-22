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
package Spamikaze::PgSQL_3;
use strict;
use warnings;
use Env qw( HOME );
use News::NNTPClient;

my $news_header_notspam =
"From: spamikaze <$nntp_from>
Subject: spamtrap mail REASON
Newsgroups: $nntp_base.notspam

";

sub post_notspam
{
	unless ($nntp_enabled) return;

	my $nntp = new News::NNTPClient("$nntp_server");
	$nntp->mode_reader();

	my ( $spam, $reason ) = @_;
	my $header = $news_header_notspam;
	$header =~ s/REASON/$reason/m;

	$nntp->group("$nntp_base.notspam");

	my @message = split /\n/, $header . $spam;
	$nntp->post(@message);
	$nntp->quit();
}

my $news_header_spam =
"From: spamikaze <$nntp_from>
Subject: IPADDRESS spamtrap mail
Newsgroups: $nntp_base.OCTA

";

sub post_spam
{
	unless ($nntp_enabled) return;

	my $nntp = new News::NNTPClient("$nntp_server");
	$nntp->mode_reader();

	my ( $ip, $spam ) = @_;
	my $header = $news_header_spam;
	$ip =~ /^(\d{1,3})\./;
	my $octa = $1;
	$header =~ s/IPADDRESS/$ip/m;
	$header =~ s/OCTA/$octa/m;

	$nntp->group("surriel.spamtrap.$octa");

	my @message = split /\n/, $header . $spam;
	$nntp->post(@message);
	$nntp->quit();
}

sub new
{
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}

BEGIN {
	# do nothing
}

1;
