<html>
<head>
<title>Spamikaze Installation</title>
</head>
<body bgcolor="white">

<?php
  require("../menu.inc.php");
?>
<img src="/logo/spamikaze.jpg" alt="Spamikaze">

<h1>Spamikaze Installation</h1>

The spamikaze scripts should be installed on disk somewhere; in this
manual we'll assume the scripts are installed in /opt/spamikaze/scripts,
but it really doesn't matter where they are.  The perl module
(Spamikaze.pm) should be installed somewhere in perl's module search
path, or in /opt/spamikaze/scripts.  Currently there is no installation
script that does this automatically.

<h2>Perl modules</h2>

The basic Spamikaze configuration needs the following 3rd party perl
modules: DBI, DBI:mysql (or DBI:pgsql if you use PostgreSQL), Config::IniFiles
and Net::DNS.  If your OS does not have these perl modules available as
ready packages, they can be installed using the CPAN shell. As root,
run the following command to enter the CPAN shell:

<p><tt>
# perl -MCPAN -e 'shell'
</tt>

<p>If this is the first time you are using CPAN, you will need to answer
a number of questions in order to configure the software.  If you need
help, you can find documentation on
<a href="http://www.cpan.org/">http://www.cpan.org/</a>. Once CPAN is
configured, you can install the needed perl modules with the following
commands:

<p><tt>
cpan&gt; install DBI;<br>
cpan&gt; install DBI::mysql;<br>
cpan&gt; install Config::IniFiles;<br>
cpan&gt; install Net::DNS;
</tt>

<p>If these modules need other modules to work, and CPAN asks you whether
or not to install the dependencies, answer yes.

<h2>Database</h2>

This document assumes that you are using the MySQL database. PostgreSQL
support and documentation for version 0.2 should be added later.
We are assuming you already have mysql installed and running. If not
then please get a version for your OS and install it with the guide-
lines of that package.

<h3>MySQL Spamikaze database creation</h3>

At the prompt you can mysqladmin to create a new database.

<p><tt>
$ mysqladmin -u root -p create spamikaze
</tt>

<p>You will be prompted for the mysql root password, enter it. If no
errors are shown you need to login as mysql root to the database
server in order to grant privileges to the new spamikaze directory:

<p><tt>
$ mysql -u root -p mysql
</tt>

<p>Again you will be prompted for a password, enter it.
 
Once you are in you should grant privileges with to a user at either
localhost or a webserver able to access this mysql server. It is not
recommended to use a remote server without using some sort of encryption.
The following example will use user spamikaze at localhost. You need to
grant select, insert and update privileges at least. It is recommended
to hold back any other privileges at this time:

<p><tt>
mysql> GRANT SELECT, INSERT, UPDATE ON spamikaze.* TO
        spamikaze@localhost IDENTIFIED BY 's0m3leetpassw0rd';
</tt>

<p>Once this is done you only need to flush the privileges:

<p><tt>
mysql> FLUSH PRIVILEGES;
</tt>

<p>The last thing to do with mysql is read the spamikaze-sf.sql into the newly
created database.
                                                                                
<p><tt>
$ mysql -u root -p spamikaze < /path/spamikaze-mysql.sql
</tt>

<?php
  require("docmenu.inc.php");
?>

</body>
</html>
