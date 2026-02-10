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

TestHelper::load_text();

my $tmpdir = tempdir(CLEANUP => 1);
my $outfile = "$tmpdir/blocklist.txt";

# Helper to run main() with a given IP list and return file contents
sub generate_text {
    my (@ips) = @_;
    TestHelper::reset_mocks();
    @TestHelper::listed_addresses = @ips;
    local @ARGV = ($outfile);
    main();
    open my $fh, '<', $outfile or die "Cannot read $outfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    return $content;
}

# ===== Empty blocklist =====

{
    my $text = generate_text();
    is($text, '', 'empty blocklist: file is empty');
}

# ===== Single IP =====

{
    my $text = generate_text('198.51.100.1');
    is($text, "198.51.100.1\n", 'single IP: one line with newline');
}

# ===== Multiple IPs =====

{
    my $text = generate_text('10.0.0.1', '172.16.0.2', '203.0.113.99');
    my @lines = split /\n/, $text;
    is(scalar @lines, 3, 'multi IP: 3 lines');
    is($lines[0], '10.0.0.1', 'multi IP: first IP correct');
    is($lines[1], '172.16.0.2', 'multi IP: second IP correct');
    is($lines[2], '203.0.113.99', 'multi IP: third IP correct');
}

# ===== One IP per line =====

{
    my $text = generate_text('1.2.3.4', '5.6.7.8');
    like($text, qr/^1\.2\.3\.4\n5\.6\.7\.8\n$/, 'each IP on its own line');
}

# ===== No header or extra content =====

{
    my $text = generate_text('192.168.1.1');
    unlike($text, qr/SOA|NS|TTL|ORIGIN|generated|dnsbl/i,
        'no header or zone metadata in output');
    is($text, "192.168.1.1\n", 'only the IP and newline');
}

# ===== IPs in original order (not reversed) =====

{
    my $text = generate_text('1.2.3.4');
    like($text, qr/^1\.2\.3\.4$/, 'IP in original order');
    unlike($text, qr/4\.3\.2\.1/, 'no reversed IP');
}

# ===== File atomicity: no leftover temp files =====

{
    generate_text('10.0.0.1');
    my @temps = glob("$outfile.*");
    is(scalar @temps, 0, 'no leftover temp files');
    ok(-f $outfile, 'final output file exists');
}

# ===== Large number of IPs =====

{
    my @ips = map { "10.0." . int($_ / 256) . "." . ($_ % 256) } (0..999);
    my $text = generate_text(@ips);
    my @lines = split /\n/, $text;
    is(scalar @lines, 1000, 'large blocklist: 1000 IPs written');
    is($lines[0], '10.0.0.0', 'large blocklist: first IP correct');
    is($lines[999], '10.0.3.231', 'large blocklist: last IP correct');
}

# ===== File is overwritten on each run =====

{
    generate_text('1.1.1.1', '2.2.2.2');
    my $text1 = do { open my $fh, '<', $outfile; local $/; <$fh> };

    generate_text('3.3.3.3');
    my $text2 = do { open my $fh, '<', $outfile; local $/; <$fh> };

    is($text2, "3.3.3.3\n", 'file overwritten, not appended');
    unlike($text2, qr/1\.1\.1\.1/, 'old content not present');
}

done_testing();
