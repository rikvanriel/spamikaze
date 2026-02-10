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

# Load the real Pipe.pm (not mocked by TestHelper)
require Spamikaze::Pipe;

my $tmpdir = tempdir(CLEANUP => 1);

# ===== new() =====

{
    my $pipe = Spamikaze::Pipe->new();
    isa_ok($pipe, 'Spamikaze::Pipe', 'new() returns blessed object');
}

# ===== pipe_mail: delivers content to program =====

{
    my $outfile = "$tmpdir/output1.txt";
    $Spamikaze::pipe_program = "cat > $outfile";

    my $pipe = Spamikaze::Pipe->new();
    my $mail = "From: test\@example.com\nSubject: Hello\n\nBody text\n";
    $pipe->pipe_mail($mail);

    ok(-f $outfile, 'pipe_mail: output file created');
    open my $fh, '<', $outfile or die "Cannot read $outfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is($content, $mail, 'pipe_mail: full mail content delivered');
}

# ===== pipe_mail: handles multi-line mail =====

{
    my $outfile = "$tmpdir/output2.txt";
    $Spamikaze::pipe_program = "cat > $outfile";

    my $pipe = Spamikaze::Pipe->new();
    my $mail = "Received: from host [10.0.0.1] by mx\n"
             . "From: spammer\@evil.com\n"
             . "Subject: Buy pills\n"
             . "Content-Type: text/plain\n"
             . "\n"
             . "This is a multi-line\n"
             . "spam message body\n"
             . "with several lines.\n";
    $pipe->pipe_mail($mail);

    open my $fh, '<', $outfile or die "Cannot read $outfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is($content, $mail, 'pipe_mail: multi-line mail delivered intact');
}

# ===== pipe_mail: handles empty body =====

{
    my $outfile = "$tmpdir/output3.txt";
    $Spamikaze::pipe_program = "cat > $outfile";

    my $pipe = Spamikaze::Pipe->new();
    my $mail = "From: test\@example.com\nSubject: Empty\n\n";
    $pipe->pipe_mail($mail);

    open my $fh, '<', $outfile or die "Cannot read $outfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is($content, $mail, 'pipe_mail: mail with empty body delivered');
}

# ===== pipe_mail: handles large content =====

{
    my $outfile = "$tmpdir/output4.txt";
    $Spamikaze::pipe_program = "cat > $outfile";

    my $pipe = Spamikaze::Pipe->new();
    my $mail = "From: test\@example.com\nSubject: Large\n\n" . ("x" x 8000) . "\n";
    $pipe->pipe_mail($mail);

    open my $fh, '<', $outfile or die "Cannot read $outfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is($content, $mail, 'pipe_mail: large mail content delivered');
}

# ===== pipe_mail: uses current pipe_program value =====

{
    my $outfile = "$tmpdir/output5.txt";
    $Spamikaze::pipe_program = "cat > $outfile";

    my $pipe = Spamikaze::Pipe->new();
    $pipe->pipe_mail("first call\n");

    open my $fh, '<', $outfile or die "Cannot read $outfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is($content, "first call\n", 'pipe_mail: first program receives content');

    # Change program, same object
    my $outfile2 = "$tmpdir/output5b.txt";
    $Spamikaze::pipe_program = "cat > $outfile2";
    $pipe->pipe_mail("second call\n");

    open $fh, '<', $outfile2 or die "Cannot read $outfile2: $!";
    $content = do { local $/; <$fh> };
    close $fh;
    is($content, "second call\n", 'pipe_mail: reads pipe_program dynamically');
}

# ===== pipe_mail: failing program does not crash caller =====

{
    $Spamikaze::pipe_program = "/nonexistent/program/that/does/not/exist";
    my $pipe = Spamikaze::Pipe->new();
    eval { $pipe->pipe_mail("test\n") };
    ok(!$@, 'pipe_mail: failing program does not die in parent');
}

# ===== pipe_mail: special characters in mail =====

{
    my $outfile = "$tmpdir/output6.txt";
    $Spamikaze::pipe_program = "cat > $outfile";

    my $pipe = Spamikaze::Pipe->new();
    my $mail = "From: \"O'Brien\" <ob\@example.com>\nSubject: Re: 50% off!\n\nPrice: \$100 & more\n";
    $pipe->pipe_mail($mail);

    open my $fh, '<', $outfile or die "Cannot read $outfile: $!";
    my $content = do { local $/; <$fh> };
    close $fh;
    is($content, $mail, 'pipe_mail: special characters preserved');
}

done_testing();
