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

sub pipe_mail
{
	my ( $self, $mail ) = @_;
	my $program = $Spamikaze::pipe_program;

	if ( $pid = fork ) {
		# parent process:
		# wait for the child to exit
		wait;
	} elsif (defined $pid) {
		# child process:
		# feed mail to helper program
		open PIPE, "| $program" or print "could not open $program\n";
		print PIPE $mail;
		close PIPE;
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
