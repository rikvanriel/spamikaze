<html>
<head>
<title>Spamikaze</title>
</head>
<body bgcolor="white">

<?php
  require("menu.inc.php");
?>
<img src="logo/spamikaze.jpg" alt="Spamikaze">

<p>Spamikaze is an automated spam blocklist system, designed to:
<ul>
<li>block spam at the SMTP level
<li>reduce false positives
<li>work with existing mail servers
<li>make sending spam as annoying as receiving spam
</ul>

<p>Unlike some other spam blocking systems, Spamikaze does no tests for
open relay or open proxy vulnerabilities at all.  Instead, Spamikaze simply
lists the IP addresses that have sent spam and allows anybody to remove
IP addresses from the list.

<ul>
<li><b>August 16, 2004</b> Several bugs in the Spamikaze 0.2 beta have
been fixed, please use the latest
<a href="ftp://ftp.nl.linux.org/pub/spamikaze/">CVS snapshot</a> instead.
<li><b>July 2, 2004</b> Spamikaze 0.2-beta is released.
<a href="ftp://ftp.nl.linux.org/pub/spamikaze/spamikaze-0.2-beta.tar.gz">Get
it</a> while it's hot...
<li><b>June 29, 2004</b> Spamikaze 0.2 is almost ready. Currently we need
volunteers to test the latest CVS snapshot and to check the documentation
for errors, inconsistencies and oversights.
<li><b>May 21, 2004</b> The Spamikaze team is working hard to get
version 0.2 ready for general use. This version will feature a new
database layout, a configuration framework and some actual documentation.
<li><b>June 21, 2003</b> The
<a href="http://infosec.uninet.edu/infosec2003/talk/riel-20030620.html">logs</a>
from yesterday's presentation are online.  Useful if you want to know
why Spamikaze was started and how it works.
<li><b>June 20, 2003</b> Spamikaze 0.1 is released and announced at
the <a href="http://infosec.uninet.edu/">Infosec</a> conference.
</ul>

<p>Spamikaze is free software.

</body>
</html>
