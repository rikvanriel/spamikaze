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

<h2>Database</h2>

This document assumes that you are using the MySQL database. PostgreSQL
support and documentation for version 0.2 should be added later.
We are assuming you already have mysql installed and running. If not
then please get a version for your OS and install it with the guide-
lines of that package.

<h3>Creating a new database for spamikaze</h3>

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


<h2>Spam trap</h2>


<?php
  require("docmenu.inc.php");
?>

</body>
</html>
