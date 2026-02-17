#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

# ===== IsIPv6 =====

ok(Spamikaze::IsIPv6('2001:db8::1'), 'IsIPv6: simple IPv6');
ok(Spamikaze::IsIPv6('::1'), 'IsIPv6: loopback');
ok(Spamikaze::IsIPv6('fe80::1'), 'IsIPv6: link-local');
ok(!Spamikaze::IsIPv6('192.168.1.1'), 'IsIPv6: IPv4 is not IPv6');
ok(!Spamikaze::IsIPv6(''), 'IsIPv6: empty string');
ok(!Spamikaze::IsIPv6(undef), 'IsIPv6: undef');

# ===== NormalizeIPv6 =====

# Full expansion
is(Spamikaze::NormalizeIPv6('2001:db8:1234:5678:abcd:ef01:2345:6789'),
    '2001:0db8:1234:5678:abcd:ef01:2345:6789',
    'NormalizeIPv6: already expanded');

# Compressed form
is(Spamikaze::NormalizeIPv6('2001:db8::1'),
    '2001:0db8:0000:0000:0000:0000:0000:0001',
    'NormalizeIPv6: compressed with ::');

# Loopback
is(Spamikaze::NormalizeIPv6('::1'),
    '0000:0000:0000:0000:0000:0000:0000:0001',
    'NormalizeIPv6: loopback ::1');

# All zeros
is(Spamikaze::NormalizeIPv6('::'),
    '0000:0000:0000:0000:0000:0000:0000:0000',
    'NormalizeIPv6: all zeros ::');

# Mixed case
is(Spamikaze::NormalizeIPv6('2001:DB8:ABCD::1'),
    '2001:0db8:abcd:0000:0000:0000:0000:0001',
    'NormalizeIPv6: mixed case normalized to lowercase');

# IPv4-mapped returns undef
is(Spamikaze::NormalizeIPv6('::ffff:192.0.2.1'), undef,
    'NormalizeIPv6: IPv4-mapped returns undef');

# Invalid inputs
is(Spamikaze::NormalizeIPv6('not-an-ip'), undef,
    'NormalizeIPv6: garbage returns undef');
is(Spamikaze::NormalizeIPv6(''), undef,
    'NormalizeIPv6: empty string returns undef');
is(Spamikaze::NormalizeIPv6(undef), undef,
    'NormalizeIPv6: undef returns undef');
is(Spamikaze::NormalizeIPv6('2001:db8::1::2'), undef,
    'NormalizeIPv6: double :: returns undef (too many groups)');

# Leading zeros in groups
is(Spamikaze::NormalizeIPv6('2001:0db8:0000:0000:0000:0000:0000:0001'),
    '2001:0db8:0000:0000:0000:0000:0000:0001',
    'NormalizeIPv6: already fully expanded');

# fe80 link-local
is(Spamikaze::NormalizeIPv6('fe80::1'),
    'fe80:0000:0000:0000:0000:0000:0000:0001',
    'NormalizeIPv6: link-local');

# fd00 ULA
is(Spamikaze::NormalizeIPv6('fd00::1'),
    'fd00:0000:0000:0000:0000:0000:0000:0001',
    'NormalizeIPv6: ULA');

# ===== IPv6ToPrefix64 =====

is(Spamikaze::IPv6ToPrefix64('2001:db8:1234:5678:abcd:ef01:2345:6789'),
    '2001:0db8:1234:5678:0000:0000:0000:0000',
    'IPv6ToPrefix64: zeros lower 64 bits');

is(Spamikaze::IPv6ToPrefix64('2001:db8::1'),
    '2001:0db8:0000:0000:0000:0000:0000:0000',
    'IPv6ToPrefix64: compressed address');

is(Spamikaze::IPv6ToPrefix64('fe80::abcd:1234:5678:9abc'),
    'fe80:0000:0000:0000:0000:0000:0000:0000',
    'IPv6ToPrefix64: link-local prefix');

# Two different IPs in the same /64 should yield the same prefix
is(Spamikaze::IPv6ToPrefix64('2001:db8:1234:5678::1'),
    Spamikaze::IPv6ToPrefix64('2001:db8:1234:5678::ffff'),
    'IPv6ToPrefix64: same /64 for different host parts');

# Different /64s
isnt(Spamikaze::IPv6ToPrefix64('2001:db8:1234:5678::1'),
     Spamikaze::IPv6ToPrefix64('2001:db8:1234:5679::1'),
     'IPv6ToPrefix64: different /64s produce different prefixes');

is(Spamikaze::IPv6ToPrefix64('not-valid'), undef,
    'IPv6ToPrefix64: invalid returns undef');

# ===== ValidIPv6 =====

ok(Spamikaze::ValidIPv6('2001:db8::1'), 'ValidIPv6: valid compressed');
ok(Spamikaze::ValidIPv6('::1'), 'ValidIPv6: loopback');
ok(Spamikaze::ValidIPv6('::'), 'ValidIPv6: all zeros');
ok(Spamikaze::ValidIPv6('2001:0db8:0000:0000:0000:0000:0000:0001'), 'ValidIPv6: fully expanded');
ok(!Spamikaze::ValidIPv6('::ffff:192.0.2.1'), 'ValidIPv6: IPv4-mapped is not valid IPv6');
ok(!Spamikaze::ValidIPv6('192.168.1.1'), 'ValidIPv6: IPv4 is not valid IPv6');
ok(!Spamikaze::ValidIPv6('garbage'), 'ValidIPv6: garbage is not valid');
ok(!Spamikaze::ValidIPv6(''), 'ValidIPv6: empty string');

# ===== ValidIP (combined IPv4 + IPv6) =====

ok(Spamikaze::ValidIP('192.168.1.1'), 'ValidIP: IPv4 still works');
ok(Spamikaze::ValidIP('2001:db8::1'), 'ValidIP: IPv6 now works');
ok(!Spamikaze::ValidIP('not-an-ip'), 'ValidIP: garbage rejected');
ok(!Spamikaze::ValidIP(''), 'ValidIP: empty rejected');

done_testing();
