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
use DBI;
use CGI qw(:standard :html4 -no_xhtml);
use CGI::Carp;

require "/path/config.pl";
our $dbuser;
our $dbpwd;
our $dbbase;
our $dbhost;
our $dbport;
our $dbtype;

# the IP address broken down into octets
my $octa;
my $octb;
my $octc;
my $octd;

my $q = new CGI;

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

sub invalid_page
{
	my ( $ip ) = @_;
	print $q->header("text/html"),
		$q->start_html("Invalid IP address specified"),
		$q->h1("Invalid IP address specified"),
		$q->p("Please <a href=\"/\">specify</a> a valid
			 IP address, $ip does not work for me."),
		$q->end_html;
}

sub example_page
{
	my ( $ip ) = @_;
	print $q->header("text/html"),
		$q->start_html("Example IP address specified"),
		$q->h1("Example IP address specified"),
		$q->p("That's one of the example IP addresses. Please
			<a href=\"/\">specify</a> the IP address
			of your mail server.");
		$q->end_html;
}

sub listing_page
{
	my ( $ip, $foundinfo ) = @_;
	my $body;
	if ($foundinfo eq ' ') {
		$body = "The host $ip has never been listed in PSBL";
	} else {
		$body = "Spam and removal history for $ip (times in UTC):\n" .
			"<p><table border=\"1\">\n" . "$foundinfo" .
			"</table>\n" .
			"<p>Check this IP address in: " .
			"<a href=\"http://openrbl.org/lookup?i=$ip\">Openrbl" .
			"</a> and " .
			"<a href=\"http://groups.google.com/groups?scoring=d&q=$ip+group:*abuse*\">Google groups</a>.\n" .
			"<FORM ACTION=\"/cgi-bin/remove.cgi\" METHOD=GET>\n" .
			"<INPUT TYPE=\"text\" NAME=\"ip\" VALUE=\"$ip\" " .
			"SIZE=\"20\">\n" . "<INPUT TYPE=\"submit\" " .
			"NAME=\"action\" VALUE=\"Remove IP\">\n" .
			"<p>Remember that\n" .
			"next time your mail server spams it will get\n" .
			"listed again, so please do not spam.";
	}
	print $q->header("text/html"),
		$q->start_html("Listing info for $ip"),
		$q->h1("PSBL listing info"),
		$q->p("$body"),
		$q->p("Back to the <a href=\"/\">main page</a>."),
		$q->end_html;
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
    $dbh = DBI->connect( "dbi:$dbtype:dbname=$dbbase;host=$dbhost;port=$dbport",
                         $dbuser, $dbpwd, { RaiseError => 1 }) || die
                         "Database connection not made\n";
                         
	#
	# first, get the times where we received spam
	#
	my $sql = "SELECT spamtime AS time FROM spammers WHERE
			octa = ? AND
			octb = ? AND
			octc = ? AND
			octd = ?";

	my $sth = $dbh->prepare($sql);
	$sth->execute($octa, $octb, $octc, $octd);
	$sth->bind_columns(undef, \$time);
	while ($sth->fetch()) {
		$found++;
		$iplog{$time} = 'received spam';
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

	$CGI::DISABLE_UPLOADS = 1;
	$CGI::POST_MAX = 300;

	my $ip = $q->param("ip") || '';

	# check if the IP address is valid
	if ($ip eq '' || &invalid($ip)) {
		&invalid_page($ip);
		exit;
	}

	if ($ip =~ /^127/) {
		&example_page;
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

	&listing_page($ip, $foundinfo);
}

&main;
