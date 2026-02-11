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

TestHelper::load_passivetrap();

$Spamikaze::ignorebounces = 1;

# Helper to build a mail with Received headers
sub make_mail {
    my (%opts) = @_;
    my $from = $opts{from} // 'spammer@evil.com';
    my $received_ip = $opts{ip} // '198.51.100.42';
    my $body = $opts{body} // 'Buy cheap pills!';
    my $extra_headers = $opts{extra_headers} // '';
    my $no_received = $opts{no_received} // 0;

    my $mail = '';
    unless ($no_received) {
        $mail .= "Received: from mail.example.com (host [$received_ip]) by mx.local\n";
    }
    $mail .= "From: $from\n";
    $mail .= $extra_headers if $extra_headers;
    $mail .= "Subject: Test\n";
    $mail .= "\n$body\n";
    return $mail;
}

# ============================================================
# from_daemon: ignorebounces as string 'true'
# ============================================================
{
    $Spamikaze::ignorebounces = 'true';
    ok(from_daemon("From: <>\nSubject: test\n"),
        'from_daemon: ignorebounces=true (string) works');
    $Spamikaze::ignorebounces = 1;
}

# ============================================================
# from_daemon: ignorebounces as undef
# ============================================================
{
    $Spamikaze::ignorebounces = undef;
    ok(!from_daemon("From: <>\nSubject: test\n"),
        'from_daemon: ignorebounces=undef returns 0');
    $Spamikaze::ignorebounces = 1;
}

# ============================================================
# process_mail: backup MX IP is skipped
# ============================================================
{
    TestHelper::reset_mocks();
    # BackupMX is configured as 203.0.113.1 in TestHelper
    my $mail = make_mail(ip => '203.0.113.1');
    my $ret = process_mail($mail);
    is($ret, 0, 'backup MX IP returns 0');
    is(scalar @TestHelper::storeip_calls, 0, 'storeip not called for backup MX');
    ok(grep(/backup MX/, @TestHelper::syslog_messages), 'syslog mentions backup MX');
}

# ============================================================
# process_mail: archive_notspam called for daemon mail
# ============================================================
{
    TestHelper::reset_mocks();
    # Track archive_notspam calls
    my @notspam_calls;
    {
        no warnings 'redefine';
        local *Spamikaze::archive_notspam = sub {
            push @notspam_calls, [@_];
        };
        my $mail = make_mail(from => '<>');
        process_mail($mail);
    }
    is(scalar @notspam_calls, 1, 'archive_notspam called for daemon mail');
    like($notspam_calls[0][1], qr/from daemon/, 'archive_notspam reason is "from daemon"');
}

# ============================================================
# process_mail: archive_notspam called for no-IP mail
# ============================================================
{
    TestHelper::reset_mocks();
    my @notspam_calls;
    {
        no warnings 'redefine';
        local *Spamikaze::archive_notspam = sub {
            push @notspam_calls, [@_];
        };
        my $mail = make_mail(no_received => 1);
        process_mail($mail);
    }
    is(scalar @notspam_calls, 1, 'archive_notspam called for no-IP mail');
    like($notspam_calls[0][1], qr/no valid IP/, 'archive_notspam reason is "no valid IP"');
}

# ============================================================
# process_mail: archive_spam called for valid spam
# ============================================================
{
    TestHelper::reset_mocks();
    my @spam_calls;
    {
        no warnings 'redefine';
        local *Spamikaze::archive_spam = sub {
            push @spam_calls, [@_];
        };
        my $mail = make_mail(ip => '198.51.100.42');
        process_mail($mail);
    }
    is(scalar @spam_calls, 1, 'archive_spam called for valid spam');
    is($spam_calls[0][0], '198.51.100.42', 'archive_spam passed correct IP');
    like($spam_calls[0][1], qr/Received:/, 'archive_spam passed the mail body');
}

# ============================================================
# process_mail: ignorebounces=0, daemon mail is processed normally
# ============================================================
{
    TestHelper::reset_mocks();
    $Spamikaze::ignorebounces = 0;
    my $mail = make_mail(from => '<>', ip => '198.51.100.42');
    my $ret = process_mail($mail);
    is($ret, 1, 'with ignorebounces=0, daemon mail is processed as spam');
    is(scalar @TestHelper::storeip_calls, 1, 'storeip called for daemon mail when ignorebounces=0');
    $Spamikaze::ignorebounces = 1;
}

# ============================================================
# process_mail: no From header
# ============================================================
{
    TestHelper::reset_mocks();
    my $mail = "Received: from host [198.51.100.42] by mx.local\n"
             . "Subject: No From header\n"
             . "\nBody\n";
    my $ret = process_mail($mail);
    is($ret, 1, 'mail without From header still processed');
    is($TestHelper::storeip_calls[0][0], '198.51.100.42', 'IP extracted without From header');
    # From field in syslog should be empty
    ok(grep(/from=\s*ip=198\.51\.100\.42/, @TestHelper::syslog_messages),
        'syslog shows empty from with correct IP');
}

# ============================================================
# process_mail: Received with multiline continuation
# ============================================================
{
    TestHelper::reset_mocks();
    # Received headers can span multiple lines with whitespace continuation
    my $mail = "Received: from mail.example.com\n"
             . "\t(host [198.51.100.88]) by mx.local\n"
             . "From: spammer\@evil.com\n"
             . "Subject: Test\n"
             . "\nBody\n";
    my $ret = process_mail($mail);
    # The regex (?=\n[\w\n]|\z) should capture the continuation
    is($ret, 1, 'Received with multiline continuation is processed');
    is($TestHelper::storeip_calls[0][0], '198.51.100.88', 'IP from multiline Received extracted');
}

# ============================================================
# process_mail: Received with no extractable IP
# ============================================================
{
    TestHelper::reset_mocks();
    my $mail = "Received: from localhost by localhost\n"
             . "From: spammer\@evil.com\n"
             . "Subject: Test\n"
             . "\nBody\n";
    my $ret = process_mail($mail);
    is($ret, 0, 'Received without IP returns 0');
    is(scalar @TestHelper::storeip_calls, 0, 'storeip not called for Received without IP');
    ok(grep(/no IP found/, @TestHelper::syslog_messages), 'syslog mentions no IP found');
}

# ============================================================
# process_mail: syslog shows last_ip when skipped
# ============================================================
{
    TestHelper::reset_mocks();
    # Only a localhost IP — last_ip should be set for syslog
    my $mail = make_mail(ip => '127.0.0.1');
    process_mail($mail);
    ok(grep(/ip=127\.0\.0\.1/, @TestHelper::syslog_messages),
        'syslog shows the skipped IP');
}

# ============================================================
# process_mail: all Received headers are whitelisted
# ============================================================
{
    TestHelper::reset_mocks();
    $TestHelper::dns_answers{"42.100.51.198.wl.example.com/A"} = 1;
    $TestHelper::dns_answers{"99.113.0.203.wl.example.com/A"} = 1;
    my $mail = "Received: from host1 [198.51.100.42] by relay\n"
             . "Received: from host2 [203.0.113.99] by mx.local\n"
             . "From: spammer\@evil.com\n"
             . "Subject: Test\n"
             . "\nBody\n";
    my $ret = process_mail($mail);
    is($ret, 0, 'all whitelisted IPs returns 0');
    is(scalar @TestHelper::storeip_calls, 0, 'storeip not called when all whitelisted');
    ok(grep(/whitelisted/, @TestHelper::syslog_messages), 'syslog mentions whitelisted');
}

# ============================================================
# process_mail: first Received whitelisted, second valid — stores second
# ============================================================
{
    TestHelper::reset_mocks();
    $TestHelper::dns_answers{"42.100.51.198.wl.example.com/A"} = 1;
    my $mail = "Received: from host1 [198.51.100.42] by relay\n"
             . "Received: from host2 [203.0.113.99] by mx.local\n"
             . "From: spammer\@evil.com\n"
             . "Subject: Test\n"
             . "\nBody\n";
    my $ret = process_mail($mail);
    is($ret, 1, 'first whitelisted, second valid returns 1');
    is($TestHelper::storeip_calls[0][0], '203.0.113.99',
        'second IP stored after first whitelisted');
}

# ============================================================
# process_mail: multiple 172.x RFC1918 addresses
# ============================================================
{
    TestHelper::reset_mocks();
    my $mail = make_mail(ip => '172.16.0.1');
    my $ret = process_mail($mail);
    is($ret, 0, '172.16.x is filtered');
    is(scalar @TestHelper::storeip_calls, 0, 'storeip not called for 172.16.x');

    TestHelper::reset_mocks();
    $mail = make_mail(ip => '172.31.255.1');
    $ret = process_mail($mail);
    is($ret, 0, '172.31.x is filtered');

    TestHelper::reset_mocks();
    $mail = make_mail(ip => '192.168.1.1');
    $ret = process_mail($mail);
    is($ret, 0, '192.168.x is filtered');
}

# ============================================================
# process_mail: Received header at end of mail (no trailing newline)
# ============================================================
{
    TestHelper::reset_mocks();
    my $mail = "From: spammer\@evil.com\n"
             . "Received: from host [198.51.100.33] by mx.local";
    my $ret = process_mail($mail);
    is($ret, 1, 'Received at end of mail (no trailing newline) is matched');
    is($TestHelper::storeip_calls[0][0], '198.51.100.33',
        'IP from trailing Received extracted');
}

# ============================================================
# process_dir: file contents are read (up to 10000 bytes)
# ============================================================
{
    TestHelper::reset_mocks();
    my $dir = tempdir(CLEANUP => 1);
    # Write a file with a known IP
    my $path = "$dir/testmail";
    open my $fh, '>', $path or die "Cannot write $path: $!";
    print $fh "Received: from host [198.51.100.99] by mx.local\n";
    print $fh "From: test\@example.com\n";
    print $fh "Subject: Test\n";
    print $fh "\nTest body\n";
    close $fh;

    process_dir($dir);
    is(scalar @TestHelper::storeip_calls, 1, 'process_dir: storeip called');
    is($TestHelper::storeip_calls[0][0], '198.51.100.99',
        'process_dir: correct IP from file content');
}

# ============================================================
# received_to_ip: edge cases not in received_to_ip.t
# ============================================================

# IPv4 with port-like suffix in brackets
is(received_to_ip('from host [10.0.0.1]:25 by mx'), '10.0.0.1',
    'received_to_ip: IP with port suffix');

# Mixed bracket and paren
is(received_to_ip('from host (unknown [192.0.2.5]) by mx'), '192.0.2.5',
    'received_to_ip: IP in brackets inside parens');

# Empty string
is(received_to_ip(''), '',
    'received_to_ip: empty string returns empty');

# Only whitespace
is(received_to_ip('   '), '',
    'received_to_ip: whitespace only returns empty');

# IP at very start
is(received_to_ip('[203.0.113.1] by mx'), '203.0.113.1',
    'received_to_ip: IP at start of string');

# ============================================================
# from_daemon: edge cases not in from_daemon.t
# ============================================================

# Return-Path with colon variant
ok(from_daemon("Return-Path <>\\nFrom: test\n"),
    'from_daemon: Return-Path without colon');

# Case insensitivity for MAILER-DAEMON
ok(from_daemon("From: mailer-daemon\@example.com\n"),
    'from_daemon: lowercase mailer-daemon');

# Precedence: list should NOT match (only bulk/junk)
ok(!from_daemon("Precedence: list\n"),
    'from_daemon: Precedence list is not daemon');

# Normal mail with various headers should not match
ok(!from_daemon("From: user\@example.com\nSubject: Hello\nPrecedence: normal\n"),
    'from_daemon: normal mail with Precedence normal');

# Subject with "reply" but not "automatic/automated reply"
ok(!from_daemon("Subject: Re: your reply\n"),
    'from_daemon: Subject with "reply" not matching automated');

done_testing();
