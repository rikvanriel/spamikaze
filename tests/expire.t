#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

# --- Smart DBI mock (same as pgsql3.t) ---

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

# --- Load the real PgSQL_3 code ---
{
    my $src_file = "$FindBin::Bin/../scripts/Spamikaze/PgSQL_3.pm";
    open my $fh, '<', $src_file or die "Cannot read $src_file: $!";
    my $src = do { local $/; <$fh> };
    close $fh;
    $src =~ s/^use warnings;$/use warnings;\nno warnings 'redefine';/m;
    eval $src;
    die "Failed to load real PgSQL_3: $@" if $@;
}

# --- Load the real MySQL_2 code ---
{
    my $src_file = "$FindBin::Bin/../scripts/Spamikaze/MySQL_2.pm";
    open my $fh, '<', $src_file or die "Cannot read $src_file: $!";
    my $src = do { local $/; <$fh> };
    close $fh;
    $src =~ s/^use warnings;$/use warnings;\nno warnings 'redefine';/m;
    eval $src;
    die "Failed to load real MySQL_2: $@" if $@;
}

# --- Override DBConnect ---
{
    no warnings 'redefine';
    *Spamikaze::DBConnect = sub { return MockDB::new_dbh() };
}

# ============================================================
# PgSQL_3::expire - simple DELETE + commit + disconnect
# ============================================================
{
    my $db = Spamikaze::PgSQL_3->new();

    # --- Basic expire call ---
    MockDB::reset();
    $db->expire('127.0.0.2');

    is(scalar @MockDB::do_calls, 1, 'PgSQL_3 expire: one DO call');
    like($MockDB::do_calls[0]{sql}, qr/DELETE FROM blocklist/i,
        'PgSQL_3 expire: DELETE FROM blocklist SQL');
    like($MockDB::do_calls[0]{sql}, qr/expires\s*<\s*CURRENT_TIMESTAMP/i,
        'PgSQL_3 expire: uses CURRENT_TIMESTAMP comparison');
    is(scalar @MockDB::committed, 1, 'PgSQL_3 expire: commits');
    is(scalar @MockDB::disconnected, 1, 'PgSQL_3 expire: disconnects');

    # --- expire with no dontexpire args (PgSQL_3 ignores them anyway) ---
    MockDB::reset();
    $db->expire();
    is(scalar @MockDB::do_calls, 1, 'PgSQL_3 expire: works with no dontexpire args');

    # --- expire with multiple dontexpire args ---
    MockDB::reset();
    $db->expire('127.0.0.2', '10.0.0.0');
    is(scalar @MockDB::do_calls, 1, 'PgSQL_3 expire: works with multiple dontexpire args');
}

# ============================================================
# MySQL_2::mxdontexpire - pattern matching against dontexpire list
# ============================================================
{
    my $db = Spamikaze::MySQL_2->new();

    # Matching IP
    is($db->mxdontexpire('127.0.0.2', '127.0.0.2'), 1,
        'mxdontexpire: exact match returns 1');

    # Prefix match
    is($db->mxdontexpire('10.1.2.3', '10\.'), 1,
        'mxdontexpire: prefix regex match returns 1');

    # No match
    is($db->mxdontexpire('192.168.1.1', '127.0.0.2'), 0,
        'mxdontexpire: non-matching IP returns 0');

    # Multiple patterns, second matches
    is($db->mxdontexpire('10.0.0.1', '127.0.0.2', '10\.'), 1,
        'mxdontexpire: matches second pattern');

    # Empty dontexpire list
    is($db->mxdontexpire('10.0.0.1'), 0,
        'mxdontexpire: empty list returns 0');
}

# ============================================================
# MySQL_2::expire - complex logic with fetch/expire/time checks
# ============================================================
{
    my $db = Spamikaze::MySQL_2->new();

    # Set config values that expire uses
    $Spamikaze::firsttime = 24 * 3600;    # 24 hours in seconds
    $Spamikaze::extratime = 12 * 3600;    # 12 hours in seconds
    $Spamikaze::maxspamperip = 10;

    # --- No rows to expire ---
    MockDB::reset();
    @MockDB::fetch_queues = (
        [],   # SELECT query returns no rows
    );
    $db->expire('127.0.0.2');

    is(scalar @MockDB::prepared, 1, 'MySQL_2 expire no rows: prepares SELECT only');
    like($MockDB::prepared[0], qr/SELECT.*COUNT/si, 'MySQL_2 expire: SELECT with COUNT');
    is(scalar @MockDB::executed, 1, 'MySQL_2 expire no rows: only SELECT executed');
    is(scalar @MockDB::committed, 1, 'MySQL_2 expire no rows: commits');
    is(scalar @MockDB::disconnected, 1, 'MySQL_2 expire no rows: disconnects');

    # --- Single spam entry, old enough to expire ---
    MockDB::reset();
    my $old_time = time() - (48 * 3600);  # 48 hours ago, well past firsttime
    # fetch_queues[0] = rows for the SELECT: [total, octa, octb, octc, octd, spamtime]
    # fetch_queues[1] = rows for the UPDATE prepare (empty, it's just prepared)
    @MockDB::fetch_queues = (
        [ [1, 198, 51, 100, 42, $old_time] ],   # SELECT returns 1 row
        [],                                       # UPDATE prepare (gets no fetch)
    );
    $db->expire();

    # The UPDATE should have been executed with the IP octets
    my @update_executions = grep { scalar @$_ == 4 } @MockDB::executed;
    is(scalar @update_executions, 1, 'MySQL_2 expire old single: UPDATE executed');
    is_deeply($update_executions[0], [198, 51, 100, 42],
        'MySQL_2 expire old single: correct octets in UPDATE');

    # --- Single spam entry, too recent to expire ---
    MockDB::reset();
    my $recent_time = time() - 3600;  # 1 hour ago, well within firsttime (24h)
    @MockDB::fetch_queues = (
        [ [1, 198, 51, 100, 42, $recent_time] ],
        [],
    );
    $db->expire();

    @update_executions = grep { scalar @$_ == 4 } @MockDB::executed;
    is(scalar @update_executions, 0, 'MySQL_2 expire recent single: UPDATE not executed');

    # --- Multiple spam entries (total=3), old enough to expire ---
    MockDB::reset();
    # bonustime = spamtime + (extratime * total) + firsttime
    # = old_time + (12h * 3) + 24h = old_time + 60h
    my $very_old_time = time() - (72 * 3600);  # 72 hours ago
    @MockDB::fetch_queues = (
        [ [3, 10, 0, 0, 1, $very_old_time] ],
        [],
    );
    $db->expire();

    @update_executions = grep { scalar @$_ == 4 } @MockDB::executed;
    is(scalar @update_executions, 1, 'MySQL_2 expire old multi: UPDATE executed');
    is_deeply($update_executions[0], [10, 0, 0, 1],
        'MySQL_2 expire old multi: correct octets');

    # --- Multiple spam entries, too recent to expire ---
    MockDB::reset();
    @MockDB::fetch_queues = (
        [ [3, 10, 0, 0, 1, $recent_time] ],
        [],
    );
    $db->expire();

    @update_executions = grep { scalar @$_ == 4 } @MockDB::executed;
    is(scalar @update_executions, 0, 'MySQL_2 expire recent multi: UPDATE not executed');

    # --- IP in dontexpire list is not expired ---
    MockDB::reset();
    @MockDB::fetch_queues = (
        [ [1, 127, 0, 0, 2, $old_time] ],
        [],
    );
    $db->expire('127.0.0.2');

    @update_executions = grep { scalar @$_ == 4 } @MockDB::executed;
    is(scalar @update_executions, 0, 'MySQL_2 expire dontexpire match: not expired');

    # --- IP NOT in dontexpire list IS expired ---
    MockDB::reset();
    @MockDB::fetch_queues = (
        [ [1, 198, 51, 100, 42, $old_time] ],
        [],
    );
    $db->expire('127.0.0.2');

    @update_executions = grep { scalar @$_ == 4 } @MockDB::executed;
    is(scalar @update_executions, 1, 'MySQL_2 expire dontexpire no match: expired');

    # --- total >= maxspamperip: never expired ---
    MockDB::reset();
    @MockDB::fetch_queues = (
        [ [10, 192, 168, 1, 1, $very_old_time] ],
        [],
    );
    $db->expire();

    @update_executions = grep { scalar @$_ == 4 } @MockDB::executed;
    is(scalar @update_executions, 0, 'MySQL_2 expire maxspamperip reached: not expired');

    # --- Multiple rows: one expired, one not ---
    MockDB::reset();
    @MockDB::fetch_queues = (
        [
            [1, 198, 51, 100, 42, $old_time],     # old, should expire
            [1, 203, 0, 113, 99, $recent_time],    # recent, should not
        ],
        [],  # for first UPDATE prepare
        [],  # for second UPDATE prepare
    );
    $db->expire();

    @update_executions = grep { scalar @$_ == 4 } @MockDB::executed;
    is(scalar @update_executions, 1, 'MySQL_2 expire mixed rows: only old one expired');
    is_deeply($update_executions[0], [198, 51, 100, 42],
        'MySQL_2 expire mixed rows: correct IP expired');
}

# ============================================================
# expire.pl script integration: calls $db->expire with @DONTEXPIRE
# ============================================================
{
    # Load expire.pl's main function
    my $script = "$FindBin::Bin/../scripts/expire.pl";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    $code =~ s/^\&main;\s*$//m;
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use FindBin;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;

    eval "package ExpireTest;\nuse strict;\nuse warnings;\n$code";
    die "Failed to load expire.pl: $@" if $@;

    # Verify @DONTEXPIRE is set
    is_deeply(\@ExpireTest::DONTEXPIRE, ['127.0.0.2'],
        'expire.pl: @DONTEXPIRE defaults to 127.0.0.2');

    # Replace $Spamikaze::db with a tracking mock
    my @expire_args;
    {
        no warnings 'redefine';
        my $mock_db = bless {}, 'ExpireTest::MockDB';
        local $Spamikaze::db = $mock_db;

        package ExpireTest::MockDB;
        sub expire {
            my ($self, @args) = @_;
            push @expire_args, [@args];
        }
        package main;

        ExpireTest::main();
    }

    is(scalar @expire_args, 1, 'expire.pl main: calls expire once');
    is_deeply($expire_args[0], ['127.0.0.2'],
        'expire.pl main: passes @DONTEXPIRE to expire');
}

done_testing();
