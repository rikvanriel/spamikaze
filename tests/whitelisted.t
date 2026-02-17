#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

# whitelist_zones are set to "wl.example.com wl2.example.com" via config

# --- IP found in first whitelist zone ---
TestHelper::reset_mocks();
$TestHelper::dns_answers{"1.100.51.198.wl.example.com/A"} = 1;
is(Spamikaze::whitelisted('198.51.100.1'), 'whitelisted in wl.example.com',
    'IP found in first whitelist zone');

# --- IP found in second whitelist zone ---
TestHelper::reset_mocks();
$TestHelper::dns_answers{"1.1.168.192.wl2.example.com/A"} = 1;
is(Spamikaze::whitelisted('192.168.1.1'), 'whitelisted in wl2.example.com',
    'IP found in second whitelist zone');

# --- IP not found in any zone ---
TestHelper::reset_mocks();
is(Spamikaze::whitelisted('203.0.113.50'), 0,
    'IP not in any whitelist zone returns 0');

# --- Verify IP octets are reversed ---
TestHelper::reset_mocks();
# For IP 1.2.3.4, reversed should be 4.3.2.1
$TestHelper::dns_answers{"4.3.2.1.wl.example.com/A"} = 1;
is(Spamikaze::whitelisted('1.2.3.4'), 'whitelisted in wl.example.com',
    'IP octets are reversed for DNS query');

# Verify the un-reversed version does NOT match
TestHelper::reset_mocks();
$TestHelper::dns_answers{"1.2.3.4.wl.example.com/A"} = 1;
is(Spamikaze::whitelisted('1.2.3.4'), 0,
    'unreversed IP does not match');

# --- First matching zone wins ---
TestHelper::reset_mocks();
$TestHelper::dns_answers{"1.0.0.10.wl.example.com/A"} = 1;
$TestHelper::dns_answers{"1.0.0.10.wl2.example.com/A"} = 1;
is(Spamikaze::whitelisted('10.0.0.1'), 'whitelisted in wl.example.com',
    'first matching zone wins');

# --- No whitelist zones configured ---
{
    local @Spamikaze::whitelist_zones = ();
    TestHelper::reset_mocks();
    is(Spamikaze::whitelisted('198.51.100.1'), 0,
        'no whitelist zones returns 0');
}

# --- Different IP formats ---
TestHelper::reset_mocks();
$TestHelper::dns_answers{"255.0.0.192.wl.example.com/A"} = 1;
is(Spamikaze::whitelisted('192.0.0.255'), 'whitelisted in wl.example.com',
    'IP with high octets reversed correctly');

# --- IPv6 nibble reversal ---
# 2001:0db8:1234:5678:0000:0000:0000:0001
# Nibbles reversed: 1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.7.6.5.4.3.2.1.8.b.d.0.1.0.0.2
TestHelper::reset_mocks();
$TestHelper::dns_answers{"1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.7.6.5.4.3.2.1.8.b.d.0.1.0.0.2.wl.example.com/A"} = 1;
is(Spamikaze::whitelisted('2001:db8:1234:5678::1'), 'whitelisted in wl.example.com',
    'IPv6 nibble reversal in whitelist query');

# IPv6 not found in whitelist
TestHelper::reset_mocks();
is(Spamikaze::whitelisted('2001:db8::99'), 0,
    'IPv6 not in any whitelist zone returns 0');

# IPv6 loopback nibble reversal: ::1 → 1.0.0.0...0.0.0.0
TestHelper::reset_mocks();
$TestHelper::dns_answers{"1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.wl.example.com/A"} = 1;
is(Spamikaze::whitelisted('::1'), 'whitelisted in wl.example.com',
    'IPv6 loopback nibble reversal');

done_testing();
