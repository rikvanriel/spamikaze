#   Spamikaze.pm
#   copyright 2003 Hans Wolters (h-wolters@nl.linux.org)
#   <insert GPL 2 or later in here>

package Spamikaze;
use DBI;

require '/home/sys_scripts/config.pl';
our $dbuser;
our $dbpwd;
our $dbbase;
our $dbport;
our $dbtype;
our $dbhost;
our @MXBACKUP;

my $VERSION = "Spamikaze.pm Version .1\n";

sub Version 
{ 
    return $VERSION; 
}

sub DBConnect
{
    $dbh = DBI->connect("dbi:$dbtype:dbname=$dbbase;host=$dbhost;port=$dbport",
                        "$dbuser", "$dbpwd", { RaiseError => 1 }) || die
                        "Database connection not made: $DBI::errstr";
    return $dbh;
}
