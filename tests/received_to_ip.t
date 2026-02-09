#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

TestHelper::load_passivetrap();

# IPv4 in square brackets
is(received_to_ip('from host [192.168.1.1] by mx'), '192.168.1.1',
    'IPv4 in square brackets');

# IPv4 in parentheses
is(received_to_ip('from host (10.0.0.1) by mx'), '10.0.0.1',
    'IPv4 in parentheses');

# IPv4 with IPv6 prefix (IPv4-mapped IPv6)
is(received_to_ip('from host [IPv6:::ffff:192.0.2.1] by mx'), '192.0.2.1',
    'IPv4-mapped IPv6 address');

# Pure IPv6 (2001:db8::1)
is(received_to_ip('from host [IPv6:2001:db8:0:0:0:0:0:1] by mx'), '2001:db8:0:0:0:0:0:1',
    'pure IPv6 2001: address');

# Pure IPv6 (3ffe prefix)
is(received_to_ip('from host [IPv6:3ffe:1234:5678:abcd:0:0:0:1] by mx'), '3ffe:1234:5678:abcd:0:0:0:1',
    'pure IPv6 3ffe: address');

# Fallback bare IPv4 (no brackets)
is(received_to_ip('from host 1.2.3.4 by mx.example.com'), '1.2.3.4',
    'bare IPv4 without brackets');

# No IP at all
is(received_to_ip('from host by mx'), '',
    'no IP returns empty string');

# No IP - just text
is(received_to_ip('some random text'), '',
    'random text returns empty string');

# Real-world Received header: Postfix style
is(received_to_ip('from unknown (HELO mail.example.com) (203.0.113.42) by mx.example.com'), '203.0.113.42',
    'Postfix-style Received header');

# Real-world Received header: sendmail style
is(received_to_ip('from mail.example.com (mail.example.com [198.51.100.25]) by mx.example.com'), '198.51.100.25',
    'sendmail-style Received header');

# Real-world: qmail
is(received_to_ip('from 172.16.0.1 by mx.example.com'), '172.16.0.1',
    'qmail-style bare IP');

# Multiple IPs - should return the first one
is(received_to_ip('from host [10.0.0.1] via [10.0.0.2] by mx'), '10.0.0.1',
    'multiple IPs returns first one');

# parsereceived delegates to received_to_ip
is(parsereceived('from host [192.168.1.100] by mx'), '192.168.1.100',
    'parsereceived returns same as received_to_ip');

is(parsereceived('from host by mx'), '',
    'parsereceived returns empty for no IP');

# IPv6 2002 prefix
is(received_to_ip('from host [IPv6:2002:abcd:ef01:0:0:0:0:1] by mx'), '2002:abcd:ef01:0:0:0:0:1',
    'pure IPv6 2002: address');

done_testing();
