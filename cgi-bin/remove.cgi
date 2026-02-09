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
my $listname = $Spamikaze::web_listname;

sub write_page
{
	my ( $ip, $body ) = @_;

	print $q->header("text/html");
	print $q->start_html("$listname removal of $ip");

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
		print $q->h1("$listname removal");
	}

	print $q->p("<h2>Removal Results</h2>");
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

sub invalid_page
{
	my ( $ip ) = @_;

	my $safe_ip = CGI::escapeHTML($ip // '');
	my $body = "Invalid IP address specified ($safe_ip);\n";
	$body .= "please specify a valid IP address.\n";

	return $body;
}

sub success_page
{
	my ( $ip ) = @_;
	my $safe_ip = CGI::escapeHTML($ip);
	my $body = "IP address $safe_ip has been removed from the database. ";
	$body .= "It should be gone from the DNSBL list $listname ";
	$body .= "after the next zone file rebuild, in a couple of minutes.\n";
	$body .= "<p>Note that it will be added back in the next time it ";
	$body .= "sends email to one of our spam traps, so please minimise ";
	$body .= "any abusive behaviour by $safe_ip.\n";

	return $body;
}

sub not_found_page
{
	my ( $ip ) = @_;
	my $safe_ip = CGI::escapeHTML($ip);
	my $body = "Sorry, but $safe_ip does not appear to be on the DNSBL ";
	$body .= "$listname (any more?).  <p>Maybe you made a typo, or the ";
	$body .= "IP address was already removed from the database?\n";
	$body .= "If you are sure that $safe_ip is the right address, it should ";
	$body .= "be gone from the DNSBL after the next zone file rebuild, ";
	$body .= "which should happen in a few minutes.\n";

	return $body;
}

sub main
{
	$CGI::DISABLE_UPLOADS = 1;
	$CGI::POST_MAX = 300;
	my $body;

	my $ip = $q->param("ip");

	# check if the IP address is valid
	if (!defined($ip) || !Spamikaze::ValidIP($ip) || $ip =~ /^127/) {
		$body = &invalid_page($ip);
	} 

	# valid IP address, try to remove
	elsif ($Spamikaze::db->remove_from_db($ip) > 0) { 
		$body = &success_page($ip);
	}

	# ok so the removal failed
	else {
		$body = &not_found_page($ip);
	}

	# 
	# Write the web page
	#
	&write_page ($ip, $body);
	exit 0;
}

main;

# get rid of perl warning that would flood apache logs
my $nowarn = $Spamikaze::web_listname;
