# Spamikaze::MySQL_2.pm
#
# Copyright (C) 2005 Rik van Riel <riel@surriel.com>
#
# Released under the GNU GPL
#
# NO WARRANTY, see the file COPYING for details.
#
# This file is part of the spamikaze project:
#     http://spamikaze.org/

#
# Database abstractions for MySQL schema from Spamikaze 0.2
#

package Spamikaze::MySQL_2;
use strict;
use warnings;
use DBI;
use Env qw( HOME );

# Get all the IP addresses that are listed in the DNSBL.
sub get_listed_addresses {
	my @addresses = ();
	my $dbh;
	my $sql;
	my $sth;
	my $ip;

	$dbh = Spamikaze::DBConnect();

	$sql = "SELECT CONCAT_WS('.', octa, octb, octc, octd) AS ip
		  FROM ipnumbers WHERE visible = 1";
	$sth = $dbh->prepare($sql);
	$sth->execute();
	$sth->bind_columns( undef, \$ip );

	while ( $sth->fetch() ) {
		unshift(@addresses, $ip);
	}
	$sth->finish();
	$dbh->disconnect();

	return @addresses;
}

sub storeip
{
    my ( $self, $ip, $type )  = @_;
    my $error   = 0;
    my @iplist  = split /\./, $ip;
    my $ts      = time();


    my $sql     = "INSERT INTO ipentries (id_ip, date_logged) SELECT 
                    ipnumbers.id, UNIX_TIMESTAMP() FROM ipnumbers WHERE 
                    octa = ? and octb = ? and octc = ? and octd = ?";

    my $visip   = "UPDATE ipnumbers SET visible = 1 WHERE
                        octa = ? AND octb = ? AND octc = ? AND octd = ?";
                        
    # Set the dbh from the new pm.

    my $dbh         = Spamikaze::DBConnect();

    unless ($#iplist == 3) {
    	$error = 1;
    }

    foreach my $num (@iplist) {
            $error = 1 if ($num < 0 or $num > 255 or $num =~ /[^\d]/);
    }

    if ($error < 1) {
        my $sth = $dbh->prepare( $sql );
        $sth->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3]);
        $sth->finish();

        my $rv = $sth->rows;

        if ($rv < 1){

            # the ipnumber isn't known, store it and get the id to
            # store it into the ipentries table.

            my $sqlipnumber = "INSERT INTO ipnumbers (octa, octb, octc, octd)
                               VALUES ( ?, ?, ?, ?)";
           
            eval { # catch failures
                $dbh->{PrintError} = 0 ;
                my $sthipnumber = $dbh->prepare( $sqlipnumber );
                $sthipnumber->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3]);
                $sthipnumber->finish();

                $sth = $dbh->prepare( $sql );
                $sth->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3]);
                $sth->finish();
            } ;

            if ($@) { # handle errors
                unless ($dbh->err() == 1062) { # die unless duplicate entry error
                    die $@ ;
                }
            }
        }

        # needed to set all earlier entries for this ipnumber to visible.
        my $sthupdate = $dbh->prepare( $visip );
        $sthupdate->execute($iplist[0], $iplist[1], $iplist[2], $iplist[3]);
        $sthupdate->finish();
    }        
    $dbh->commit();
    $dbh->disconnect();

}

sub mxdontexpire
{
    my ($self, $ip, @dontexpire) = @_;
    my $entry;

    foreach $entry (@dontexpire) 
    {
        if ($ip =~ /^$entry/) {
            return 1;
        }
    }
    return 0;
}

sub expire
{
    my ($self, @dontexpire) = @_;
    my $ip;
    my $total;
    my $spamtime;
    my $bonustime;
    my $octa;
    my $octb;
    my $octc;
    my $octd;
    my $hostname;

    my $dbh = Spamikaze::DBConnect();

    my $sql = "SELECT
                    COUNT(*) AS total,
                    octa, octb, octc, octd,
                    MAX(date_logged) AS spamtime
               FROM
                    ipentries,  ipnumbers
               WHERE
                    ipnumbers.id = ipentries.id_ip AND
                    visible = 1
               GROUP BY octa, octb, octc, octd
               ORDER BY spamtime ASC";

    my $sth = $dbh->prepare( $sql );
    $sth->execute();
    $sth->bind_columns( undef, \$total, \$octa, \$octb, \$octc, \$octd, \$spamtime);

    my $expiresql = "UPDATE ipnumbers SET visible = 0 WHERE 
                        octa = ? AND octb = ? AND octc = ? AND octd = ?";

    while( $sth->fetch() )
    {
        my $sthexpire = $dbh->prepare( $expiresql );
        $ip = "$octa.$octb.$octc.$octd";
        if ($total == 1 && mxdontexpire($ip) < 1) {
            $bonustime = $spamtime + $Spamikaze::firsttime;
            if ($bonustime <= time()){
                # print $total, "\t";
                $sthexpire->execute($octa, $octb, $octc, $octd);
                # print "$octa.$octb.$octc.$octd\n";
            }
        }
        elsif (($total < $Spamikaze::maxspamperip) &&
                               (mxdontexpire($ip,@dontexpire) < 1))
        {
            $bonustime = $spamtime + ($Spamikaze::extratime * $total) +
			$Spamikaze::firsttime;
            if ($bonustime <= time()){
                # print $total, "\t";
                $sthexpire->execute($octa, $octb, $octc, $octd);
                # print "$octa.$octb.$octc.$octd\n";
            }
        }
        $sthexpire->finish();
        #sleep(1);
    }

    $sth->finish();
    $dbh->commit();
    $dbh->disconnect();
}

sub remove_from_db($)
{
	my ($self, $ip) = @_;
	my ($octa, $octb, $octc, $octd) = split /\./, $ip;
	my $rows_affected;
	my $dbh;

	# DBI connect params.
	$dbh = Spamikaze::DBConnect();
                         
	my $sql = "UPDATE ipnumbers SET visible = 0 WHERE
			octa = ? AND
			octb = ? AND
			octc = ? AND
			octd = ? AND
			visible = 1";

	my $sth = $dbh->prepare($sql);

	# store octs in placeholders, a little more secure.
	$rows_affected = $sth->execute($octa, $octb, $octc, $octd);
	$sth->finish();

	if ($rows_affected > 0)
	{
		my $sqlipr = "INSERT INTO ipremove 
                      (removetime, octa, octb, octc, octd) 
                      VALUES ( ?, ?, ?, ?, ?)";
		my $epoch = time();
		my $sthi = $dbh->prepare($sqlipr);
		$sthi->execute($epoch, $octa, $octb, $octc, $octd);
	}

	$dbh->commit();
	$dbh->disconnect();

	return $rows_affected;    
}

sub get_listing_info
{
	my ($self, $ip) = @_;
	my ($octa, $octb, $octc, $octd) = Spamikaze::SplitIP($ip);
	my %iplog = ();
	my $visible = 0;
	my $vis;
	my $time;
	my $found;
	my $dbh;
    
	$dbh = Spamikaze::DBConnect();
                         
	#
	# get the times where we received spamtrap mail
	#
	my $sql = "SELECT 
                    date_logged AS time FROM ipentries, ipnumbers
               WHERE
            id_ip = ipnumbers.id AND
			octa = ? AND
			octb = ? AND
			octc = ? AND
			octd = ?
		ORDER BY ipentries.id DESC LIMIT 200";

	my $sth = $dbh->prepare($sql);
	$sth->execute($octa, $octb, $octc, $octd);
	$sth->bind_columns(undef, \$time);
	while ($sth->fetch()) {
		$found++;
		$time = gmtime($time);
		$iplog{$time} = 'spamtrap hit';
	}
	$sth->finish();

	#
	# get the removal times, if any
	#
	$sql = "SELECT removetime AS time FROM ipremove WHERE
			octa = ? AND
			octb = ? AND
			octc = ? AND
			octd = ?";

	$sth = $dbh->prepare($sql);
	$sth->execute($octa, $octb, $octc, $octd);
	$sth->bind_columns(undef, \$time);
	while ($sth->fetch()) {
		$found++;
		$time = gmtime($time);
		$iplog{$time} = 'removed from list';
	}
	$sth->finish();

	#
	# is the IP currently listed?
	#
	$sql = "SELECT visible FROM ipnumbers WHERE
			octa = ? AND
			octb = ? AND
			octc = ? AND
			octd = ?";
	
	$sth = $dbh->prepare($sql);
	$sth->execute($octa, $octb, $octc, $octd);
	$sth->bind_columns(\$vis);
	while ($sth->fetch()) {
		$visible = $vis;
	}
	$sth->finish();

	$dbh->disconnect();

	return ($visible, %iplog);
}

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	return $self;
}

BEGIN {
	# nothing
}

1;
