#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

TestHelper::load_passivetrap();

$Spamikaze::ignorebounces = 1;

# Helper to write a spam email file
sub write_mail_file {
    my ($dir, $filename, $ip) = @_;
    $ip //= '198.51.100.42';
    my $path = "$dir/$filename";
    open my $fh, '>', $path or die "Cannot write $path: $!";
    print $fh "Received: from host [$ip] by mx.local\n";
    print $fh "From: spammer\@evil.com\n";
    print $fh "Subject: Test\n";
    print $fh "\nSpam body\n";
    close $fh;
    return $path;
}

# --- Processes regular files ---
{
    TestHelper::reset_mocks();
    my $dir = tempdir(CLEANUP => 1);
    write_mail_file($dir, 'msg001', '198.51.100.1');
    write_mail_file($dir, 'msg002', '198.51.100.2');
    my $count = process_dir($dir);
    is($count, 2, 'processes 2 regular files');
    is(scalar @TestHelper::storeip_calls, 2, 'storeip called for each file');
}

# --- Skips directories ---
{
    TestHelper::reset_mocks();
    my $dir = tempdir(CLEANUP => 1);
    write_mail_file($dir, 'msg001');
    make_path("$dir/subdir");
    my $count = process_dir($dir);
    is($count, 1, 'skips subdirectory');
}

# --- Skips dotfiles ---
{
    TestHelper::reset_mocks();
    my $dir = tempdir(CLEANUP => 1);
    write_mail_file($dir, 'msg001');
    write_mail_file($dir, '.hidden');
    my $count = process_dir($dir);
    is($count, 1, 'skips dotfile');
}

# --- Skips temp files ---
{
    TestHelper::reset_mocks();
    my $dir = tempdir(CLEANUP => 1);
    write_mail_file($dir, 'msg001');
    write_mail_file($dir, 'tmp12345');
    write_mail_file($dir, 'temp6789');
    my $count = process_dir($dir);
    is($count, 1, 'skips tmp/temp files');
}

# --- Returns count of processed files ---
{
    TestHelper::reset_mocks();
    my $dir = tempdir(CLEANUP => 1);
    write_mail_file($dir, "msg$_") for (1..5);
    my $count = process_dir($dir);
    is($count, 5, 'returns correct count');
}

# --- Empty directory ---
{
    TestHelper::reset_mocks();
    my $dir = tempdir(CLEANUP => 1);
    my $count = process_dir($dir);
    is($count, 0, 'empty directory returns 0');
}

# --- Files are deleted after processing ---
{
    TestHelper::reset_mocks();
    my $dir = tempdir(CLEANUP => 1);
    write_mail_file($dir, 'msg001');
    process_dir($dir);
    ok(! -f "$dir/msg001", 'file deleted after processing');
}

# --- Stops at 50 files (returns > 50 count) ---
{
    TestHelper::reset_mocks();
    my $dir = tempdir(CLEANUP => 1);
    write_mail_file($dir, sprintf("msg%03d", $_)) for (1..60);
    my $count = process_dir($dir);
    ok($count > 50, "stops processing after 50 files (count=$count)");
    # Some files should remain unprocessed
    opendir(my $dh, $dir);
    my @remaining = grep { -f "$dir/$_" } readdir($dh);
    closedir($dh);
    ok(scalar @remaining > 0, 'some files remain unprocessed after 50 limit');
}

done_testing();
