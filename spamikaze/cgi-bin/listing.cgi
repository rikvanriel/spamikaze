#!/usr/bin/perl -T

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
use warnings;
use CGI qw(:standard :html4 -no_xhtml);

use lib "/opt/spamikaze/scripts";
use Spamikaze;

my $q = new CGI;

my $listname = 'Spamikaze example';
if (defined $Spamikaze::web_listname) {
	$listname = $Spamikaze::web_listname;
}

# URL to check whether the IP is listed in other DNSBLs
my $checkurl = "http://www.dnsstuff.com/tools/ip4r.ch?ip=";

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

	print $q->p("<h2>Query Results</h2>");
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
	my ( $ip, $foundinfo, $listed ) = @_;
	my $body;
	my $listedword = 'No';
	$listedword = 'Yes' if $listed;

	if ($foundinfo eq ' ') {
		$body = "The host $ip has never been listed in $listname. " .
			"Maybe you are looking at the wrong blocklist? " .
			"<p>You may want to check the <a href=" .
			$checkurl . $ip . ">other blocklists</a>";
	} else {
		$body = "Currently listed in $listname?  $listedword.\n<p>" .
			"Spam and removal history for $ip (times in UTC):\n" .
			"<p><table border=\"1\">\n" . "$foundinfo" .
			"</table>\n" .
			"<p>You may also want to check the <a href=" .
			$checkurl . $ip . ">other blocklists</a>" .
			"</a> and " .
			"<a href=\"http://groups.google.com/groups?scoring=d&q=$ip+group:*abuse*\">Google groups</a>.\n" .
			"<h2>Remove IP from $listname</h2>\n" .
			"<FORM ACTION=\"$Spamikaze::web_removalurl\" METHOD=GET>\n" .
			"<INPUT TYPE=\"text\" NAME=\"ip\" VALUE=\"$ip\" " .
			"SIZE=\"20\">\n" . "<INPUT TYPE=\"submit\" " .
			"NAME=\"action\" VALUE=\"Remove IP\">\n" .
			"</FORM>\n" .
			"<p>Remember that\n" .
			"next time your mail server spams it will get\n" .
			"listed again, so please do not spam.";
	}
	return $body;
}

sub main
{
	my $time;
	my $page_body;

	$CGI::DISABLE_UPLOADS = 1;
	$CGI::POST_MAX = 300;

	my $ip = $q->param("ip") || '';

	# check if the IP address is valid
	if ($ip eq '' || !Spamikaze::ValidIP($ip)) {
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
	my ($listed, %iplog) = $Spamikaze::db->get_listing_info($ip);

	my $foundinfo = ' ';
	foreach $time (sort keys %iplog) {
		my $printtime = gmtime($time);
		$foundinfo .= "<tr><td>$printtime</td>" .
				"<td>$iplog{$time}</td></tr>\n";
	}

	$page_body = &listing_page_body($ip, $foundinfo, $listed);
	&write_page ($ip, $page_body);
}

&main;

# stupid hack to prevent perl from spamming apache's error_log with
# 'listing.cgi: Name "Spamikaze::web_removalurl" used only once: possible typo'
my $nowarnings = $Spamikaze::web_removalurl;
