#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

# --- Localhost ---
is(Spamikaze::MXBackup('127.0.0.1'), 'localhost', '127.0.0.1 is localhost');
is(Spamikaze::MXBackup('127.0.0.2'), 'localhost', '127.0.0.2 is localhost');
is(Spamikaze::MXBackup('127.255.255.255'), 'localhost', '127.255.255.255 is localhost');

# --- RFC1918 (with ignoreRFC1918 enabled via config) ---
is(Spamikaze::MXBackup('10.0.0.1'), 'RFC1918 private address', '10.x is RFC1918');
is(Spamikaze::MXBackup('10.255.255.255'), 'RFC1918 private address', '10.255.x is RFC1918');
is(Spamikaze::MXBackup('172.16.0.1'), 'RFC1918 private address', '172.16.x is RFC1918');
is(Spamikaze::MXBackup('172.31.255.255'), 'RFC1918 private address', '172.31.x is RFC1918');
is(Spamikaze::MXBackup('192.168.0.1'), 'RFC1918 private address', '192.168.x is RFC1918');
is(Spamikaze::MXBackup('192.168.255.255'), 'RFC1918 private address', '192.168.255.x is RFC1918');

# Not RFC1918
is(Spamikaze::MXBackup('172.15.0.1'), 0, '172.15.x is not RFC1918');
is(Spamikaze::MXBackup('172.33.0.1'), 0, '172.33.x is not RFC1918');
ok(!Spamikaze::MXBackup('192.169.0.1'), '192.169.x is not RFC1918');

# --- Backup MX (configured as 203.0.113.1) ---
is(Spamikaze::MXBackup('203.0.113.1'), 'backup MX', 'configured backup MX IP');

# --- Normal public IP ---
is(Spamikaze::MXBackup('198.51.100.1'), 0, 'normal public IP returns 0');
is(Spamikaze::MXBackup('8.8.8.8'), 0, '8.8.8.8 returns 0');

done_testing();
