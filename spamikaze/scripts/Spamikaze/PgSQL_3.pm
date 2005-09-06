# Spamikaze::PgSQL_3.pm
#
# Copyright (C) 2005 Rik van Riel <riel@surriel.com>
#
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.nl.linux.org/

#
# Database abstractions for the 3rd Postgres schema for Spamikaze
# The database layout can be found in: schemas/spamikaze-pgsql-3.sql
#

package Spamikaze::PgSQL_3;
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

# This function gets called from ->storeip and ->removefromdb,
# with a database connection already made!
sub store_ipevent
{
    my ( $self, $dbh, $ip, $type )  = @_;
    my $sql = "INSERT INTO ipevents VALUES (?, CURRENT_TIMESTAMP, (SELECT
				id FROM eventtypes WHERE eventtext = ?))";

    # print "$sql\n";
    my $sth = $dbh->prepare($sql);
    $sth->execute($ip, $type);
    $sth->finish;
}

sub storeip
{
    my ( $self, $ip, $type )  = @_;
    my $expires = "$Spamikaze::firsttime seconds";
    my $dbh;
    my $sth;
    my $sql;
    my $rv;

    $dbh = Spamikaze::DBConnect();

    eval { # catch failures
        $sql = "INSERT INTO blocklist VALUES (?, CURRENT_TIMESTAMP + ?::interval)";
        # print "$sql\n";
        $sth = $dbh->prepare($sql);
        $rv = $sth->execute($ip, $expires);
    };
    
    if (!$rv) { # the INSERT failed because the IP is already in blocklist
	$dbh->commit(); # the INSERT failing aborts the whole transaction
	$sql = "UPDATE blocklist SET expires = CURRENT_TIMESTAMP + ?::interval WHERE ip = ?";
	# print "$sql\n";
	$sth = $dbh->prepare($sql);
	$sth->execute($expires, $ip);
    }
    $self->store_ipevent($dbh, $ip, $type);
    $dbh->commit();
    $dbh->disconnect();
}

sub expire
{
    my ($self, @dontexpire) = @_;

    my $dbh = Spamikaze::DBConnect();
    # print "DELETE FROM blocklist WHERE expires < CURRENT_TIMESTAMP\n";
    $dbh->do("DELETE FROM blocklist WHERE expires < CURRENT_TIMESTAMP");
    $dbh->commit();
    $dbh->disconnect();
}

sub remove_from_db($)
{
	my ($self, $ip) = @_;
	my $rows_affected;
	my $dbh;

	# DBI connect params.
	$dbh = Spamikaze::DBConnect();
        $rows_affected = $dbh->do("DELETE FROM blocklist WHERE ip = \'$ip\'");
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
