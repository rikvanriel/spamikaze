<html>
<head>
<title>Spamikaze Operation</title>
</head>
<body bgcolor="white">

<?php
  require("../menu.inc.php");
?>
<img src="/logo/spamikaze.jpg" alt="Spamikaze">

<h1>Spamikaze Operation</h1>

Spamikaze consists of various scripts, many of which are needed for
proper operation:
<ul>
<li>passivetrap.pl: populates the database by parsing mail that comes
   into the spamtrap email addresses
<li>expire.pl: maintains the database, by expiring old entries
<li>named.pl, sendmail.pl &amp; text.pl: extract the currently listed
    IP addresses from the database and export them into various file formats
</ul>

<h2>Spamikaze's spam trap software</h2>

The passivetrap.pl script analyses mail coming into spam traps and
finds the IP address that delivered the message to your mail servers
and adds that IP address to the database.

<p>To call the passivetrap.pl script automatically from a spam trap
email address in sendmail, postfix, zmailer or exim, simply add lines
like the following to the email aliases file (usually in /etc/aliases).

<p><tt>
spamtrap:     "|/opt/spamikaze/scripts/passivetrap.pl"<br>
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

<p>Note: if you want to feed an entire mailbox into passivetrap,
you'll have to use formail, like this:

<pre>
$ formail -s /path/passivetrap.pl &lt; /path/spam.mbox
</pre>

<h2>Database Expiry</h2>

The fact that a certain IP address sent email into a spamtrap becomes
irrelevant after a certain time.  After all, if an IP address hasn't
sent any spam recently, why block email from there?

<p>The expire.pl script should be run periodically, at least once a day,
to take IP addresses that haven't sent spam recently off the list. Note
that the history in the database is preserved so the listing web script
will still show things.

<h2>Named, sendmail &amp; text scripts</h2>

These scripts export the currently listed IP addresses in the form of
a bind zone file, a sendmail access db and a plaintext file respectively.

<p>The named.pl script needs to be configured in the Spamikaze config
file. Note that after the zone file is regenerated, you will still need
to tell bind to reload the zone in question, by issuing the
<tt>rndc reload</tt> command.

<p>Since the output of the plaintext script doesn't need any configuration,
the file where the plaintext list of IP addresses is exported is specified
on the commandline, like this:

<pre>
$ ./text.pl /tmp/spamikaze-list.txt
</pre>

<?php
  require("docmenu.inc.php");
?>

</body>
</html>
