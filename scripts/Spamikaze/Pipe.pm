# Spamikaze::Pipe.pm
#
# Copyright (C) 2015 Rik van Riel <riel@surriel.com>
#
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.org/

#
# Methods to pipe spam to an external helper program
#
package Spamikaze::Pipe;
use strict;
use warnings;
use Env qw( HOME );
use POSIX "sys_wait_h";
use Try::Tiny;

sub pipe_mail
{
	my ( $self, $mail ) = @_;
	my $program = $Spamikaze::pipe_program;
	my $pid;

	if ( $pid = fork ) {
		# parent process:
		# wait for the child to exit
		wait;
	} elsif (defined $pid) {
		# child process:
		# feed mail to helper program
		try {
			open PIPE, "| $program";
			print PIPE $mail;
			close PIPE;
			exit 0;
		} catch {
			print "failed to execute $program: $_";
			exit 1;
		}
	}
}

sub new
{
	my $class = shift;
	my $self = {};
	bless $self, $class;

	return $self;
}

BEGIN {
	# do nothing
}

1;
