<html>
<head>
<title>Spamikaze Configuration</title>
</head>
<body bgcolor="white">

<?php
  require("../menu.inc.php");
?>
<img src="/logo/spamikaze.jpg" alt="Spamikaze">

<h1>Spamikaze Configuration</h1>

The main Spamikaze configuration file (the php web scripts use their own
config file) uses the well-known .ini format.  The example configuration
file can be copied to <tt>/etc/spamikaze/config</tt> or 
<tt>~/.spamikaze/config</tt>.

<h2>[Database]</h2>

This section of the configuration file specifies which database Spamikaze
connects to. Note that the <tt>Type</tt> keyword corresponds to the
DBI perl module name, which could be DBI::MySQL or DBI:mysql depending
on your version. It is conceivable that different versions of the postgres
DBI module also have different capitalisation...

<p>The <tt>Host</tt> and <tt>Port</tt> keywords correspond to the host
on which the database is running and the network port at which the database
is listening.  The <tt>Name</tt> keyword indicates the name of the database
Spamikaze should use, while <tt>Username</tt> and <tt>Password</tt> are
used to authenticate with the database server.

<p>Example:

<pre>
[Database]
Type = mysql
Host = localhost
Port = 3306
Name = spamikaze
Username = spamikaze
Password = s3kr1t
</pre>

<h2>[Mail]</h2>

This section of the configuration file indicates what Spamikaze should do
with incoming spam.  The <tt>IgnoreRFC1918</tt> parameter tells Spamikaze
skip over local network addresses when searching the Received: headers for
the IP address to blocklist; leave this option on unless you know what
you are doing. 

<p>The <tt>IgnoreBOGON</tt> option does the same for network
addresses in unassigned (bogus) ranges.  These network ranges should not
be on the internet, so these IP addresses are often forged; however sometimes
rogue ISPs announce addresses from these network ranges, for the purpose
of sending out spam. Whether or not you want to ignore these addresses
depends on taste.

<p>By far the most important option in this section of the Spamikaze
configuration file is <tt>BackupMX</tt>, which indicates exactly which
IP addresses are your MX servers.  Spamikaze will never blocklist any
of the IP addresses in this list.  It is essential to configure the IP
addresses of all your incoming mail servers (including servers that forward
mail to you), otherwise there is a chance of Spamikaze blocklisting your
own mail servers. Make sure this list is complete!

<pre>
[Mail]
IgnoreRFC1918 = 1
IgnoreBOGON = 0
BackupMX = 192\.0\.2\.1 192\.0\.2\.13
</pre>

<h2>[Expire]</h2>

In this section you configure how many hours a host is blocked after the
first spam (<tt>FirstTime</tt>) and how many hours a host is blocked for
every subsequent spam (<tt>ExtraTime</tt>).  Note that the ExtraTime
parameter is cumulative; if a host sends 3 spams, it will be blocked
for 3 times ExtraTime, measured from the last spam that arrived.

<p>If a host has sent more than <tt>MaxSpamPerIp</tt> messages into
the spam traps, it will not be expired from the list automatically;
in order to remove the IP address from the list, somebody will have
to request removal using the web interface.

<pre>
[Expire]
FirstTime = 168
ExtraTime = 336
MaxSpamPerIp = 100
</pre>

<p>Note that database expiration is done by the expire script, so the
Spamikaze user will need to run that script regularly, eg. by placing it
in the crontab.

<h2>[DNSBL]</h2>

This section of the configuration file governs the creation of the
bind zone file that holds the blocklist.  The <tt>Domain</tt> keyword
is the domain of your DNSBL, which will also need to be configured
into your MTA.

<p>The <tt>ZoneFile</tt> keyword determines where the named script
puts the zone file and the <tt>TTL</tt> keyword specifies the time-to-live
of the DNSBL entries in your zone.  Note that in order to avoid excess
DNS queries, the other entries in the zone (eg. the NS records) have a
much longer TTL.

<p><tt>UrlBase</tt> specifies the URL mentioned in the TXT record; this
allows people whose email bounced to visit the web page of the DNSBL.
This way people can see why their mail servers got listed, and they
have the ability to remove their mail server from the blocklist.

<pre>
$ host -t any 3.2.0.192.spamikaze.example.com
3.2.0.192.spamikaze.example.com has address 127.0.0.2
3.2.0.192.spamikaze.example.com text "http://spamikaze.example.com/cgi-bin/listing?ip=192.0.2.3"
$
</pre>

<p>The <tt>PrimaryNS</tt> and <tt>SecondaryNSes</tt> configuration
variables are used to specify the name servers for your Spamikaze zone.
The <tt>PrimaryNS</tt> keyword is also used in the construction of
the zone's SOA record.

<pre>
[DNSBL]
Domain = spamikaze.example.com
ZoneFile = /var/named/master/spamikaze.example.com.zone
TTL = 300
UrlBase = http://spamikaze.example.com/cgi-bin/listing?ip=
PrimaryNS = ns.example.com
SecondaryNSes = ns2.example.com ns.example.net

<?php
  require("docmenu.inc.php");
?>

</body>
</html>
