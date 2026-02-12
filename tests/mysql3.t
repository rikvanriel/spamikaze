#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

# --- Smart DBI mock ---

package MockDB;

our @prepared;
our @executed;
our @do_calls;
our @committed;
our @disconnected;
our @fetch_queues;
our $do_return_value;

sub reset {
    @prepared = ();
    @executed = ();
    @do_calls = ();
    @committed = ();
    @disconnected = ();
    @fetch_queues = ();
    $do_return_value = 1;
}

sub new_dbh {
    return bless {}, 'MockDB::DBH';
}

package MockDB::DBH;

sub prepare {
    my ($self, $sql) = @_;
    push @MockDB::prepared, $sql;
    my $rows = shift @MockDB::fetch_queues || [];
    return bless { sql => $sql, rows => [@$rows], bound_refs => [] }, 'MockDB::STH';
}

sub do {
    my ($self, $sql, $attr, @params) = @_;
    push @MockDB::do_calls, { sql => $sql, params => [@params] };
    return $MockDB::do_return_value;
}

sub commit { push @MockDB::committed, 1 }
sub disconnect { push @MockDB::disconnected, 1 }
sub err { return 0 }

package MockDB::STH;

sub execute {
    my ($self, @params) = @_;
    push @MockDB::executed, [@params];
    return 1;
}

sub bind_columns {
    my $self = shift;
    $self->{bound_refs} = [grep { ref $_ } @_];
    return 1;
}

sub fetch {
    my $self = shift;
    return undef unless @{$self->{rows}};
    my $row = shift @{$self->{rows}};
    my $refs = $self->{bound_refs};
    for my $i (0 .. $#$refs) {
        ${$refs->[$i]} = $row->[$i] if $i <= $#$row;
    }
    return 1;
}

sub finish { return 1 }
sub rows { return 0 }

package main;

# --- Load the real MySQL_3 code (overrides TestHelper stubs) ---
{
    my $src_file = "$FindBin::Bin/../scripts/Spamikaze/MySQL_3.pm";
    open my $fh, '<', $src_file or die "Cannot read $src_file: $!";
    my $src = do { local $/; <$fh> };
    close $fh;
    $src =~ s/^use warnings;$/use warnings;\nno warnings 'redefine';/m;
    eval $src;
    die "Failed to load real MySQL_3: $@" if $@;
}

# --- Override Spamikaze::DBConnect to use our smart mock ---
{
    no warnings 'redefine';
    *Spamikaze::DBConnect = sub { return MockDB::new_dbh() };
}

my $db = Spamikaze::MySQL_3->new();

# ===== new() =====

isa_ok($db, 'Spamikaze::MySQL_3', 'new() returns blessed object');

# ===== storeip =====

{
    MockDB::reset();
    $Spamikaze::firsttime = 86400;
    $db->storeip('192.168.1.1', 'received spamtrap mail');

    # Should prepare blocklist INSERT then ipevents INSERT
    is(scalar @MockDB::prepared, 2, 'storeip: 2 prepares');

    like($MockDB::prepared[0], qr/INSERT INTO blocklist/i,
        'storeip: first prepare is blocklist INSERT');
    like($MockDB::prepared[0], qr/ON DUPLICATE KEY UPDATE/i,
        'storeip: uses ON DUPLICATE KEY UPDATE');
    like($MockDB::prepared[0], qr/DATE_ADD.*INTERVAL.*SECOND/si,
        'storeip: uses DATE_ADD with INTERVAL SECOND');

    # Execute params: ip, firsttime, firsttime (for the ON DUPLICATE KEY)
    is($MockDB::executed[0][0], '192.168.1.1', 'storeip: correct IP');
    is($MockDB::executed[0][1], 86400, 'storeip: firsttime for INSERT');
    is($MockDB::executed[0][2], 86400, 'storeip: firsttime for UPDATE');

    # store_ipevent
    like($MockDB::prepared[1], qr/INSERT INTO ipevents/i,
        'storeip: second prepare is ipevents INSERT');
    like($MockDB::prepared[1], qr/NOW\(\)/i,
        'storeip: store_ipevent uses NOW()');
    is($MockDB::executed[1][0], '192.168.1.1', 'storeip: ipevent IP');
    is($MockDB::executed[1][1], 'received spamtrap mail', 'storeip: ipevent type');

    is(scalar @MockDB::committed, 1, 'storeip: commits');
    is(scalar @MockDB::disconnected, 1, 'storeip: disconnects');
}

# ===== archivemail =====

{
    MockDB::reset();
    $db->archivemail('10.0.0.1', 1, 'spam email content');

    is(scalar @MockDB::prepared, 1, 'archivemail: 1 prepare');
    like($MockDB::prepared[0], qr/INSERT INTO emails/i,
        'archivemail: INSERT INTO emails');
    like($MockDB::prepared[0], qr/NOW\(\)/i,
        'archivemail: uses NOW()');
    is($MockDB::executed[0][0], '10.0.0.1', 'archivemail: correct IP');
    is($MockDB::executed[0][1], 1, 'archivemail: isspam flag');
    is($MockDB::executed[0][2], 'spam email content', 'archivemail: mail content');
    is(scalar @MockDB::committed, 1, 'archivemail: commits');
    is(scalar @MockDB::disconnected, 1, 'archivemail: disconnects');
}

# ===== expire =====

{
    MockDB::reset();
    $db->expire('127.0.0.2');

    is(scalar @MockDB::do_calls, 1, 'expire: one DO call');
    like($MockDB::do_calls[0]{sql}, qr/DELETE FROM blocklist/i,
        'expire: DELETE FROM blocklist');
    like($MockDB::do_calls[0]{sql}, qr/expires\s*<\s*NOW\(\)/i,
        'expire: uses NOW() comparison');
    is(scalar @MockDB::committed, 1, 'expire: commits');
    is(scalar @MockDB::disconnected, 1, 'expire: disconnects');
}

# expire with no args
{
    MockDB::reset();
    $db->expire();
    is(scalar @MockDB::do_calls, 1, 'expire: works with no args');
}

# ===== remove_from_db =====

# Successful removal
{
    MockDB::reset();
    $MockDB::do_return_value = 1;

    my $rows = $db->remove_from_db('198.51.100.42');

    is($rows, 1, 'remove_from_db: returns 1 row affected');
    like($MockDB::do_calls[0]{sql}, qr/DELETE FROM blocklist WHERE ip = \?/i,
        'remove_from_db: DELETE SQL with placeholder');
    is($MockDB::do_calls[0]{params}[0], '198.51.100.42',
        'remove_from_db: correct IP in DELETE');

    # store_ipevent called
    is(scalar @MockDB::prepared, 1, 'remove_from_db: store_ipevent prepared');
    like($MockDB::prepared[0], qr/INSERT INTO ipevents/i,
        'remove_from_db: store_ipevent SQL');
    is($MockDB::executed[0][0], '198.51.100.42', 'remove_from_db: ipevent IP');
    is($MockDB::executed[0][1], 'removed through website', 'remove_from_db: ipevent text');

    is(scalar @MockDB::committed, 1, 'remove_from_db: commits');
    is(scalar @MockDB::disconnected, 1, 'remove_from_db: disconnects');
}

# IP not found
{
    MockDB::reset();
    $MockDB::do_return_value = 0;

    my $rows = $db->remove_from_db('192.0.2.99');

    is($rows, 0, 'remove_from_db: returns 0 when not found');
    is(scalar @MockDB::prepared, 0, 'remove_from_db: no store_ipevent when not found');
    is(scalar @MockDB::committed, 1, 'remove_from_db: still commits');
    is(scalar @MockDB::disconnected, 1, 'remove_from_db: still disconnects');
}

# ===== get_listed_addresses =====

{
    MockDB::reset();
    @MockDB::fetch_queues = (
        [
            ['198.51.100.1'],
            ['203.0.113.50'],
            ['10.0.0.1'],
        ],
    );

    my @addrs = $db->get_listed_addresses();

    is(scalar @addrs, 3, 'get_listed_addresses: returns 3 addresses');
    like($MockDB::prepared[0], qr/SELECT ip FROM blocklist/i,
        'get_listed_addresses: correct SQL');
    is(scalar @MockDB::disconnected, 1, 'get_listed_addresses: disconnects');
}

# Empty blocklist
{
    MockDB::reset();
    @MockDB::fetch_queues = ([]);

    my @addrs = $db->get_listed_addresses();

    is(scalar @addrs, 0, 'get_listed_addresses: empty list');
}

# ===== store_ipevent =====

{
    MockDB::reset();
    my $dbh = MockDB::new_dbh();
    $db->store_ipevent($dbh, '198.51.100.42', 'received spamtrap mail');

    is(scalar @MockDB::prepared, 1, 'store_ipevent: 1 prepare');
    like($MockDB::prepared[0], qr/INSERT INTO ipevents/i,
        'store_ipevent: INSERT SQL');
    like($MockDB::prepared[0], qr/NOW\(\)/i,
        'store_ipevent: uses NOW()');
    like($MockDB::prepared[0], qr/SELECT id FROM eventtypes/i,
        'store_ipevent: subselect for eventid');
    is($MockDB::executed[0][0], '198.51.100.42', 'store_ipevent: correct IP');
    is($MockDB::executed[0][1], 'received spamtrap mail', 'store_ipevent: correct type');
}

# ===== get_listing_info =====

# IP with events and currently listed
{
    MockDB::reset();
    @MockDB::fetch_queues = (
        [
            ['2024-01-01 12:00:00', 'received spamtrap mail'],
            ['2024-01-02 06:00:00', 'removed through website'],
        ],
        [
            ['2024-01-03 00:00:00'],
        ],
    );

    my ($listed, %iplog) = $db->get_listing_info('198.51.100.42');

    is($listed, 1, 'get_listing_info: IP is listed');
    is(scalar keys %iplog, 2, 'get_listing_info: 2 events');
    is($iplog{'2024-01-01 12:00:00'}, 'received spamtrap mail',
        'get_listing_info: first event');
    is($iplog{'2024-01-02 06:00:00'}, 'removed through website',
        'get_listing_info: second event');
    is($MockDB::executed[0][0], '198.51.100.42',
        'get_listing_info: correct IP in ipevents query');
    is($MockDB::executed[1][0], '198.51.100.42',
        'get_listing_info: correct IP in blocklist query');
    is(scalar @MockDB::disconnected, 1, 'get_listing_info: disconnects');
}

# IP not listed, no events
{
    MockDB::reset();
    @MockDB::fetch_queues = ([], []);

    my ($listed, %iplog) = $db->get_listing_info('192.0.2.1');

    is($listed, 0, 'get_listing_info: not listed');
    is(scalar keys %iplog, 0, 'get_listing_info: no events');
}

# ===== get_latest =====

{
    MockDB::reset();
    @MockDB::fetch_queues = (
        [
            ['2024-01-03 12:00:00.123', '198.51.100.42', 'received spamtrap mail'],
            ['2024-01-03 12:01:00.456', '203.0.113.99', 'removed through website'],
        ],
    );

    my %events = $db->get_latest(10);

    is(scalar keys %events, 2, 'get_latest: 2 events');
    is($events{'2024-01-03 12:00:00.123'}, '198.51.100.42 received spamtrap mail',
        'get_latest: first event');
    is($events{'2024-01-03 12:01:00.456'}, '203.0.113.99 removed through website',
        'get_latest: second event');
    like($MockDB::prepared[0], qr/ORDER BY eventtime DESC LIMIT \?/i,
        'get_latest: ORDER BY DESC LIMIT');
    is($MockDB::executed[0][0], 10, 'get_latest: LIMIT param');
    is(scalar @MockDB::disconnected, 1, 'get_latest: disconnects');
}

# Empty events
{
    MockDB::reset();
    @MockDB::fetch_queues = ([]);

    my %events = $db->get_latest(5);

    is(scalar keys %events, 0, 'get_latest: empty');
}

# ===== Verify MySQL_3 has same API as PgSQL_3 =====
{
    my $pgsql = Spamikaze::PgSQL_3->new();
    my $mysql = Spamikaze::MySQL_3->new();

    for my $method (qw(get_listed_addresses store_ipevent storeip archivemail
                       expire remove_from_db get_listing_info get_latest new)) {
        ok($mysql->can($method), "MySQL_3 implements $method");
    }
}

done_testing();
