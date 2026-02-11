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

# --- Load real PgSQL_3 ---
{
    my $src_file = "$FindBin::Bin/../scripts/Spamikaze/PgSQL_3.pm";
    open my $fh, '<', $src_file or die "Cannot read $src_file: $!";
    my $src = do { local $/; <$fh> };
    close $fh;
    $src =~ s/^use warnings;$/use warnings;\nno warnings 'redefine';/m;
    eval $src;
    die "Failed to load real PgSQL_3: $@" if $@;
}

# --- Override DBConnect ---
{
    no warnings 'redefine';
    *Spamikaze::DBConnect = sub { return MockDB::new_dbh() };
}

my $db = Spamikaze::PgSQL_3->new();

# ============================================================
# PgSQL_3::get_listing_info
# ============================================================

# --- IP with events and currently listed ---
{
    MockDB::reset();
    # First prepare: ipevents query returns 2 rows [eventtime, eventtext]
    # Second prepare: blocklist query returns 1 row [expires]
    @MockDB::fetch_queues = (
        [
            ['2024-01-01 12:00:00', 'received spamtrap mail'],
            ['2024-01-02 06:00:00', 'removed through website'],
        ],
        [
            ['2024-01-03 00:00:00'],  # listed - has expiry
        ],
    );

    my ($listed, %iplog) = $db->get_listing_info('198.51.100.42');

    is($listed, 1, 'get_listing_info: IP is listed');
    is(scalar keys %iplog, 2, 'get_listing_info: 2 events returned');
    is($iplog{'2024-01-01 12:00:00'}, 'received spamtrap mail',
        'get_listing_info: first event text');
    is($iplog{'2024-01-02 06:00:00'}, 'removed through website',
        'get_listing_info: second event text');

    # Verify correct SQL and params
    like($MockDB::prepared[0], qr/ipevents.*eventtypes/si,
        'get_listing_info: ipevents query');
    is($MockDB::executed[0][0], '198.51.100.42',
        'get_listing_info: correct IP in ipevents query');
    like($MockDB::prepared[1], qr/blocklist/si,
        'get_listing_info: blocklist query');
    is($MockDB::executed[1][0], '198.51.100.42',
        'get_listing_info: correct IP in blocklist query');
    is(scalar @MockDB::disconnected, 1, 'get_listing_info: disconnects');
}

# --- IP with events but NOT currently listed ---
{
    MockDB::reset();
    @MockDB::fetch_queues = (
        [
            ['2024-01-01 12:00:00', 'received spamtrap mail'],
        ],
        [],  # blocklist empty — not listed
    );

    my ($listed, %iplog) = $db->get_listing_info('198.51.100.42');

    is($listed, 0, 'get_listing_info: IP not listed');
    is(scalar keys %iplog, 1, 'get_listing_info: 1 event returned');
}

# --- IP with no events at all ---
{
    MockDB::reset();
    @MockDB::fetch_queues = (
        [],  # no events
        [],  # not listed
    );

    my ($listed, %iplog) = $db->get_listing_info('192.0.2.1');

    is($listed, 0, 'get_listing_info: unlisted, no events');
    is(scalar keys %iplog, 0, 'get_listing_info: empty iplog');
}

# ============================================================
# PgSQL_3::remove_from_db
# ============================================================

# --- Successful removal ---
{
    MockDB::reset();
    $MockDB::do_return_value = 1;
    # The prepare inside store_ipevent
    @MockDB::fetch_queues = ();

    my $rows = $db->remove_from_db('198.51.100.42');

    is($rows, 1, 'remove_from_db: returns 1 row affected');
    like($MockDB::do_calls[0]{sql}, qr/DELETE FROM blocklist/i,
        'remove_from_db: DELETE SQL');
    is($MockDB::do_calls[0]{params}[0], '198.51.100.42',
        'remove_from_db: correct IP in DELETE');

    # store_ipevent should have been called
    is(scalar @MockDB::prepared, 1, 'remove_from_db: store_ipevent prepared');
    like($MockDB::prepared[0], qr/INSERT INTO ipevents/i,
        'remove_from_db: store_ipevent INSERT SQL');
    is($MockDB::executed[0][0], '198.51.100.42',
        'remove_from_db: store_ipevent IP');
    is($MockDB::executed[0][1], 'removed through website',
        'remove_from_db: store_ipevent event text');

    is(scalar @MockDB::committed, 1, 'remove_from_db: commits');
    is(scalar @MockDB::disconnected, 1, 'remove_from_db: disconnects');
}

# --- IP not found (0 rows affected) ---
{
    MockDB::reset();
    $MockDB::do_return_value = 0;

    my $rows = $db->remove_from_db('192.0.2.99');

    is($rows, 0, 'remove_from_db: returns 0 when not found');
    # store_ipevent should NOT have been called
    is(scalar @MockDB::prepared, 0, 'remove_from_db: no store_ipevent when not found');
    is(scalar @MockDB::committed, 1, 'remove_from_db: still commits');
    is(scalar @MockDB::disconnected, 1, 'remove_from_db: still disconnects');
}

# ============================================================
# PgSQL_3::get_latest
# ============================================================

# --- Returns events ---
{
    MockDB::reset();
    # [eventtime, ip, eventtext]
    @MockDB::fetch_queues = (
        [
            ['2024-01-03 12:00:00.123', '198.51.100.42', 'received spamtrap mail'],
            ['2024-01-03 12:01:00.456', '203.0.113.99', 'removed through website'],
        ],
    );

    my %events = $db->get_latest(10);

    is(scalar keys %events, 2, 'get_latest: 2 events returned');
    is($events{'2024-01-03 12:00:00.123'}, '198.51.100.42 received spamtrap mail',
        'get_latest: first event');
    is($events{'2024-01-03 12:01:00.456'}, '203.0.113.99 removed through website',
        'get_latest: second event');

    like($MockDB::prepared[0], qr/ORDER BY eventtime DESC LIMIT/i,
        'get_latest: SQL has ORDER BY and LIMIT');
    is($MockDB::executed[0][0], 10, 'get_latest: LIMIT param is 10');
    is(scalar @MockDB::disconnected, 1, 'get_latest: disconnects');
}

# --- No events ---
{
    MockDB::reset();
    @MockDB::fetch_queues = ([]);

    my %events = $db->get_latest(5);

    is(scalar keys %events, 0, 'get_latest: empty when no events');
}

# ============================================================
# CGI script function tests - listing.cgi
# ============================================================
{
    # Load listing.cgi helpers
    my $script = "$FindBin::Bin/../cgi-bin/listing.cgi";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    $code =~ s/^\&main;\s*$//m;
    $code =~ s/^main;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;
    $code =~ s/^use Spamikaze;\s*$//m;
    # Remove the file-scope CGI and $q
    $code =~ s/^use CGI[^;]*;\s*$//m;
    $code =~ s/^my \$q = new CGI;\s*$//m;
    # Remove the no-warnings hack at the end
    $code =~ s/^my \$nowarnings.*$//m;

    eval "package ListingTest;\n"
       . "use strict;\nuse warnings;\n"
       . "use CGI qw(:standard :html4 -no_xhtml);\n"
       . "my \$q = CGI->new('');\n"
       . $code;
    die "Failed to load listing.cgi: $@" if $@;

    # --- invalid_page_body ---
    {
        my $body = ListingTest::invalid_page_body('bad-ip');
        like($body, qr/valid.*IP/si, 'listing invalid_page_body: mentions valid IP');
        like($body, qr/bad-ip/, 'listing invalid_page_body: shows the bad input');
    }

    # --- invalid_page_body: XSS protection ---
    {
        my $body = ListingTest::invalid_page_body('<script>alert(1)</script>');
        unlike($body, qr/<script>/, 'listing invalid_page_body: HTML-escapes input');
        like($body, qr/&lt;script&gt;/, 'listing invalid_page_body: entities present');
    }

    # --- example_page_body ---
    {
        my $body = ListingTest::example_page_body('127.0.0.1');
        like($body, qr/example/i, 'listing example_page_body: mentions example');
        like($body, qr/mail server/i, 'listing example_page_body: mentions mail server');
    }

    # --- listing_page_body: never listed ---
    {
        my $body = ListingTest::listing_page_body('198.51.100.42', ' ', 0);
        like($body, qr/never been listed/i, 'listing_page_body: never listed');
        like($body, qr/198\.51\.100\.42/, 'listing_page_body: shows IP');
    }

    # --- listing_page_body: currently listed ---
    {
        my $foundinfo = "<tr><td>2024-01-01</td><td>received spamtrap mail</td></tr>\n";
        my $body = ListingTest::listing_page_body('198.51.100.42', $foundinfo, 1);
        like($body, qr/Yes/, 'listing_page_body: listed = Yes');
        like($body, qr/Spam and removal history/i, 'listing_page_body: shows history');
        like($body, qr/Remove IP/, 'listing_page_body: shows remove form');
        like($body, qr/198\.51\.100\.42/, 'listing_page_body: shows IP in form');
    }

    # --- listing_page_body: not currently listed but has history ---
    {
        my $foundinfo = "<tr><td>2024-01-01</td><td>removed through website</td></tr>\n";
        my $body = ListingTest::listing_page_body('198.51.100.42', $foundinfo, 0);
        like($body, qr/No/, 'listing_page_body: listed = No');
        like($body, qr/table/, 'listing_page_body: has table');
    }

    # --- listing_page_body: XSS in IP ---
    {
        my $body = ListingTest::listing_page_body('<script>', ' ', 0);
        unlike($body, qr/<script>/, 'listing_page_body: escapes IP');
    }
}

# ============================================================
# CGI script function tests - remove.cgi
# ============================================================
{
    my $script = "$FindBin::Bin/../cgi-bin/remove.cgi";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    $code =~ s/^main;\s*$//m;
    $code =~ s/^\&main;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use CGI[^;]*;\s*$//m;
    $code =~ s/^my \$q = new CGI;\s*$//m;
    $code =~ s/^my \$nowarn.*$//m;
    $code =~ s/^my \$listname = \$Spamikaze::web_listname;\s*$/my \$listname = 'TestList';/m;

    eval "package RemoveTest;\n"
       . "use strict;\nuse warnings;\n"
       . "use CGI qw(:standard :html4 -no_xhtml);\n"
       . "my \$q = CGI->new('');\n"
       . $code;
    die "Failed to load remove.cgi: $@" if $@;

    # --- invalid_page ---
    {
        my $body = RemoveTest::invalid_page('bad');
        like($body, qr/Invalid IP/i, 'remove invalid_page: mentions invalid');
        like($body, qr/bad/, 'remove invalid_page: shows input');
    }

    # --- invalid_page: undef IP ---
    {
        my $body = RemoveTest::invalid_page(undef);
        like($body, qr/Invalid IP/i, 'remove invalid_page: handles undef');
    }

    # --- invalid_page: XSS ---
    {
        my $body = RemoveTest::invalid_page('<img onerror=alert(1)>');
        unlike($body, qr/<img/, 'remove invalid_page: HTML-escapes input');
    }

    # --- success_page ---
    {
        my $body = RemoveTest::success_page('198.51.100.42');
        like($body, qr/has been removed/i, 'remove success_page: mentions removed');
        like($body, qr/198\.51\.100\.42/, 'remove success_page: shows IP');
        like($body, qr/DNSBL/, 'remove success_page: mentions DNSBL');
    }

    # --- not_found_page ---
    {
        my $body = RemoveTest::not_found_page('192.0.2.1');
        like($body, qr/does not appear/i, 'remove not_found_page: mentions not found');
        like($body, qr/192\.0\.2\.1/, 'remove not_found_page: shows IP');
    }
}

# ============================================================
# CGI script function tests - latest.cgi
# ============================================================
{
    my $script = "$FindBin::Bin/../cgi-bin/latest.cgi";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    $code =~ s/^main;\s*$//m;
    $code =~ s/^\&main;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use CGI[^;]*;\s*$//m;
    $code =~ s/^my \$q = new CGI;\s*$//m;

    eval "package LatestTest;\n"
       . "use strict;\nuse warnings;\n"
       . "use CGI qw(:standard :html4 -no_xhtml);\n"
       . "my \$q = CGI->new('');\n"
       . $code;
    die "Failed to load latest.cgi: $@" if $@;

    # Test the write_page by capturing STDOUT
    {
        # Mock get_latest on $Spamikaze::db
        no warnings 'redefine';
        my $orig_get_latest = \&Spamikaze::PgSQL_3::get_latest;

        *Spamikaze::PgSQL_3::get_latest = sub {
            my ($self, $num) = @_;
            return (
                '2024-01-03 12:00:00.123' => '198.51.100.42 received spamtrap mail',
                '2024-01-03 12:01:00.456' => '203.0.113.99 removed through website',
            );
        };

        my $output = '';
        {
            local *STDOUT;
            open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";
            LatestTest::main();
        }

        like($output, qr/198\.51\.100\.42/, 'latest main: output contains IP');
        like($output, qr/received spamtrap mail/, 'latest main: output contains event text');
        like($output, qr/203\.0\.113\.99/, 'latest main: output contains second IP');
        like($output, qr/<table/, 'latest main: output has table');
        like($output, qr/text\/html/, 'latest main: output has content-type');

        *Spamikaze::PgSQL_3::get_latest = $orig_get_latest;
    }

    # Test with empty events
    {
        no warnings 'redefine';
        my $orig_get_latest = \&Spamikaze::PgSQL_3::get_latest;

        *Spamikaze::PgSQL_3::get_latest = sub { return () };

        my $output = '';
        {
            local *STDOUT;
            open STDOUT, '>', \$output or die "Cannot redirect STDOUT: $!";
            LatestTest::main();
        }

        like($output, qr/<table/, 'latest main empty: still has table structure');
        like($output, qr/<\/table>/, 'latest main empty: table closed');

        *Spamikaze::PgSQL_3::get_latest = $orig_get_latest;
    }
}

# ============================================================
# listing.cgi main() integration - via STDOUT capture
# ============================================================
{
    my $script = "$FindBin::Bin/../cgi-bin/listing.cgi";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    $code =~ s/^\&main;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use CGI[^;]*;\s*$//m;
    $code =~ s/^my \$q = new CGI;\s*$//m;
    $code =~ s/^my \$nowarnings.*$//m;
    # Replace exit calls to avoid terminating the test
    $code =~ s/\bexit\b/return/g;

    # --- Invalid IP query ---
    {
        eval "package ListingMain;\n"
           . "use strict;\nuse warnings;\n"
           . "use CGI qw(:standard :html4 -no_xhtml);\n"
           . "my \$q = CGI->new('ip=notanip');\n"
           . $code;
        die "Failed to load listing.cgi for main test: $@" if $@;

        my $output = '';
        {
            local *STDOUT;
            open STDOUT, '>', \$output or die;
            ListingMain::main();
        }
        like($output, qr/valid.*IP/si, 'listing main: invalid IP shows error');
        like($output, qr/notanip/, 'listing main: invalid IP echoed (escaped)');
    }

    # --- 127.x example IP ---
    {
        eval "package ListingExample;\n"
           . "use strict;\nuse warnings;\n"
           . "use CGI qw(:standard :html4 -no_xhtml);\n"
           . "my \$q = CGI->new('ip=127.0.0.1');\n"
           . $code;
        die "Failed to load listing.cgi for example test: $@" if $@;

        my $output = '';
        {
            local *STDOUT;
            open STDOUT, '>', \$output or die;
            ListingExample::main();
        }
        like($output, qr/example/i, 'listing main: 127.x shows example page');
    }

    # --- Valid IP, listed ---
    {
        eval "package ListingListed;\n"
           . "use strict;\nuse warnings;\n"
           . "use CGI qw(:standard :html4 -no_xhtml);\n"
           . "my \$q = CGI->new('ip=198.51.100.42');\n"
           . $code;
        die "Failed to load listing.cgi for listed test: $@" if $@;

        no warnings 'redefine';
        my $orig = \&Spamikaze::PgSQL_3::get_listing_info;
        *Spamikaze::PgSQL_3::get_listing_info = sub {
            my ($self, $ip) = @_;
            return (1, '2024-01-01 12:00:00' => 'received spamtrap mail');
        };

        my $output = '';
        {
            local *STDOUT;
            open STDOUT, '>', \$output or die;
            ListingListed::main();
        }
        like($output, qr/Yes/, 'listing main: listed IP shows Yes');
        like($output, qr/198\.51\.100\.42/, 'listing main: shows IP');
        like($output, qr/received spamtrap mail/, 'listing main: shows event');

        *Spamikaze::PgSQL_3::get_listing_info = $orig;
    }
}

# ============================================================
# remove.cgi main() integration
# ============================================================
{
    my $script = "$FindBin::Bin/../cgi-bin/remove.cgi";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    $code =~ s/^main;\s*$//m;
    $code =~ s/^\&main;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use CGI[^;]*;\s*$//m;
    $code =~ s/^my \$q = new CGI;\s*$//m;
    $code =~ s/^my \$nowarn.*$//m;
    $code =~ s/^my \$listname = \$Spamikaze::web_listname;\s*$/my \$listname = 'TestList';/m;
    $code =~ s/\bexit\s+0\s*;/return;/g;

    # --- No IP param ---
    {
        eval "package RemoveNoIP;\n"
           . "use strict;\nuse warnings;\n"
           . "use CGI qw(:standard :html4 -no_xhtml);\n"
           . "my \$q = CGI->new('');\n"
           . $code;
        die "Failed to load remove.cgi for no-IP test: $@" if $@;

        my $output = '';
        {
            local *STDOUT;
            open STDOUT, '>', \$output or die;
            RemoveNoIP::main();
        }
        like($output, qr/Invalid IP/i, 'remove main: no IP shows invalid');
    }

    # --- 127.x IP ---
    {
        eval "package Remove127;\n"
           . "use strict;\nuse warnings;\n"
           . "use CGI qw(:standard :html4 -no_xhtml);\n"
           . "my \$q = CGI->new('ip=127.0.0.1');\n"
           . $code;
        die "Failed to load remove.cgi for 127.x test: $@" if $@;

        my $output = '';
        {
            local *STDOUT;
            open STDOUT, '>', \$output or die;
            Remove127::main();
        }
        like($output, qr/Invalid IP/i, 'remove main: 127.x shows invalid');
    }

    # --- Successful removal ---
    {
        eval "package RemoveOK;\n"
           . "use strict;\nuse warnings;\n"
           . "use CGI qw(:standard :html4 -no_xhtml);\n"
           . "my \$q = CGI->new('ip=198.51.100.42');\n"
           . $code;
        die "Failed to load remove.cgi for success test: $@" if $@;

        no warnings 'redefine';
        my $orig = \&Spamikaze::PgSQL_3::remove_from_db;
        *Spamikaze::PgSQL_3::remove_from_db = sub { return 1 };

        my $output = '';
        {
            local *STDOUT;
            open STDOUT, '>', \$output or die;
            RemoveOK::main();
        }
        like($output, qr/has been removed/i, 'remove main: success shows removed');
        like($output, qr/198\.51\.100\.42/, 'remove main: success shows IP');

        *Spamikaze::PgSQL_3::remove_from_db = $orig;
    }

    # --- IP not found in DB ---
    {
        eval "package RemoveNotFound;\n"
           . "use strict;\nuse warnings;\n"
           . "use CGI qw(:standard :html4 -no_xhtml);\n"
           . "my \$q = CGI->new('ip=192.0.2.99');\n"
           . $code;
        die "Failed to load remove.cgi for not-found test: $@" if $@;

        no warnings 'redefine';
        my $orig = \&Spamikaze::PgSQL_3::remove_from_db;
        *Spamikaze::PgSQL_3::remove_from_db = sub { return 0 };

        my $output = '';
        {
            local *STDOUT;
            open STDOUT, '>', \$output or die;
            RemoveNotFound::main();
        }
        like($output, qr/does not appear/i, 'remove main: not found shows message');

        *Spamikaze::PgSQL_3::remove_from_db = $orig;
    }
}

done_testing();
