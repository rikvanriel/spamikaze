<html>
<head>
<title>Spamikaze Documentation</title>
</head>
<body bgcolor="white">

<?php
  require("../menu.inc.php");
?>
<img src="/logo/spamikaze.jpg" alt="Spamikaze">

<h1>An Introduction to Spamikaze</h1>

Spamikaze is based on the following premises, which appear to be true
on the sites where the authors are running Spamikaze:

<ul>
<li>Almost all spam received at spamtrap addresses is spam
<li>Almost all spam is sent from IP addresses that are not mail servers,
    so no legitimate email is lost by blocking those
<li>Open relays and easy to detect open proxies are being abandoned by
    spammers (due to the traditional blocklists), in favor of virus
    infected Windows machines with hard to detect spam trojans.
<li>The chance of somebody else receiving a spam before you is very
    high, since you're only one of over a million recipients.
<li>If users (or mail servers) warn each other from which IP addresses
    spam is flowing, spam can be blocked before it is delivered to most
    recipients.
<li>Spammers have to send out millions of emails to make a profit;
    spammers cannot be profitable without sending out bulk email.
<li>Since spammers have millions of addresses on their lists, it's
    going to be economically impossible for them to find out which addresses
    belong to real users and which belong to spamtraps.
<li>If implemented properly, an anti-spam solution should be able to
    use the numbers against spammers, turning the tables against those
    who send unsollicited bulk email.
</ul>

<p>Spamikaze roughly works as follows:
<ol>
<li>A spamtrap receives an email (most probably spam).
<li>The passivetrap script figures out which IP address delivered the
    email to the spamtrap's email server.
<li>The IP address gets added to the local Spamikaze blocklist.
<li>Spamikaze notifies other Spamikaze systems of the spamtrap event
    (future functionality, not currently implemented).
<li>The local mail server will reject mail from the IP address that
    sent mail into the spam trap.
<li>After a configurable number of days the IP address is automatically
    dropped from the blocklist.
<li>Alternatively, somebody removes the IP address from the list using
    the web interface. This happens in the rare cases where the spam comes
    from an actual mail server that also wants to send legitimate mail
    to a mail server protected by the local Spamikaze list.
<li>If a new spamtrap hit happens from the same IP address, the timeout
    is extended, or the IP address is listed again.
</ol>

The end effect should be that IP addresses that only send you
spam stay on the list for long times (blocking all spam), while
IP addresses from which legitimate mail comes only get blocked
for short periods (so spam is blocked, but you don't miss out
on the legitimate email).

<?php
  require("docmenu.inc.php");
?>

</body>
</html>
