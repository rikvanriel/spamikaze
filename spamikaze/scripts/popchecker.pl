#!/usr/bin/perl

# popchecker.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.org/

use strict;
use warnings;
use Mail::POP3Client; 

my $pop3user   = "user";
my $pop3pass   = "password";
my $pop3host   = "localhost";

my $pop = new Mail::POP3Client( USER => $pop3user, 
                             PASSWORD => $pop3pass, 
                             HOST => $pop3host ) || die "Can't connect";

require '/path/config';
our @MXBACKUP;

my $accesslist = "/etc/mail/access";
my @iplist;
my $checked = 0;

sub mxbackup
{
    my ( $ip ) = @_;
    my $mxhosts;

    foreach $mxhosts (@MXBACKUP) {
        if ($ip =~ /^$mxhosts/) {
            return 1;
        }
    }
    return 0;

}

sub readaccess
{
    my ( $ip ) = @_;
    my $iplist;
    my $match;
    my $rest;
    
    open FILE,$accesslist ||die "Can't open the access list\n";
    while ( $iplist = <FILE> )
    {
        # Leave the rest, I want to fetch the error subject and
        # bounce the mail once this script is working correctly.

        ($match, $rest) = split(/ERROR/,$iplist);
        $match =~ s/\s+$//;
        $match =~ s/^\s+//;
        if ($match eq $ip)
        {
            close FILE;
            return 1;
        }
    }
    close FILE;
    return 0;
}

sub main
{
    my $ip;
    my $rcvd;
		my $i;

    for ($i = 1; $i <= $pop->Count(); $i++) 
    {
        foreach ( $pop->Head( $i ) ) 
        {
            /^(Received):\s+/i; 
            $rcvd = $_;
            if ($rcvd =~ /\[(?:IPv6.*?:)?(\d{1,3}(\.\d{1,3}){3})\]/g) 
            {
                $ip = $1;
            } 
            elsif ($rcvd =~ /\[IPv6:((3ffe|2001|2002)(:[\da-f]{0,4}){3,7})/ig) 
            {
                $ip = $1;
            }
            else 
            {
                $ip = 0;
            }
            if ($ip  && !&mxbackup($ip) && !$checked == 1) 
            {
                if (&readaccess($ip)) 
                {
                    $pop->Delete( $i ); 
                    print "Spammerfound\n";
                }
            }
            
        } 
        $checked = 0;
    }
    $pop->Close();
}

&main;
