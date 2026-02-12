#!/usr/bin/perl
#
# End-to-end tests using a real MariaDB/MySQL backend.
# Automatically starts/stops a temporary MariaDB instance.
# Skips if mariadb-install-db is not available (install mariadb-server).
#
# Tests the full pipeline:
#   spam email → process_mail() → storeip() → blocklist
#   plus: get_listed_addresses, get_listing_info, get_latest,
#         expire, remove_from_db, archivemail

use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

our @syslog_messages;

BEGIN {
    # Check for required Perl modules
    for my $mod (qw(DBD::mysql Config::IniFiles Try::Tiny)) {
        eval "require $mod";
        if ($@) {
            require Test::More;
            Test::More::plan(skip_all => "$mod not installed");
        }
    }

    # --- Mock Sys::Syslog (capture messages instead of real syslog) ---

    $INC{'Sys/Syslog.pm'} = 'mocked';
    package Sys::Syslog;
    use Exporter 'import';
    our @EXPORT_OK = qw(openlog syslog closelog);
    our %EXPORT_TAGS = (
        standard => [qw(openlog syslog closelog)],
        macros   => [],
    );
    use constant {
        LOG_EMERG   => 0, LOG_ALERT   => 1, LOG_CRIT    => 2,
        LOG_ERR     => 3, LOG_WARNING => 4, LOG_NOTICE  => 5,
        LOG_INFO    => 6, LOG_DEBUG   => 7, LOG_MAIL    => 16,
    };
    push @EXPORT_OK, qw(LOG_EMERG LOG_ALERT LOG_CRIT LOG_ERR LOG_WARNING
                        LOG_NOTICE LOG_INFO LOG_DEBUG LOG_MAIL);
    $EXPORT_TAGS{macros} = [qw(LOG_EMERG LOG_ALERT LOG_CRIT LOG_ERR
                               LOG_WARNING LOG_NOTICE LOG_INFO LOG_DEBUG LOG_MAIL)];
    sub openlog  { return 1 }
    sub closelog { return 1 }
    sub syslog {
        my ($priority, $format, @args) = @_;
        my $msg = defined $format ? sprintf($format, @args) : '';
        push @main::syslog_messages, $msg;
    }
    package main;

    # --- Mock Net::DNS (no real DNS lookups in tests) ---

    $INC{'Net/DNS.pm'} = 'mocked';
    $INC{'Net/DNS/Resolver.pm'} = 'mocked';
    package Net::DNS;
    package Net::DNS::Resolver;
    sub new   { return bless {}, shift }
    sub query { return undef }
    package main;

    # --- Create config for MySQL_3 ---
    # DBConnect is overridden below to use the test socket directly,
    # so Host/Port here are placeholders.  Schema = MySQL_3 is the
    # important part — it makes $Spamikaze::db a MySQL_3 object.

    my $tmpdir = File::Temp::tempdir(CLEANUP => 1);
    File::Path::make_path("$tmpdir/.spamikaze");
    my $cfgfile = "$tmpdir/.spamikaze/config";

    open my $fh, '>', $cfgfile or die "Cannot write $cfgfile: $!";
    print $fh <<"ENDCFG";
[Database]
Host = localhost
Port = 3306
Type = mysql
Username = root
Password =
Name = psbl
Schema = MySQL_3
EmailInDb = 1

[Mail]
BackupMX = 203.0.113.1
WhitelistZones =
IgnoreRFC1918 = 1
IgnoreBounces = 1

[Expire]
FirstTime = 1
ExtraTime = 1
MaxSpamPerIp = 10

[DNSBL]
Domain = bl.example.com
ZoneFile = /tmp/zone
UrlBase = http://example.com
Address = 127.0.0.2
TTL = 3600
PrimaryNS = ns1.example.com
SecondaryNSes = ns2.example.com

[Web]
Header =
Footer =
ListName = test
ListingURL = http://example.com
RemovalURL = http://example.com
ListLatest = 10
SiteURL = http://example.com

[NNTP]
Enabled = 0
Server =
Groupbase =
From =

[Pipe]
Program =
ENDCFG
    close $fh;
    $ENV{HOME} = $tmpdir;
}

# --- Load real Spamikaze (uses test config + real MySQL_3) ---

use lib "$FindBin::Bin/../scripts";
use Spamikaze;
use DBI;
use Test::More;

# Override DBConnect to use our test socket.
# Spamikaze::DBConnect builds a DSN without mysql_socket, so we
# replace it to connect to the temporary MariaDB instance.
my $MYSQL_SOCKET = "$FindBin::Bin/db/mysql/socket/mysql.sock";
{
    no warnings 'redefine';
    *Spamikaze::DBConnect = sub {
        return DBI->connect(
            "dbi:mysql:database=psbl;mysql_socket=$MYSQL_SOCKET",
            "root", "", { RaiseError => 1, AutoCommit => 0 }
        );
    };
}

my $SETUP_SCRIPT = "$FindBin::Bin/db/setup-mysql.sh";
my $we_started_mysql = 0;

# Start MariaDB if not already running
unless (-e $MYSQL_SOCKET) {
    my $output = `$SETUP_SCRIPT start 2>&1`;
    if ($? != 0) {
        # Stale state from a previous crash — clean up and retry
        system($SETUP_SCRIPT, "stop");
        $output = `$SETUP_SCRIPT start 2>&1`;
        if ($? != 0) {
            plan skip_all => 'Could not start MariaDB test instance'
                . ' (is mariadb-server installed?)';
        }
    }
    $we_started_mysql = 1;
}

END {
    if ($we_started_mysql) {
        system($SETUP_SCRIPT, "stop");
    }
}

# Verify database connectivity
{
    my $dbh = eval { Spamikaze::DBConnect() };
    unless ($dbh) {
        plan skip_all => 'Cannot connect to test MariaDB: '
            . ($@ || 'unknown error');
    }
    $dbh->disconnect();
}

# Load passivetrap.pl functions (process_mail, from_daemon, etc.)
{
    my $script = "$FindBin::Bin/../scripts/passivetrap.pl";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    $code =~ s/^\&main;\s*$//m;
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use Sys::Syslog[^;]*;\s*$//m;
    $code =~ s/^use Net::DNS;\s*$//m;
    $code =~ s/^use FindBin;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;
    $code =~ s/^use POSIX[^;]*;\s*$//m;

    my $wrapped = "package main;\n"
                . "use strict;\nuse warnings;\n"
                . "use POSIX \"sys_wait_h\";\n"
                . "sub syslog { Sys::Syslog::syslog(\@_) }\n"
                . "sub LOG_INFO () { 6 }\n"
                . $code;

    eval $wrapped;
    die "Failed to load passivetrap.pl: $@" if $@;
}

# ===== Helpers =====

sub clear_db {
    my $dbh = Spamikaze::DBConnect();
    $dbh->do("DELETE FROM emails");
    $dbh->do("DELETE FROM ipevents");
    $dbh->do("DELETE FROM blocklist");
    $dbh->commit();
    $dbh->disconnect();
}

sub count_rows {
    my ($table) = @_;
    my $dbh = Spamikaze::DBConnect();
    my $sth = $dbh->prepare("SELECT COUNT(*) FROM $table");
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    return $count;
}

sub get_blocklist_ip {
    my ($ip) = @_;
    my $dbh = Spamikaze::DBConnect();
    my $sth = $dbh->prepare("SELECT ip, expires FROM blocklist WHERE ip = ?");
    $sth->execute($ip);
    my $row = $sth->fetchrow_hashref();
    $sth->finish();
    $dbh->disconnect();
    return $row;
}

sub get_emails_for_ip {
    my ($ip) = @_;
    my $dbh = Spamikaze::DBConnect();
    my $sth = $dbh->prepare(
        'SELECT ip, spam, email FROM emails WHERE ip = ? ORDER BY `time`');
    $sth->execute($ip);
    my @rows;
    while (my $row = $sth->fetchrow_hashref()) {
        push @rows, $row;
    }
    $sth->finish();
    $dbh->disconnect();
    return @rows;
}

sub set_expiry_past {
    my ($ip) = @_;
    my $dbh = Spamikaze::DBConnect();
    $dbh->do("UPDATE blocklist SET expires = DATE_SUB(NOW(), INTERVAL 1 HOUR)"
           . " WHERE ip = ?", undef, $ip);
    $dbh->commit();
    $dbh->disconnect();
}

sub make_spam_mail {
    my (%opts) = @_;
    my $ip   = $opts{ip}   || '198.51.100.42';
    my $from = $opts{from} || 'spammer@example.com';
    my $subj = $opts{subject} || 'Buy stuff';
    my $body = $opts{body} || 'This is spam content.';
    my $extra_received = $opts{extra_received} || '';

    return "${extra_received}Received: from sender.example.com (sender [$ip])"
         . " by trap.example.com\n"
         . "From: $from\n"
         . "Subject: $subj\n"
         . "\n"
         . "$body\n";
}

# ===== Schema verification =====

{
    clear_db();
    is(count_rows('eventtypes'), 5, 'schema: eventtypes has 5 seed rows');
}

# ===== storeip =====

{
    clear_db();

    $Spamikaze::db->storeip('198.51.100.42', 'received spamtrap mail');

    my $row = get_blocklist_ip('198.51.100.42');
    ok(defined $row, 'storeip: IP is in blocklist');
    is($row->{ip}, '198.51.100.42', 'storeip: correct IP stored');

    # Verify ipevent was logged
    my $dbh = Spamikaze::DBConnect();
    my $sth = $dbh->prepare(
        "SELECT e.eventtext FROM ipevents i"
      . " JOIN eventtypes e ON i.eventid = e.id"
      . " WHERE i.ip = ?");
    $sth->execute('198.51.100.42');
    my ($eventtext) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    is($eventtext, 'received spamtrap mail', 'storeip: ipevent logged correctly');
}

# ===== storeip upsert (same IP twice) =====

{
    clear_db();

    $Spamikaze::db->storeip('198.51.100.42', 'received spamtrap mail');
    is(count_rows('blocklist'), 1, 'upsert: one row after first store');

    # Store same IP again — ON DUPLICATE KEY UPDATE should not duplicate
    sleep(1);
    $Spamikaze::db->storeip('198.51.100.42', 'received spamtrap mail');

    is(count_rows('blocklist'), 1, 'upsert: still one row after second store');

    # Two events should be logged
    my $dbh = Spamikaze::DBConnect();
    my $sth = $dbh->prepare(
        "SELECT COUNT(*) FROM ipevents WHERE ip = ?");
    $sth->execute('198.51.100.42');
    my ($event_count) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    is($event_count, 2, 'upsert: two events logged');
}

# ===== archivemail =====

{
    clear_db();

    $Spamikaze::db->archivemail('10.0.0.1', 1, 'spam email body here');

    my @emails = get_emails_for_ip('10.0.0.1');
    is(scalar @emails, 1, 'archivemail: one email stored');
    ok($emails[0]->{spam}, 'archivemail: marked as spam');
    like($emails[0]->{email}, qr/spam email body here/,
        'archivemail: content stored correctly');
}

# ===== process_mail end-to-end =====

{
    clear_db();
    @syslog_messages = ();

    my $mail = make_spam_mail(
        ip   => '198.51.100.42',
        from => 'spammer@evil.com',
        body => 'Buy our product now!',
    );
    my $result = process_mail($mail);

    is($result, 1, 'process_mail: returns 1 for stored spam');

    # Verify IP in blocklist
    ok(defined get_blocklist_ip('198.51.100.42'),
        'process_mail: IP stored in blocklist');

    # Verify event via get_listing_info
    my ($listed, %iplog) = $Spamikaze::db->get_listing_info('198.51.100.42');
    is($listed, 1, 'process_mail: IP is listed');
    is(scalar keys %iplog, 1, 'process_mail: one event logged');
    my ($event_text) = values %iplog;
    is($event_text, 'received spamtrap mail', 'process_mail: correct event type');

    # Verify email archived (EmailInDb = 1)
    my @emails = get_emails_for_ip('198.51.100.42');
    is(scalar @emails, 1, 'process_mail: email archived in DB');
    ok($emails[0]->{spam}, 'process_mail: email marked as spam');
    like($emails[0]->{email}, qr/spammer\@evil\.com/,
        'process_mail: archived email contains From');

    # Verify syslog
    ok(grep(/stored in blocklist/, @syslog_messages),
        'process_mail: syslog says "stored in blocklist"');
    ok(grep(/198\.51\.100\.42/, @syslog_messages),
        'process_mail: syslog contains the IP');
}

# ===== process_mail: daemon/bounce mail not stored =====

{
    clear_db();
    @syslog_messages = ();

    my $bounce = "Received: from bouncer.example.com (bouncer [198.51.100.42])"
               . " by trap.example.com\n"
               . "From: <>\n"
               . "Subject: Delivery failure\n"
               . "\n"
               . "Your message could not be delivered.\n";

    my $result = process_mail($bounce);

    is($result, 0, 'daemon mail: returns 0');
    is(count_rows('blocklist'), 0, 'daemon mail: nothing in blocklist');
    ok(grep(/from daemon/, @syslog_messages),
        'daemon mail: syslog says "from daemon"');
}

# ===== process_mail: localhost not stored =====

{
    clear_db();
    @syslog_messages = ();

    my $mail = make_spam_mail(ip => '127.0.0.1');
    my $result = process_mail($mail);

    is($result, 0, 'localhost: returns 0');
    is(count_rows('blocklist'), 0, 'localhost: nothing in blocklist');
    ok(grep(/localhost/, @syslog_messages),
        'localhost: syslog mentions localhost');
}

# ===== process_mail: RFC1918 not stored =====

{
    clear_db();
    @syslog_messages = ();

    my $mail = make_spam_mail(ip => '10.0.0.1');
    my $result = process_mail($mail);

    is($result, 0, 'RFC1918: returns 0');
    is(count_rows('blocklist'), 0, 'RFC1918: nothing in blocklist');
    ok(grep(/RFC1918/, @syslog_messages),
        'RFC1918: syslog mentions RFC1918');
}

# ===== process_mail: backup MX skipped, real sender stored =====

{
    clear_db();
    @syslog_messages = ();

    # First Received has the backup MX IP (203.0.113.1), second has the sender
    my $mail = "Received: from mx.example.com (mx [203.0.113.1])"
             . " by trap.example.com\n"
             . "Received: from sender.example.com (sender [198.51.100.99])"
             . " by mx.example.com\n"
             . "From: spammer\@example.com\n"
             . "Subject: Spam via backup MX\n"
             . "\n"
             . "Spam body\n";

    my $result = process_mail($mail);

    is($result, 1, 'backup MX: returns 1');
    ok(!defined get_blocklist_ip('203.0.113.1'),
        'backup MX: backup MX IP not stored');
    ok(defined get_blocklist_ip('198.51.100.99'),
        'backup MX: real sender IP stored');
}

# ===== get_listed_addresses =====

{
    clear_db();

    $Spamikaze::db->storeip('198.51.100.1', 'received spamtrap mail');
    $Spamikaze::db->storeip('198.51.100.2', 'received spamtrap mail');
    $Spamikaze::db->storeip('203.0.113.50', 'received spamtrap mail');

    my @addrs = $Spamikaze::db->get_listed_addresses();
    is(scalar @addrs, 3, 'get_listed_addresses: returns 3 IPs');

    my $joined = join(',', sort @addrs);
    like($joined, qr/198\.51\.100\.1\b/, 'get_listed_addresses: has 198.51.100.1');
    like($joined, qr/198\.51\.100\.2\b/, 'get_listed_addresses: has 198.51.100.2');
    like($joined, qr/203\.0\.113\.50\b/, 'get_listed_addresses: has 203.0.113.50');
}

# ===== get_listing_info =====

{
    clear_db();

    # Store and verify listed
    $Spamikaze::db->storeip('198.51.100.42', 'received spamtrap mail');

    my ($listed, %iplog) = $Spamikaze::db->get_listing_info('198.51.100.42');
    is($listed, 1, 'get_listing_info: IP is listed');
    is(scalar keys %iplog, 1, 'get_listing_info: one event');
    my ($evt) = values %iplog;
    is($evt, 'received spamtrap mail', 'get_listing_info: correct event text');

    # Non-existent IP
    my ($listed2, %iplog2) = $Spamikaze::db->get_listing_info('192.0.2.99');
    is($listed2, 0, 'get_listing_info: unlisted IP returns 0');
    is(scalar keys %iplog2, 0, 'get_listing_info: no events for unlisted IP');
}

# ===== get_latest =====

{
    clear_db();

    $Spamikaze::db->storeip('198.51.100.1', 'received spamtrap mail');
    sleep(1);  # ensure distinct timestamps for ordering
    $Spamikaze::db->storeip('198.51.100.2', 'major smtp violation');

    my %events = $Spamikaze::db->get_latest(10);
    is(scalar keys %events, 2, 'get_latest: returns 2 events');

    my @vals = values %events;
    ok(grep(/198\.51\.100\.1.*received spamtrap mail/, @vals),
        'get_latest: contains first event');
    ok(grep(/198\.51\.100\.2.*major smtp violation/, @vals),
        'get_latest: contains second event');

    # Test LIMIT
    my %limited = $Spamikaze::db->get_latest(1);
    is(scalar keys %limited, 1, 'get_latest: LIMIT 1 returns 1 event');
    my ($latest_val) = values %limited;
    like($latest_val, qr/198\.51\.100\.2/,
        'get_latest: most recent event first');
}

# ===== remove_from_db =====

{
    clear_db();

    $Spamikaze::db->storeip('198.51.100.42', 'received spamtrap mail');
    is(count_rows('blocklist'), 1, 'remove: IP stored first');

    my $rows = $Spamikaze::db->remove_from_db('198.51.100.42');
    cmp_ok($rows, '==', 1, 'remove_from_db: returns 1 row affected');
    is(count_rows('blocklist'), 0, 'remove_from_db: blocklist is empty');

    # Verify "removed through website" event was logged
    my ($listed, %iplog) = $Spamikaze::db->get_listing_info('198.51.100.42');
    is($listed, 0, 'remove_from_db: IP no longer listed');
    my @events = values %iplog;
    ok(grep(/removed through website/, @events),
        'remove_from_db: removal event logged');
}

# ===== remove_from_db: non-existent IP =====

{
    clear_db();

    my $rows = $Spamikaze::db->remove_from_db('192.0.2.99');
    cmp_ok($rows, '==', 0, 'remove non-existent: returns 0 rows');
    is(count_rows('ipevents'), 0,
        'remove non-existent: no event logged');
}

# ===== expire =====

{
    clear_db();

    $Spamikaze::db->storeip('198.51.100.42', 'received spamtrap mail');
    $Spamikaze::db->storeip('198.51.100.43', 'received spamtrap mail');
    is(count_rows('blocklist'), 2, 'expire: 2 IPs stored');

    # Set one IP to expired
    set_expiry_past('198.51.100.42');

    $Spamikaze::db->expire();

    is(count_rows('blocklist'), 1, 'expire: 1 IP remaining');
    ok(!defined get_blocklist_ip('198.51.100.42'),
        'expire: expired IP removed');
    ok(defined get_blocklist_ip('198.51.100.43'),
        'expire: non-expired IP preserved');

    # Events should NOT be deleted by expire
    is(count_rows('ipevents'), 2, 'expire: ipevents preserved');
}

# ===== Full lifecycle =====

{
    clear_db();
    @syslog_messages = ();

    # 1. Process first spam
    my $mail1 = make_spam_mail(
        ip   => '198.51.100.42',
        from => 'spammer1@evil.com',
    );
    process_mail($mail1);

    my ($listed1, %log1) = $Spamikaze::db->get_listing_info('198.51.100.42');
    is($listed1, 1, 'lifecycle: listed after first spam');
    is(scalar keys %log1, 1, 'lifecycle: one event after first spam');

    # 2. Process second spam from same IP (upsert)
    sleep(1);
    my $mail2 = make_spam_mail(
        ip   => '198.51.100.42',
        from => 'spammer2@evil.com',
    );
    process_mail($mail2);

    my ($listed2, %log2) = $Spamikaze::db->get_listing_info('198.51.100.42');
    is($listed2, 1, 'lifecycle: still listed after second spam');
    is(scalar keys %log2, 2, 'lifecycle: two events after second spam');
    is(count_rows('blocklist'), 1, 'lifecycle: one blocklist row (upsert)');
    is(count_rows('emails'), 2, 'lifecycle: two emails archived');

    # 3. Expire the entry
    set_expiry_past('198.51.100.42');
    $Spamikaze::db->expire();

    my ($listed3, %log3) = $Spamikaze::db->get_listing_info('198.51.100.42');
    is($listed3, 0, 'lifecycle: not listed after expire');
    is(scalar keys %log3, 2, 'lifecycle: events preserved after expire');

    # 4. Process third spam — IP gets re-listed
    sleep(1);
    my $mail3 = make_spam_mail(
        ip   => '198.51.100.42',
        from => 'spammer3@evil.com',
    );
    process_mail($mail3);

    my ($listed4, %log4) = $Spamikaze::db->get_listing_info('198.51.100.42');
    is($listed4, 1, 'lifecycle: re-listed after new spam');
    is(scalar keys %log4, 3, 'lifecycle: three total events');

    # 5. Manual removal
    sleep(1);  # ensure distinct second for MySQL NOW() timestamp
    my $removed = $Spamikaze::db->remove_from_db('198.51.100.42');
    cmp_ok($removed, '==', 1, 'lifecycle: remove_from_db returns 1');

    my ($listed5, %log5) = $Spamikaze::db->get_listing_info('198.51.100.42');
    is($listed5, 0, 'lifecycle: not listed after removal');
    is(scalar keys %log5, 4, 'lifecycle: four events (3 spam + 1 removal)');

    # 6. Verify get_latest shows the full history
    my %latest = $Spamikaze::db->get_latest(10);
    ok(scalar keys %latest >= 4,
        'lifecycle: get_latest shows at least 4 events');
    my @vals = values %latest;
    ok(grep(/removed through website/, @vals),
        'lifecycle: get_latest includes removal event');
}

# ===== Cleanup =====

clear_db();
done_testing();
