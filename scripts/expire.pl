#!/usr/bin/perl

# expire.pl
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
use FindBin;
use lib "$FindBin::Bin";
 
use Spamikaze;

our @DONTEXPIRE = ('127.0.0.2');

sub main
{
    $Spamikaze::db->expire(@DONTEXPIRE);
}

&main;

