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
		$q->p("Please <a href=\"/remove.html\">specify</a> a valid
			 IP address, $ip does not work for me."),
		$q->end_html;
}

sub example_page
{
	my ( $ip ) = @_;
	print $q->header("text/html"),
		$q->start_html("Example IP address specified"),
		$q->h1("Example IP address specified"),
		$q->p("That's one of the example IP addresses. Please check
			your bounce message and
			<a href=\"/remove.html\">specify</a> the IP address
			of your mail server.");
		$q->end_html;
}

sub success_page
{
	my ( $ip ) = @_;
	print $q->header("text/html"),
		$q->start_html("IP address removed from database"),
		$q->h1("IP address removed from database"),
		$q->p("IP address $ip has been removed from the database,
			but note that it will be added back in when the next
			spam is received."),
		$q->p("It should be gone from the DNSBL in a few minutes,
			when the zone file is regenerated. If you were sending
			an email to a site using this list, please try again
			in a few minutes.");
		$q->p("If you don't want to get listed again, don't send spam."),
		$q->end_html;
}

sub not_found_page
{
	my ( $ip ) = @_;
	print $q->header("text/html"),
		$q->start_html("IP address not found"),
		$q->h1("IP address not found"),
		$q->p("Sorry, but I could not find $ip in the database."),
		$q->p("Maybe you made a <a href=\"/remove.html\">typo</a>, or
			maybe it was already removed from the database but
			the DNSBL has not been updated yet."),
		$q->p("If you are sure that $ip is the right address, it
			should be gone from the DNSBL in a few minutes.
			Please try again later.");
		$q->end_html;
}

sub remove_from_db
{
    my $dbh;
    
	# DBI connect params.
    $dbh = DBI->connect( "dbi:$dbtype:dbname=$dbbase;host=$dbhost;port=$dbport",
                         $dbuser, $dbpwd, { RaiseError => 1 }) || die
                         "Database connection not made\n";
                         
	my $sql = "UPDATE ipnumbers SET visible = 0 WHERE
			octa = ? AND
			octb = ? AND
			octc = ? AND
			octd = ? AND
			visible = 1";

	my $sth = $dbh->prepare($sql);

    my $rows_affected = 0;

	# store octs in placeholders, a little more secure.
	$rows_affected = $sth->execute($octa, $octb, $octc, $octd);
	$sth->finish();
    
    
    if ($rows_affected > 0)
    {
        my $sqlipr = "INSERT INTO ipremove 
                      (removetime, octa, octb, octc, octd) 
                      VALUES ( ?, ?, ?, ?, ?)";
        my $epoch = time();
        my $sthi = $dbh->prepare($sqlipr);
        $sthi->execute($epoch, $octa, $octb, $octc, $octd);
        $dbh->disconnect();
    }
    else
    {
        $dbh->disconnect();
    }
    return $rows_affected;    
}

sub main
{
	$CGI::DISABLE_UPLOADS = 1;
	$CGI::POST_MAX = 300;

	my $ip = $q->param("ip") || '';

	# check if the IP address is valid
	if ($ip eq '' || &invalid($ip)) {
		&invalid_page($ip);
	} 

	if ($ip =~ /^127/) {
		&example_page;
	}

	# valid IP address, try to remove
	elsif (&remove_from_db($ip) > 0){ 
		&success_page($ip);
	}

	# ok so the removal failed
	else {
		&not_found_page($ip);
	}
}

main;
