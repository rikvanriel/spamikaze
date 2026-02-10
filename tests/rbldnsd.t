#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;
use File::Temp qw(tempdir);

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

TestHelper::load_rbldnsd();

my $tmpdir = tempdir(CLEANUP => 1);
my $outfile = "$tmpdir/rbldnsd.zone";

our $zone_header;

# Helper to run main() with a given IP list and return zone file contents
sub generate_zone {
    my (@ips) = @_;
    TestHelper::reset_mocks();
    @TestHelper::listed_addresses = @ips;
    $zone_header = '';
    local @ARGV = ($outfile);
    main();
    open my $fh, '<', $outfile or die "Cannot read $outfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

# ===== Header tests =====

# --- Default record line ---
{
    my $zone = generate_zone();
    like($zone, qr/^:127\.0\.0\.2:http:\/\/example\.com\$/m,
        'header: default A record with URL template');
}

# --- SOA record ---
{
    my $zone = generate_zone();
    like($zone, qr/^\$SOA 3000 ns1\.example\.com root\.ns1\.example\.com 0 3600 3600 86400 3600$/m,
        'header: SOA with correct NS, TTL values');
}

# --- NS record ---
{
    my $zone = generate_zone();
    like($zone, qr/^\$NS 86400 ns1\.example\.com ns2\.example\.com$/m,
        'header: NS record with primary and secondary');
}

# --- Test entry 127.0.0.2 ---
{
    my $zone = generate_zone();
    like($zone, qr/^127\.0\.0\.2$/m, 'header: standard test entry 127.0.0.2');
}

# ===== Empty blocklist =====

{
    my $zone = generate_zone();
    my @lines = split /\n/, $zone;
    # Should only have header lines (default record, SOA, NS, test entry)
    is(scalar @lines, 4, 'empty blocklist: only 4 header lines');
}

# ===== Single IP =====

{
    my $zone = generate_zone('198.51.100.1');
    like($zone, qr/^198\.51\.100\.1$/m, 'single IP: present in zone');
    my @lines = split /\n/, $zone;
    is(scalar @lines, 5, 'single IP: 4 header + 1 IP');
}

# ===== Multiple IPs =====

{
    my $zone = generate_zone('10.0.0.1', '172.16.0.2', '203.0.113.99');
    like($zone, qr/^10\.0\.0\.1$/m, 'multi IP: first IP present');
    like($zone, qr/^172\.16\.0\.2$/m, 'multi IP: second IP present');
    like($zone, qr/^203\.0\.113\.99$/m, 'multi IP: third IP present');
    my @lines = split /\n/, $zone;
    is(scalar @lines, 7, 'multi IP: 4 header + 3 IPs');
}

# ===== IPs are NOT reversed (unlike named.pl) =====

{
    my $zone = generate_zone('1.2.3.4');
    like($zone, qr/^1\.2\.3\.4$/m, 'IP written in original (non-reversed) order');
    unlike($zone, qr/^4\.3\.2\.1$/m, 'reversed IP not present');
}

# ===== IPs appear after header =====

{
    my $zone = generate_zone('192.168.1.1');
    my $header_end = index($zone, "127.0.0.2\n");
    my $ip_pos = index($zone, "192.168.1.1");
    ok($header_end < $ip_pos, 'IPs appear after header test entry');
}

# ===== One IP per line =====

{
    my $zone = generate_zone('10.0.0.1', '10.0.0.2');
    like($zone, qr/^10\.0\.0\.1\n10\.0\.0\.2$/m, 'each IP on its own line');
}

# ===== File atomicity: no leftover temp files =====

{
    generate_zone();
    my @temps = glob("$outfile.*");
    is(scalar @temps, 0, 'no leftover temp files after generation');
    ok(-f $outfile, 'final zone file exists');
}

# ===== Config values used correctly =====

# --- TTL from config appears in SOA ---
{
    my $zone = generate_zone();
    # TTL is 3600 from config, appears multiple times in SOA
    my @ttl_matches = ($zone =~ /3600/g);
    ok(scalar @ttl_matches >= 3, 'config TTL 3600 appears in SOA fields');
}

# --- URL base from config ---
{
    my $zone = generate_zone();
    like($zone, qr/http:\/\/example\.com/, 'URL base from config in default record');
}

# --- Primary NS from config ---
{
    my $zone = generate_zone();
    like($zone, qr/ns1\.example\.com/, 'primary NS from config');
}

# ===== build_header appends (doesn't overwrite) =====
# Verify that calling build_header doesn't lose earlier content
# by checking the zone_header after generation
{
    my $zone = generate_zone('5.6.7.8');
    # zone_header should contain all header parts
    like($zone_header, qr/:127\.0\.0\.2:/, 'zone_header contains default record');
    like($zone_header, qr/\$SOA/, 'zone_header contains SOA');
    like($zone_header, qr/\$NS/, 'zone_header contains NS');
}

done_testing();
