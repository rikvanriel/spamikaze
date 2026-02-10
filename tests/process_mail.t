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

# Ensure ignorebounces is on
$Spamikaze::ignorebounces = 1;

# Helper to build a mail with Received headers
# The Received header must be followed by a line starting with a non-whitespace
# character for the regex in process_mail to work (it uses (?=\n\w) lookahead)
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

# --- Daemon mail: not stored ---
{
    TestHelper::reset_mocks();
    my $mail = make_mail(from => '<>');
    my $ret = process_mail($mail);
    is($ret, 0, 'daemon mail returns 0');
    ok(grep(/from daemon/, @TestHelper::syslog_messages), 'syslog mentions from daemon');
    is(scalar @TestHelper::storeip_calls, 0, 'storeip not called for daemon mail');
}

# --- Normal spam: IP extracted, stored ---
{
    TestHelper::reset_mocks();
    my $mail = make_mail(ip => '198.51.100.42');
    my $ret = process_mail($mail);
    is($ret, 1, 'normal spam returns 1');
    is(scalar @TestHelper::storeip_calls, 1, 'storeip called once');
    is($TestHelper::storeip_calls[0][0], '198.51.100.42', 'storeip called with correct IP');
    ok(grep(/stored in blocklist/, @TestHelper::syslog_messages), 'syslog mentions stored in blocklist');
}

# --- Localhost IP: skipped ---
{
    TestHelper::reset_mocks();
    my $mail = make_mail(ip => '127.0.0.1');
    my $ret = process_mail($mail);
    is($ret, 0, 'localhost IP returns 0');
    is(scalar @TestHelper::storeip_calls, 0, 'storeip not called for localhost');
    ok(grep(/localhost/, @TestHelper::syslog_messages), 'syslog mentions localhost');
}

# --- RFC1918 IP: skipped ---
{
    TestHelper::reset_mocks();
    my $mail = make_mail(ip => '10.0.0.1');
    my $ret = process_mail($mail);
    is($ret, 0, 'RFC1918 IP returns 0');
    is(scalar @TestHelper::storeip_calls, 0, 'storeip not called for RFC1918');
    ok(grep(/RFC1918/, @TestHelper::syslog_messages), 'syslog mentions RFC1918');
}

# --- Whitelisted IP: skipped ---
{
    TestHelper::reset_mocks();
    # Whitelist 198.51.100.42 => reversed is 42.100.51.198
    $TestHelper::dns_answers{"42.100.51.198.wl.example.com/A"} = 1;
    my $mail = make_mail(ip => '198.51.100.42');
    my $ret = process_mail($mail);
    is($ret, 0, 'whitelisted IP returns 0');
    is(scalar @TestHelper::storeip_calls, 0, 'storeip not called for whitelisted IP');
    ok(grep(/whitelisted/, @TestHelper::syslog_messages), 'syslog mentions whitelisted');
}

# --- No Received headers: not stored ---
{
    TestHelper::reset_mocks();
    my $mail = make_mail(no_received => 1);
    my $ret = process_mail($mail);
    is($ret, 0, 'no Received headers returns 0');
    is(scalar @TestHelper::storeip_calls, 0, 'storeip not called without Received');
    ok(grep(/no IP found/, @TestHelper::syslog_messages), 'syslog mentions no IP found');
}

# --- Last Received header (before blank line) is not skipped ---
{
    TestHelper::reset_mocks();
    # Only one Received header, followed by blank line then body
    my $mail = "From: spammer\@evil.com\n"
             . "Received: from host [198.51.100.77] by mx.local\n"
             . "\n"
             . "Spam body\n";
    my $ret = process_mail($mail);
    is($ret, 1, 'last Received header (before body) is matched');
    is($TestHelper::storeip_calls[0][0], '198.51.100.77', 'IP from last Received extracted');
}

# --- Multiple Received headers: first valid non-filtered IP used ---
{
    TestHelper::reset_mocks();
    # First Received has a private IP (will be skipped), second has a public IP
    my $mail = "Received: from internal (host [10.0.0.1]) by relay\n"
             . "Received: from external (host [203.0.113.99]) by mx.local\n"
             . "From: spammer\@evil.com\n"
             . "Subject: Test\n"
             . "\nBuy pills!\n";
    my $ret = process_mail($mail);
    is($ret, 1, 'multi-Received returns 1 for valid IP');
    is($TestHelper::storeip_calls[0][0], '203.0.113.99', 'second Received IP used after first filtered');
}

# --- From header extracted correctly ---
{
    TestHelper::reset_mocks();
    my $mail = make_mail(from => 'Test User <test@example.com>', ip => '198.51.100.1');
    process_mail($mail);
    ok(grep(/Test User/, @TestHelper::syslog_messages), 'From header appears in syslog');
}

# --- storeip called with correct type ---
{
    TestHelper::reset_mocks();
    my $mail = make_mail(ip => '198.51.100.50');
    process_mail($mail);
    is($TestHelper::storeip_calls[0][1], 'received spamtrap mail', 'storeip type is correct');
}

done_testing();
