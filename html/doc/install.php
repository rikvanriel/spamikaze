<html>
<head>
<title>Spamikaze Documentation</title>
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


<h2>Spamikaze's spam trap software</h2>

The passivetrap.pl script analyses mail coming into spam traps and
finds the IP address that delivered the message to your mail servers
and adds that IP address to the database.

<p>To call the passivetrap.pl script automatically from a spam trap
email address in sendmail, postfix, zmailer or exim, simply add lines
like the following to the email aliases file (usually in /etc/aliases).

<p><tt>
spamtrap:     "|/opt/spamikaze/scripts/passivetrap.pl"
ionlygetspam: "|/opt/spamikaze/scripts/passivetrap.pl"
</tt>

<p>This way all email to spamtrap@yourdomain is sent into
the passivetrap script automatically. You could even turn a whole
subdomain into one big spamtrap, sending all addresses in that
subdomain into passivetrap.pl.  Eg. if your domain is example.com,
you could create the spamtrap.example.com subdomain and use that
for spamikaze only.

<p>Of course, you will need to make sure the spammers know about
the email addresses you use as spam traps.  Some obvious methods
are posting the address on usenet, putting the address on a web
page or filling the address into unsubscribe forms in spam.
A less obvious (but very effective) way is to look at your mail
logs. Chances are spammers are already trying to send email to
nonexisting accounts at your domain. Using the busiest nonexisting
accounts as spam trap addresses is very effective, because the
spammers are already trying to send mail to them!

<p>Note that you will need to configure Spamikaze before the
passivetrap script can add addresses to the database.

<?php
  require("docmenu.inc.php");
?>

</body>
</html>
