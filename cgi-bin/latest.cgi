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

sub write_page
{
	my ( $body ) = @_;

	print $q->header("text/html");
	print $q->start_html("Latest events for $listname.");

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
		print $q->h1("$listname latest events");
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

sub main
{
	my $time;
	my $page_body = "<table border=\"1\">\n";

	$CGI::DISABLE_UPLOADS = 1;
	$CGI::POST_MAX = 300;

	my %events = $Spamikaze::db->get_latest($Spamikaze::web_listlatest);

	my $foundinfo = ' ';
	foreach $time (reverse sort keys %events) {
		my ( $ip, $eventtype ) = split ' ', $events{$time}, 2;
		($time, my $dummy ) = split '\.', $time, 2;
		$page_body .= "<tr><td>" . CGI::escapeHTML($ip) . "</td>" .
				"<td>" . CGI::escapeHTML($time) . "</td>" .
				"<td>" . CGI::escapeHTML($eventtype) . "</td></tr>\n";
	}
	$page_body .= "</table>\n";

	&write_page ($page_body);
}

&main;
