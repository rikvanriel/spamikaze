<html>
<head>
<title>Spamikaze Web Scripts</title>
</head>
<body bgcolor="white">

<?php
  require("../menu.inc.php");
?>
<img src="/logo/spamikaze.jpg" alt="Spamikaze">

<h1>Spamikaze Web Scripts</h1>

The web scripts are an essential part of Spamikaze.  No matter the
quality of your spamtrap input, there will always be some false
positives and the only thing that allows others to correct them is
the web based removal script.

<p>In order to make removal easy, it is recommended that the TXT
record for the DNSBL entries point to the listing script.  This
way people can see why an IP address got listed, giving them the
option to remove the IP address from the list.  Note that eg. mail
server admins or spamassassin users will see the TXT record URLs
in their logs and visit the listing page just to figure out why
a certain IP address got listed.  Because those users have no
intention of removing the IP address from the list, the URL for
the DNSBL entries should <i>not</i> point directly to the removal
page, but to the listing page instead.

<p>Note that this page currently only describes the CGI scripts,
not the php based listing and removal scripts.

<h2>[Web]</h2>

This section of the Spamikaze config file is used to configure the web
scripts. The <tt>Header</tt> and <tt>Footer</tt> keywords specify which
header and footer files the listing.cgi and remove.cgi scripts include.
The header and footer files should contain just html, since all the cgi
scripts do is hand them straight to the browser.  You can customise
the example header and footer files to give your Spamikaze site its own
look and feel.

<p>The <tt>ListName</tt> variable should be set to whatever you call
your DNSBL, it will be part of the page title and is used in various
other places on both pages.

<p>Finally, the <tt>ListingURL</tt> and <tt>RemovalURL</tt> keywords
point to the URLs where the listing and remove scripts can be found
on your site.  This needs to be correct in order for the listing page
to be able to refer to the removal page, and vice-versa.

<p>Example:

<pre>
[Web]
Header = /var/www/htdocs/spamikaze/header.php
Footer = /var/www/htdocs/spamikaze/footer.php
ListName = Spamikaze example
ListingURL = /cgi-bin/listing.cgi
RemovalURL = /cgi-bin/remove.cgi
</pre>

<?php
  require("docmenu.inc.php");
?>

</body>
</html>
