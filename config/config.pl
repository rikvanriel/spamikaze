#!/usr/bin/perl -w
#
# config.pl
#
# Copyright (C) 2003 Hans Wolters <h-wolters@nl.linux.org>
# Copyright (C) 2003 Rik van Riel <riel@surriel.com>
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.surriel.com/

our $dbuser  = 'spammers';
our $dbpwd   = 'spammers';
our $dbbase  = 'spammers';
our $dbhost  = 'localhost';
our $dbport  = '';
our $dbtype  = '';

# All your backup MX's

our @MXBACKUP = ('10\.', '127.', '172.1[6-9]\.', '172.2[0-9]\.', '172.3[0-2]',
                '192.168.',         # rfc 1918 space
                '213.93.35.203',    # dbi coder, hans
                '131.211.28.48',        # nl.linux.org
                '3ffe:8260:',           # compendium pTLA
                '66.92.77.98',          # imladris.surriel.com
                '200.250.58.', '216.138.240.',  # conectiva
                '66.187.',          # red hat
                '213.70.168.',          # lists.sourceforge.net
                '195.224.96.',          # infradead.org
                );

# Domains not to expire.

our @BLACKLISTDOMAINS = (   'konductio.com', 
                            'kapitulex.com',
                        );

# Ranges not to expire.
our @DONTEXPIRE = (                                                                                            
                        '0\.', 
                    );

