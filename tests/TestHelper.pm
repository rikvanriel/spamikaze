package TestHelper;
use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

# Syslog capture
our @syslog_messages;

# DNS mock control
our %dns_answers;  # "$name/$type" => 1 means answer found

# DB mock
our @storeip_calls;
our @archivemail_calls;
our @commit_calls;
our @disconnect_calls;
our @listed_addresses;  # controls get_listed_addresses() return value

sub reset_mocks {
    @syslog_messages = ();
    @storeip_calls = ();
    @archivemail_calls = ();
    @commit_calls = ();
    @disconnect_calls = ();
    %dns_answers = ();
    @listed_addresses = ();
}

# --- Mock Config::IniFiles before anything loads it ---
BEGIN {
    my %cfg_data;

    my $defaults = {
        'Database' => {
            'Host'     => 'localhost',
            'Port'     => '5432',
            'Type'     => 'Pg',
            'Username' => 'test',
            'Password' => 'test',
            'Name'     => 'testdb',
            'Schema'   => 'PgSQL_3',
            'EmailInDb' => 0,
        },
        'Mail' => {
            'BackupMX'       => '203.0.113.1',
            'WhitelistZones' => 'wl.example.com wl2.example.com',
            'IgnoreRFC1918'  => 1,
            'IgnoreBounces'  => 1,
        },
        'Expire' => {
            'FirstTime'    => 24,
            'ExtraTime'    => 12,
            'MaxSpamPerIp' => 10,
        },
        'DNSBL' => {
            'Domain'        => 'bl.example.com',
            'ZoneFile'      => '/tmp/zone',
            'UrlBase'       => 'http://example.com',
            'Address'       => '127.0.0.2',
            'TTL'           => 3600,
            'PrimaryNS'     => 'ns1.example.com',
            'SecondaryNSes' => 'ns2.example.com',
        },
        'Web' => {
            'Header'     => '',
            'Footer'     => '',
            'ListName'   => 'test',
            'ListingURL' => 'http://example.com',
            'RemovalURL' => 'http://example.com',
            'ListLatest' => 10,
            'SiteURL'    => 'http://example.com',
        },
        'NNTP' => {
            'Enabled'   => 0,
            'Server'    => '',
            'Groupbase' => '',
            'From'      => '',
        },
        'Pipe' => {
            'Program' => '',
        },
    };

    %cfg_data = %$defaults;

    # Create Config::IniFiles mock
    $INC{'Config/IniFiles.pm'} = 'mocked';
    package Config::IniFiles;
    sub new {
        my ($class, %args) = @_;
        return bless {}, $class;
    }
    sub val {
        my ($self, $section, $key) = @_;
        return $cfg_data{$section}{$key} // '';
    }
    package TestHelper;

    # Create mock DBI
    $INC{'DBI.pm'} = 'mocked';
    package DBI;
    our $VERSION = '1.0';
    sub connect {
        my $mock_dbh = bless {}, 'DBI::db::Mock';
        return $mock_dbh;
    }
    package DBI::db::Mock;
    sub prepare { return bless {}, 'DBI::st::Mock' }
    sub do { return 1 }
    sub commit { push @TestHelper::commit_calls, 1 }
    sub disconnect { push @TestHelper::disconnect_calls, 1 }
    sub err { return 0 }
    package DBI::st::Mock;
    sub execute { return 1 }
    sub fetch { return undef }
    sub finish { return 1 }
    sub bind_columns { return 1 }
    sub rows { return 0 }
    package TestHelper;

    # Mock Sys::Syslog
    $INC{'Sys/Syslog.pm'} = 'mocked';
    package Sys::Syslog;
    use Exporter 'import';
    our @EXPORT_OK = qw(openlog syslog closelog);
    our %EXPORT_TAGS = (
        standard => [qw(openlog syslog closelog)],
        macros   => [],
    );
    # Define LOG_* constants
    use constant {
        LOG_EMERG   => 0,
        LOG_ALERT   => 1,
        LOG_CRIT    => 2,
        LOG_ERR     => 3,
        LOG_WARNING => 4,
        LOG_NOTICE  => 5,
        LOG_INFO    => 6,
        LOG_DEBUG   => 7,
        LOG_MAIL    => 16,
    };
    push @EXPORT_OK, qw(LOG_EMERG LOG_ALERT LOG_CRIT LOG_ERR LOG_WARNING LOG_NOTICE LOG_INFO LOG_DEBUG LOG_MAIL);
    $EXPORT_TAGS{macros} = [qw(LOG_EMERG LOG_ALERT LOG_CRIT LOG_ERR LOG_WARNING LOG_NOTICE LOG_INFO LOG_DEBUG LOG_MAIL)];

    sub openlog { return 1 }
    sub closelog { return 1 }
    sub syslog {
        my ($priority, $format, @args) = @_;
        my $msg = defined $format ? sprintf($format, @args) : '';
        push @TestHelper::syslog_messages, $msg;
    }
    package TestHelper;

    # Mock Net::DNS::Resolver
    $INC{'Net/DNS.pm'} = 'mocked';
    $INC{'Net/DNS/Resolver.pm'} = 'mocked';
    package Net::DNS;
    # nothing needed, just prevent loading
    package Net::DNS::Resolver;
    sub new {
        my ($class) = @_;
        return bless {}, $class;
    }
    sub query {
        my ($self, $name, $type) = @_;
        my $key = "$name/$type";
        if ($TestHelper::dns_answers{$key}) {
            return bless {}, 'Net::DNS::Packet::Mock';
        }
        return undef;
    }
    package Net::DNS::Packet::Mock;
    sub answer { return () }
    package TestHelper;

    # Set HOME to a temp dir with a config file so Spamikaze::ConfigLoad works
    my $tmpdir = tempdir(CLEANUP => 1);
    my $cfgdir = "$tmpdir/.spamikaze";
    make_path($cfgdir);
    my $cfgfile = "$cfgdir/config";
    open my $fh, '>', $cfgfile or die "Cannot write $cfgfile: $!";
    print $fh <<'ENDCFG';
[Database]
Host = localhost
Port = 5432
Type = Pg
Username = test
Password = test
Name = testdb
Schema = PgSQL_3
EmailInDb = 0

[Mail]
BackupMX = 203.0.113.1
WhitelistZones = wl.example.com wl2.example.com
IgnoreRFC1918 = 1
IgnoreBounces = 1

[Expire]
FirstTime = 24
ExtraTime = 12
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

    # Mock the DB schema modules to prevent loading issues
    $INC{'Spamikaze/PgSQL_3.pm'} = 'mocked';
    $INC{'Spamikaze/MySQL_2.pm'} = 'mocked';

    package Spamikaze::PgSQL_3;
    sub new {
        my ($class) = @_;
        return bless {}, $class;
    }
    sub storeip {
        my ($self, $ip, $type) = @_;
        push @TestHelper::storeip_calls, [$ip, $type];
    }
    sub archivemail {
        my ($self, $ip, $isspam, $mail) = @_;
        push @TestHelper::archivemail_calls, [$ip, $isspam, $mail];
    }
    sub get_listed_addresses {
        return @TestHelper::listed_addresses;
    }
    package Spamikaze::MySQL_2;
    sub new {
        my ($class) = @_;
        return bless {}, $class;
    }
    sub storeip {
        my ($self, $ip, $type) = @_;
        push @TestHelper::storeip_calls, [$ip, $type];
    }
    sub archivemail {
        my ($self, $ip, $isspam, $mail) = @_;
        push @TestHelper::archivemail_calls, [$ip, $isspam, $mail];
    }
    sub get_listed_addresses {
        return @TestHelper::listed_addresses;
    }
    package TestHelper;
}

# Load passivetrap.pl functions into the caller's namespace
sub load_passivetrap {
    my $script = "$FindBin::Bin/../scripts/passivetrap.pl";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    # Remove the &main; call at the end so it doesn't execute
    $code =~ s/^\&main;\s*$//m;

    # Remove use statements that would conflict with our mocks
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use Sys::Syslog[^;]*;\s*$//m;
    $code =~ s/^use Net::DNS;\s*$//m;
    $code =~ s/^use FindBin;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;
    $code =~ s/^use POSIX[^;]*;\s*$//m;

    # Wrap in caller's package
    my $caller = caller;
    my $wrapped = "package $caller;\n"
                . "use strict;\nuse warnings;\n"
                . "use POSIX \"sys_wait_h\";\n"
                . "# Import syslog functions\n"
                . "sub syslog { Sys::Syslog::syslog(\@_) }\n"
                . "sub LOG_INFO () { 6 }\n"
                . $code;

    eval $wrapped;
    die "Failed to load passivetrap.pl: $@" if $@;
}

# Load named.pl functions into the caller's namespace
sub load_named {
    my $script = "$FindBin::Bin/../scripts/named.pl";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    # Remove the &main; call at the end
    $code =~ s/^\&main;\s*$//m;

    # Remove use statements that conflict with our mocks
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use FindBin;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;

    # Convert lexical variables to package variables so tests can override them
    $code =~ s/^my \$dnsbl_location/our \$dnsbl_location/m;
    $code =~ s/^my \$dnsbl_url_base/our \$dnsbl_url_base/m;
    $code =~ s/^my \$ttl/our \$ttl/m;
    $code =~ s/^my \$dnsbl_a/our \$dnsbl_a/m;
    $code =~ s/^my \$dnsbl_txt/our \$dnsbl_txt/m;
    $code =~ s/^my \$zone_header/our \$zone_header/m;

    # Wrap in caller's package
    my $caller = caller;
    my $wrapped = "package $caller;\n"
                . "use strict;\nuse warnings;\n"
                . $code;

    eval $wrapped;
    die "Failed to load named.pl: $@" if $@;
}

# Load rbldnsd.pl functions into the caller's namespace
sub load_rbldnsd {
    my $script = "$FindBin::Bin/../scripts/rbldnsd.pl";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    # Remove the &main; call at the end
    $code =~ s/^\&main;\s*$//m;

    # Remove use statements that conflict with our mocks
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use FindBin;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;

    # Convert lexical variables to package variables so tests can override them
    $code =~ s/^my \$zone_header/our \$zone_header/m;

    # Wrap in caller's package
    my $caller = caller;
    my $wrapped = "package $caller;\n"
                . "use strict;\nuse warnings;\n"
                . $code;

    eval $wrapped;
    die "Failed to load rbldnsd.pl: $@" if $@;
}

# Load text.pl functions into the caller's namespace
sub load_text {
    my $script = "$FindBin::Bin/../scripts/text.pl";
    open my $fh, '<', $script or die "Cannot read $script: $!";
    my $code = do { local $/; <$fh> };
    close $fh;

    $code =~ s/^\&main;\s*$//m;
    $code =~ s/^use Spamikaze;\s*$//m;
    $code =~ s/^use FindBin;\s*$//m;
    $code =~ s/^use lib[^;]*;\s*$//m;

    my $caller = caller;
    my $wrapped = "package $caller;\n"
                . "use strict;\nuse warnings;\n"
                . $code;

    eval $wrapped;
    die "Failed to load text.pl: $@" if $@;
}

use FindBin;

1;
