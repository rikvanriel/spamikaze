#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

# --- Smart DBI mock with SQL/param tracking and configurable fetch ---

package MockDB;

our @prepared;         # SQL strings passed to prepare()
our @executed;         # arrayrefs of params passed to execute()
our @do_calls;         # hashrefs { sql => ..., params => [...] }
our @committed;
our @disconnected;
our @fetch_queues;     # queue of row-sets: each entry is an arrayref of row arrayrefs
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

# --- Load the real PgSQL_3 code (overrides TestHelper stubs) ---
{
    my $src_file = "$FindBin::Bin/../scripts/Spamikaze/PgSQL_3.pm";
    open my $fh, '<', $src_file or die "Cannot read $src_file: $!";
    my $src = do { local $/; <$fh> };
    close $fh;
    # Suppress redefine warnings since we're intentionally overriding stubs
    $src =~ s/^use warnings;$/use warnings;\nno warnings 'redefine';/m;
    eval $src;
    die "Failed to load real PgSQL_3: $@" if $@;
}

# --- Override Spamikaze::DBConnect to use our smart mock ---
{
    no warnings 'redefine';
    *Spamikaze::DBConnect = sub { return MockDB::new_dbh() };
}

my $db = Spamikaze::PgSQL_3->new();

# ===== new() =====

isa_ok($db, 'Spamikaze::PgSQL_3', 'new() returns blessed object');

# ===== storeip =====

{
    MockDB::reset();
    $db->storeip('192.168.1.1', 'received spamtrap mail');

    # Should prepare blocklist INSERT then ipevents INSERT
    is(scalar @MockDB::prepared, 2, 'storeip: 2 prepare calls');
    like($MockDB::prepared[0], qr/INSERT INTO blocklist/, 'storeip: first prepare is blocklist INSERT');
    like($MockDB::prepared[1], qr/INSERT INTO ipevents/, 'storeip: second prepare is ipevents INSERT');

    # Check execute params
    is($MockDB::executed[0][0], '192.168.1.1', 'storeip: blocklist execute has IP');
    like($MockDB::executed[0][1], qr/\d+ seconds/, 'storeip: blocklist execute has expiry interval');
    is($MockDB::executed[1][0], '192.168.1.1', 'storeip: ipevents execute has IP');
    is($MockDB::executed[1][1], 'received spamtrap mail', 'storeip: ipevents execute has event type');

    # Commits and disconnects
    is(scalar @MockDB::committed, 1, 'storeip: commits once');
    is(scalar @MockDB::disconnected, 1, 'storeip: disconnects once');
}

# --- storeip uses firsttime from config ---
{
    MockDB::reset();
    $db->storeip('10.0.0.1', 'test');
    # firsttime = 24 hours * 3600 = 86400 seconds
    is($MockDB::executed[0][1], '86400 seconds', 'storeip: expiry is firsttime in seconds');
}

# ===== store_ipevent =====

{
    MockDB::reset();
    my $dbh = MockDB::new_dbh();
    $db->store_ipevent($dbh, '10.0.0.1', 'test event');

    is(scalar @MockDB::prepared, 1, 'store_ipevent: 1 prepare');
    like($MockDB::prepared[0], qr/INSERT INTO ipevents/, 'store_ipevent: prepares ipevents INSERT');
    is($MockDB::executed[0][0], '10.0.0.1', 'store_ipevent: execute has IP');
    is($MockDB::executed[0][1], 'test event', 'store_ipevent: execute has event type');
}

# ===== archivemail =====

{
    MockDB::reset();
    $db->archivemail('192.168.1.1', 1, 'Subject: spam');

    is(scalar @MockDB::prepared, 1, 'archivemail: 1 prepare');
    like($MockDB::prepared[0], qr/INSERT INTO emails/, 'archivemail: prepares emails INSERT');
    is($MockDB::executed[0][0], '192.168.1.1', 'archivemail: execute has IP');
    is($MockDB::executed[0][1], 1, 'archivemail: execute has isspam flag');
    is($MockDB::executed[0][2], 'Subject: spam', 'archivemail: execute has mail content');
    is(scalar @MockDB::committed, 1, 'archivemail: commits once');
    is(scalar @MockDB::disconnected, 1, 'archivemail: disconnects once');
}

# ===== expire =====

{
    MockDB::reset();
    $db->expire();

    is(scalar @MockDB::do_calls, 1, 'expire: 1 do call');
    like($MockDB::do_calls[0]{sql}, qr/DELETE FROM blocklist WHERE expires/, 'expire: DELETE SQL');
    is(scalar @MockDB::committed, 1, 'expire: commits once');
    is(scalar @MockDB::disconnected, 1, 'expire: disconnects once');
}

# ===== remove_from_db =====

# --- with rows affected > 0: calls store_ipevent ---
{
    MockDB::reset();
    $MockDB::do_return_value = 1;
    my $rows = $db->remove_from_db('10.20.30.40');

    is($rows, 1, 'remove_from_db: returns rows affected');
    is(scalar @MockDB::do_calls, 1, 'remove_from_db: 1 do call');
    like($MockDB::do_calls[0]{sql}, qr/DELETE FROM blocklist WHERE ip/, 'remove_from_db: DELETE SQL');
    is($MockDB::do_calls[0]{params}[0], '10.20.30.40', 'remove_from_db: DELETE has correct IP');

    # store_ipevent called because rows > 0
    is(scalar @MockDB::prepared, 1, 'remove_from_db (rows>0): store_ipevent prepare called');
    like($MockDB::prepared[0], qr/INSERT INTO ipevents/, 'remove_from_db: store_ipevent INSERT');
    is($MockDB::executed[0][0], '10.20.30.40', 'remove_from_db: store_ipevent has IP');
    is($MockDB::executed[0][1], 'removed through website', 'remove_from_db: store_ipevent has event type');

    is(scalar @MockDB::committed, 1, 'remove_from_db: commits');
    is(scalar @MockDB::disconnected, 1, 'remove_from_db: disconnects');
}

# --- with rows affected = 0: skips store_ipevent ---
{
    MockDB::reset();
    $MockDB::do_return_value = 0;
    my $rows = $db->remove_from_db('99.99.99.99');

    is($rows, 0, 'remove_from_db (no rows): returns 0');
    is(scalar @MockDB::prepared, 0, 'remove_from_db (no rows): no store_ipevent');
    is(scalar @MockDB::committed, 1, 'remove_from_db (no rows): still commits');
    is(scalar @MockDB::disconnected, 1, 'remove_from_db (no rows): still disconnects');
}

# ===== get_listed_addresses =====

# --- empty blocklist ---
{
    MockDB::reset();
    @MockDB::fetch_queues = ( [] );  # no rows
    my @addrs = $db->get_listed_addresses();

    is(scalar @addrs, 0, 'get_listed_addresses: empty blocklist returns empty list');
    like($MockDB::prepared[0], qr/SELECT ip FROM blocklist/, 'get_listed_addresses: correct SQL');
    is(scalar @MockDB::disconnected, 1, 'get_listed_addresses: disconnects');
}

# --- multiple IPs ---
{
    MockDB::reset();
    @MockDB::fetch_queues = ( [['10.0.0.1'], ['172.16.0.2'], ['203.0.113.99']] );
    my @addrs = $db->get_listed_addresses();

    is(scalar @addrs, 3, 'get_listed_addresses: returns 3 IPs');
    # Note: unshift reverses the order
    is($addrs[0], '203.0.113.99', 'get_listed_addresses: last fetched IP is first (unshift)');
    is($addrs[2], '10.0.0.1', 'get_listed_addresses: first fetched IP is last');
}

# ===== get_listing_info =====

# --- IP with events and currently listed ---
{
    MockDB::reset();
    # First query (ipevents): 2 event rows [time, eventtext]
    # Second query (blocklist): 1 row [expires]
    @MockDB::fetch_queues = (
        [ ['2024-01-01 12:00', 'received spamtrap mail'], ['2024-01-02 13:00', 'received spamtrap mail'] ],
        [ ['2024-02-01 00:00'] ],
    );
    my ($listed, %iplog) = $db->get_listing_info('192.168.1.1');

    is($listed, 1, 'get_listing_info: IP is listed');
    is(scalar keys %iplog, 2, 'get_listing_info: 2 events in log');
    is($iplog{'2024-01-01 12:00'}, 'received spamtrap mail', 'get_listing_info: first event correct');

    # Verify both queries executed with correct IP
    is($MockDB::executed[0][0], '192.168.1.1', 'get_listing_info: ipevents query has IP');
    is($MockDB::executed[1][0], '192.168.1.1', 'get_listing_info: blocklist query has IP');
    is(scalar @MockDB::disconnected, 1, 'get_listing_info: disconnects');
}

# --- IP with no events and not listed ---
{
    MockDB::reset();
    @MockDB::fetch_queues = ( [], [] );
    my ($listed, %iplog) = $db->get_listing_info('1.2.3.4');

    is($listed, 0, 'get_listing_info (not listed): listed is 0');
    is(scalar keys %iplog, 0, 'get_listing_info (not listed): no events');
}

# ===== get_latest =====

{
    MockDB::reset();
    @MockDB::fetch_queues = (
        [ ['2024-01-15 10:00', '10.0.0.1', 'received spamtrap mail'],
          ['2024-01-14 09:00', '172.16.0.2', 'removed through website'] ],
    );
    my %events = $db->get_latest(5);

    is(scalar keys %events, 2, 'get_latest: returns 2 events');
    is($events{'2024-01-15 10:00'}, '10.0.0.1 received spamtrap mail', 'get_latest: first event');
    is($events{'2024-01-14 09:00'}, '172.16.0.2 removed through website', 'get_latest: second event');
    is($MockDB::executed[0][0], 5, 'get_latest: execute passes limit param');
    like($MockDB::prepared[0], qr/ORDER BY eventtime DESC LIMIT/, 'get_latest: SQL has ORDER and LIMIT');
}

# --- get_latest with empty results ---
{
    MockDB::reset();
    @MockDB::fetch_queues = ( [] );
    my %events = $db->get_latest(10);

    is(scalar keys %events, 0, 'get_latest (empty): returns empty hash');
    is($MockDB::executed[0][0], 10, 'get_latest (empty): passes limit param');
}

# ===== Error propagation =====

# --- storeip propagates errors ---
{
    MockDB::reset();
    # Make execute die on the first call
    my $orig_execute = \&MockDB::STH::execute;
    no warnings 'redefine';
    local *MockDB::STH::execute = sub {
        die "database error";
    };
    eval { $db->storeip('1.2.3.4', 'test') };
    ok($@, 'storeip: propagates database errors');
    like($@, qr/database error/, 'storeip: error message preserved');
    # Still disconnects even on error
    is(scalar @MockDB::disconnected, 1, 'storeip: disconnects on error');
}

# --- archivemail propagates errors ---
{
    MockDB::reset();
    no warnings 'redefine';
    local *MockDB::STH::execute = sub {
        die "insert failed";
    };
    eval { $db->archivemail('1.2.3.4', 1, 'mail') };
    ok($@, 'archivemail: propagates database errors');
    is(scalar @MockDB::disconnected, 1, 'archivemail: disconnects on error');
}

done_testing();
