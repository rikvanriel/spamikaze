#!/usr/bin/perl -wT

# removal from the DNSBL
#
# Copyright (C) 2003 Rik van Riel <riel@surriel.com>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.surriel.com/

use strict;
use CGI qw(:standard :html4 -no_xhtml);
use CGI::Carp;

unshift (@INC, "/opt/spamikaze/scripts");
require Spamikaze;

# the IP address broken down into octets
my $octa;
my $octb;
my $octc;
my $octd;

my $q = new CGI;

my $listname = 'Spamikaze example';
if (defined $Spamikaze::web_listname) {
	$listname = $Spamikaze::web_listname;
}

sub invalid
{
	my ( $ip ) = @_;

	# decompose into octets
	if ($ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
		$octa = $1;
		$octb = $2;
		$octc = $3;
		$octd = $4;
	} else {
		# not of the form ddd.ddd.ddd.ddd
		return 1;
	}

	# all numbers are in range
	if ($octa >= 0 && $octa < 256 &&
			$octb >= 0 && $octb < 256 &&
			$octc >= 0 && $octc < 256 &&
			$octd >= 0 && $octd < 256) {
		return 0;
	}

	# invalid
	return 1;
}

sub write_page
{
	my ( $ip, $body ) = @_;

	print $q->header("text/html");
	print $q->start_html("$listname listing info for $ip");

	# print the page header, if defined
	if (defined $Spamikaze::web_header and
			 open HEADER, "<$Spamikaze::web_header") {
		my $header = '';
		while (<HEADER>) {
			$header .= $_;
		}
		print $q->p($header);
		close HEADER;
	} else {
		print $q->h1("$listname listing info");
	}

	print $q->p($body);

	# print the footer, if defined
	if (defined $Spamikaze::web_footer and
			 open FOOTER, "<$Spamikaze::web_footer") {
		my $footer = '';
		while (<FOOTER>) {
			$footer .= $_;
		}
		print $q->p($footer);
		close FOOTER;
	}

	print $q->end_html;
}

sub invalid_page_body
{
	my ( $ip ) = @_;
	my $body = "Please <a href=\"/\">specify</a> a valid
			 IP address, $ip does not work for me.";
	return $body;
}

sub example_page_body
{
	my ( $ip ) = @_;
	my $body = "That's one of the example IP addresses. Please
		<a href=\"/\">specify</a> the IP address of your mail server.";
	return $body;
}

sub listing_page_body
{
	my ( $ip, $foundinfo ) = @_;
	my $body;
	if ($foundinfo eq ' ') {
		$body = "The host $ip has never been listed in $listname";
	} else {
		$body = "Spam and removal history for $ip (times in UTC):\n" .
			"<p><table border=\"1\">\n" . "$foundinfo" .
			"</table>\n" .
			"<p>Check this IP address in: " .
			"<a href=\"http://openrbl.org/lookup?i=$ip\">Openrbl" .
			"</a> and " .
			"<a href=\"http://groups.google.com/groups?scoring=d&q=$ip+group:*abuse*\">Google groups</a>.\n" .
			"<FORM ACTION=\"$Spamikaze::web_removalurl\" METHOD=GET>\n" .
			"<INPUT TYPE=\"text\" NAME=\"ip\" VALUE=\"$ip\" " .
			"SIZE=\"20\">\n" . "<INPUT TYPE=\"submit\" " .
			"NAME=\"action\" VALUE=\"Remove IP\">\n" .
			"<p>Remember that\n" .
			"next time your mail server spams it will get\n" .
			"listed again, so please do not spam.";
	}
	return $body;
}

sub grabinfo
{
	my %iplog = ();
	my $time;
	my $found;
	my $dbh;
    
	# DBI connect params.
	#
	# DBI->connect( $data_source, $username, $password, \%attr );
	$dbh = Spamikaze::DBConnect();
                         
	#
	# first, get the times where we received spamtrap mail
	#
	my $sql = "SELECT 
                    date_logged AS time FROM ipentries, ipnumbers
               WHERE
            id_ip = ipnumbers.id AND
			octa = ? AND
			octb = ? AND
			octc = ? AND
			octd = ?";

	my $sth = $dbh->prepare($sql);
	$sth->execute($octa, $octb, $octc, $octd);
	$sth->bind_columns(undef, \$time);
	while ($sth->fetch()) {
		$found++;
		$iplog{$time} = 'spamtrap hit';
	}
	$sth->finish();

	#
	# then, get the removal times
	#
	$sql = "SELECT removetime AS time FROM ipremove WHERE
			octa = ? AND
			octb = ? AND
			octc = ? AND
			octd = ?";

	$sth = $dbh->prepare($sql);
	$sth->execute($octa, $octb, $octc, $octd);
	$sth->bind_columns(undef, \$time);
	while ($sth->fetch()) {
		$found++;
		$iplog{$time} = 'removed from list';
	}
	$sth->finish();

	$dbh->disconnect();

	return %iplog;
}

sub main
{
	my $time;
	my $page_body;

	$CGI::DISABLE_UPLOADS = 1;
	$CGI::POST_MAX = 300;

	my $ip = $q->param("ip") || '';

	# check if the IP address is valid
	if ($ip eq '' || &invalid($ip)) {
		$page_body = &invalid_page_body($ip);
		&write_page ($ip, $page_body);
		exit;
	}

	if ($ip =~ /^127/) {
		$page_body = &example_page_body;
		&write_page ($ip, $page_body);
		exit;
	}

	# valid IP address, get info from database
	my %iplog = &grabinfo($ip);

	my $foundinfo = ' ';
	foreach $time (sort keys %iplog) {
		my $printtime = gmtime($time);
		$foundinfo .= "<tr><td>$printtime</td>" .
				"<td>$iplog{$time}</td></tr>\n";
	}

	$page_body = &listing_page_body($ip, $foundinfo);
	&write_page ($ip, $page_body);
}

&main;
