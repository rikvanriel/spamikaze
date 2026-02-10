#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

# ============================================================
# Version()
# ============================================================
{
    my $v = Spamikaze::Version();
    ok(defined $v, 'Version returns defined value');
    like($v, qr/Spamikaze\.pm/, 'Version mentions Spamikaze.pm');
}

# ============================================================
# GetDBType() - should return configured DB type
# ============================================================
{
    is(Spamikaze::GetDBType(), 'Pg', 'GetDBType returns configured type');
}

# ============================================================
# DBConnect() - returns a mock DBI handle
# ============================================================
{
    my $dbh = Spamikaze::DBConnect();
    ok(defined $dbh, 'DBConnect returns defined handle');
    ok(ref $dbh, 'DBConnect returns a reference');
}

# ============================================================
# SplitIP()
# ============================================================
{
    # Normal IPv4
    my @r = Spamikaze::SplitIP('192.168.1.1');
    is_deeply(\@r, [192, 168, 1, 1], 'SplitIP normal IP');

    # All zeros
    @r = Spamikaze::SplitIP('0.0.0.0');
    is_deeply(\@r, [0, 0, 0, 0], 'SplitIP 0.0.0.0');

    # All 255s
    @r = Spamikaze::SplitIP('255.255.255.255');
    is_deeply(\@r, [255, 255, 255, 255], 'SplitIP 255.255.255.255');

    # Single digit octets
    @r = Spamikaze::SplitIP('1.2.3.4');
    is_deeply(\@r, [1, 2, 3, 4], 'SplitIP single digit octets');

    # Not an IP - no match
    @r = Spamikaze::SplitIP('not-an-ip');
    is($r[0], undef, 'SplitIP non-IP returns undef octa');

    # Partial IP
    @r = Spamikaze::SplitIP('192.168.1');
    is($r[0], undef, 'SplitIP partial IP returns undef');

    # Too many octets
    @r = Spamikaze::SplitIP('1.2.3.4.5');
    is($r[0], undef, 'SplitIP too many octets returns undef');

    # IP with trailing text
    @r = Spamikaze::SplitIP('1.2.3.4foo');
    is($r[0], undef, 'SplitIP IP with trailing text returns undef');

    # IP with leading text
    @r = Spamikaze::SplitIP('foo1.2.3.4');
    is($r[0], undef, 'SplitIP IP with leading text returns undef');

    # Empty string
    @r = Spamikaze::SplitIP('');
    is($r[0], undef, 'SplitIP empty string returns undef');

    # Four digit octet (too many digits per the regex)
    @r = Spamikaze::SplitIP('1234.1.1.1');
    is($r[0], undef, 'SplitIP four digit octet returns undef');
}

# ============================================================
# ValidIP()
# ============================================================
{
    # Valid IPs
    is(Spamikaze::ValidIP('0.0.0.0'), 1, 'ValidIP 0.0.0.0');
    is(Spamikaze::ValidIP('255.255.255.255'), 1, 'ValidIP 255.255.255.255');
    is(Spamikaze::ValidIP('192.168.1.1'), 1, 'ValidIP 192.168.1.1');
    is(Spamikaze::ValidIP('1.2.3.4'), 1, 'ValidIP 1.2.3.4');
    is(Spamikaze::ValidIP('10.0.0.1'), 1, 'ValidIP 10.0.0.1');

    # Invalid - not an IP
    is(Spamikaze::ValidIP('not-an-ip'), 0, 'ValidIP non-IP');
    is(Spamikaze::ValidIP(''), 0, 'ValidIP empty string');

    # Invalid - partial
    is(Spamikaze::ValidIP('192.168.1'), 0, 'ValidIP partial IP');

    # Invalid - too many octets
    is(Spamikaze::ValidIP('1.2.3.4.5'), 0, 'ValidIP too many octets');

    # Note: regex limits to 3 digits so 999.999.999.999 would match the regex
    # but fail the range check
    is(Spamikaze::ValidIP('999.0.0.1'), 0, 'ValidIP octa out of range');
    is(Spamikaze::ValidIP('0.999.0.1'), 0, 'ValidIP octb out of range');
    is(Spamikaze::ValidIP('0.0.999.1'), 0, 'ValidIP octc out of range');
    is(Spamikaze::ValidIP('0.0.0.999'), 0, 'ValidIP octd out of range');
    is(Spamikaze::ValidIP('256.0.0.1'), 0, 'ValidIP 256 out of range');
}

# ============================================================
# ConfigRead() - verify values loaded from test config
# ============================================================
{
    # Database section
    is(Spamikaze::GetDBType(), 'Pg', 'ConfigRead: DB type');

    # Mail section - whitelist_zones loaded
    is(scalar @Spamikaze::whitelist_zones, 2, 'ConfigRead: 2 whitelist zones');
    is($Spamikaze::whitelist_zones[0], 'wl.example.com', 'ConfigRead: first whitelist zone');
    is($Spamikaze::whitelist_zones[1], 'wl2.example.com', 'ConfigRead: second whitelist zone');

    # Mail section - ignorebounces
    is($Spamikaze::ignorebounces, 1, 'ConfigRead: ignorebounces');

    # Expire section - converted from hours to seconds
    is($Spamikaze::firsttime, 24 * 3600, 'ConfigRead: firsttime in seconds');
    is($Spamikaze::extratime, 12 * 3600, 'ConfigRead: extratime in seconds');
    is($Spamikaze::maxspamperip, 10, 'ConfigRead: maxspamperip');

    # DNSBL section
    is($Spamikaze::dnsbl_domain, 'bl.example.com', 'ConfigRead: dnsbl_domain');
    is($Spamikaze::dnsbl_ttl, 3600, 'ConfigRead: dnsbl_ttl');
    is($Spamikaze::dnsbl_primary_ns, 'ns1.example.com', 'ConfigRead: primary NS');
    is($Spamikaze::dnsbl_secondary_nses, 'ns2.example.com', 'ConfigRead: secondary NSes');
    is($Spamikaze::dnsbl_url_base, 'http://example.com', 'ConfigRead: url base');
    is($Spamikaze::dnsbl_address, '127.0.0.2', 'ConfigRead: dnsbl address');

    # Web section
    is($Spamikaze::web_listname, 'test', 'ConfigRead: web listname');
    is($Spamikaze::web_listlatest, 10, 'ConfigRead: web listlatest');

    # NNTP section
    is($Spamikaze::nntp_enabled, 0, 'ConfigRead: nntp disabled');

    # Pipe section
    is($Spamikaze::pipe_program, '', 'ConfigRead: pipe program empty');
}

# ============================================================
# archive_spam() - with various flags
# ============================================================
{
    # With everything disabled (default test config: nntp=0, pipe='', email_in_db=0)
    TestHelper::reset_mocks();
    Spamikaze::archive_spam('198.51.100.1', 'spam body');
    is(scalar @TestHelper::archivemail_calls, 0, 'archive_spam: no archivemail when email_in_db=0');
}

# ============================================================
# archive_notspam() - with nntp disabled
# ============================================================
{
    TestHelper::reset_mocks();
    Spamikaze::archive_notspam('not spam body', 'reason');
    # With nntp_enabled=0, nothing should happen (no crash)
    ok(1, 'archive_notspam: no crash with nntp disabled');
}

# ============================================================
# $db object is initialized
# ============================================================
{
    ok(defined $Spamikaze::db, 'db object is initialized');
    ok(ref $Spamikaze::db, 'db object is a reference');
    # The configured Schema is PgSQL_3
    isa_ok($Spamikaze::db, 'Spamikaze::PgSQL_3', 'db is correct type');
}

done_testing();
