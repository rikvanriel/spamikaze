# Spamikaze::MySQL_3.pm
#
# Copyright (C) 2005 Rik van Riel <riel@surriel.com>
#
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.org/

#
# Database abstractions for the 3rd MySQL schema for Spamikaze
# The database layout can be found in: schemas/spamikaze-mysql-3.sql
#

package Spamikaze::MySQL_3;
use strict;
use warnings;
use DBI;
use Env qw( HOME );

# Get all the IP addresses that are listed in the DNSBL.
sub get_listed_addresses {
	my @addresses = ();
	my $dbh;
	my $sql;
	my $sth;
	my $ip;

	$dbh = Spamikaze::DBConnect();

	$sql = "SELECT ip FROM blocklist";
	$sth = $dbh->prepare($sql);
	$sth->execute();
	$sth->bind_columns( undef, \$ip );

	while ( $sth->fetch() ) {
		unshift(@addresses, $ip);
	}
	$sth->finish();
	$dbh->disconnect();

	return @addresses;
}

# This function gets called from ->storeip and ->remove_from_db,
# with a database connection already made!
sub store_ipevent
{
    my ( $self, $dbh, $ip, $type )  = @_;
    my $sql = "INSERT INTO ipevents (ip, eventtime, eventid)
               VALUES (?, NOW(), (SELECT id FROM eventtypes WHERE eventtext = ?))";

    my $sth = $dbh->prepare($sql);
    $sth->execute($ip, $type);
    $sth->finish;
}

sub storeip
{
    my ( $self, $ip, $type )  = @_;
    my $firsttime = $Spamikaze::firsttime;

    my $dbh = Spamikaze::DBConnect();

    eval {
        my $sql = "INSERT INTO blocklist (ip, expires)
                   VALUES (?, DATE_ADD(NOW(), INTERVAL ? SECOND))
                   ON DUPLICATE KEY UPDATE expires = DATE_ADD(NOW(), INTERVAL ? SECOND)";
        my $sth = $dbh->prepare($sql);
        $sth->execute($ip, $firsttime, $firsttime);
        $sth->finish;
        $self->store_ipevent($dbh, $ip, $type);
        $dbh->commit();
    };
    my $err = $@;
    $dbh->disconnect();
    die $err if $err;
}

sub archivemail
{
    my ($self, $ip, $isspam, $mail) = @_;

    my $dbh = Spamikaze::DBConnect();

    eval {
        my $sql = "INSERT INTO emails (ip, `time`, spam, email) VALUES (?, NOW(), ?, ?)";
        my $sth = $dbh->prepare($sql);
        $sth->execute($ip, $isspam, $mail);
        $sth->finish;
        $dbh->commit();
    };
    my $err = $@;
    $dbh->disconnect();
    die $err if $err;
}

sub expire
{
    my ($self, @dontexpire) = @_;

    my $dbh = Spamikaze::DBConnect();
    $dbh->do("DELETE FROM blocklist WHERE expires < NOW()");
    $dbh->commit();
    $dbh->disconnect();
}

sub remove_from_db
{
	my ($self, $ip) = @_;
	my $rows_affected;
	my $dbh;

	$dbh = Spamikaze::DBConnect();
	$rows_affected = $dbh->do("DELETE FROM blocklist WHERE ip = ?", undef, $ip);
	if ($rows_affected > 0) {
		$self->store_ipevent($dbh, $ip, "removed through website");
	}
	$dbh->commit();
	$dbh->disconnect();

	return $rows_affected;
}

sub get_listing_info
{
	my ($self, $ip) = @_;
	my %iplog = ();
	my $eventtext;
	my $listed = 0;
	my $found = 0;
	my $time;
	my $dbh;
	my $sth;
	my $sql;

	$dbh = Spamikaze::DBConnect();

	#
	# First, get all the events for this IP address
	#
	$sql = "SELECT eventtime, eventtext FROM ipevents, eventtypes WHERE
			ipevents.ip = ? AND ipevents.eventid = eventtypes.id";

	$sth = $dbh->prepare($sql);
	$sth->execute($ip);
	$sth->bind_columns(undef, \$time, \$eventtext);
	while ($sth->fetch()) {
		$found++;
		$iplog{$time} = $eventtext;
	}
	$sth->finish();

	#
	# is the IP currently listed?
	#
	$sql = "SELECT expires FROM blocklist WHERE ip = ?";
	$sth = $dbh->prepare($sql);
	$sth->execute($ip);
	$sth->bind_columns(\$time);
	while ($sth->fetch()) {
		$listed = 1;
	}
	$sth->finish();

	$dbh->disconnect();

	return ($listed, %iplog);
}

sub get_latest
{
	my ($self, $num) = @_;
	my %events;
	my $ip;
	my $time;
	my $eventtext;
	my $dbh;
	my $sth;
	my $sql;

	$dbh = Spamikaze::DBConnect();

	$sql = "SELECT eventtime, ip, eventtext FROM ipevents, eventtypes " .
		"WHERE eventtypes.id = ipevents.eventid " .
		"ORDER BY eventtime DESC LIMIT ?";

	$sth = $dbh->prepare($sql);
	$sth->execute($num);
	$sth->bind_columns(undef, \$time, \$ip, \$eventtext);
	while ($sth->fetch()) {
		$events{$time} = "$ip $eventtext";
	}
	$sth->finish();

	$dbh->disconnect();

	return %events;
}

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}

BEGIN {
	# nothing
}

1;
