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

Spamikaze is based on the following premises:
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
<li>A spamtrap receives an email (most probably spam)
<li>The passivetrap script figures out which IP address delivered the
    email to the spamtrap's email server
<li>... TBD
</ol>

<p>When a spamtrap address receives email, chances are very big that:
(1) the email is spam and (2) the email was not sent by a legitimate
mail server, but instead by an open relay or an open proxy.  Spamikaze
will then add the IP address that delivered the mail to your mail
server to a blocklist.  Since some of those IP addresses (1% ?) may
be legitimate mail servers, with people who want to send you email,
Spamikaze has a removal mechanism.  One simple web site visit allows
anybody to remove an IP address from the list and send you email.

<ul>
<li><a href="/doc">Index</a>
<li><a href="intro.php">Introduction</a>
<li><a href="install.php">Installation</a>
<li><a href="config.php">Configuration</a>
</ul>


</body>
</html>
