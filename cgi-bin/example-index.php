<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>Example Spamikaze List</title>
</head>
<body>
<?php
  require("header.php");
?>

Welcome to the Spamikaze Example List!  My owner will no doubt
customise this page, turning it into a more complete site.

<p>Use this interface to remove any IP address from the list:

<FORM ACTION="/listing" METHOD="GET">
<INPUT TYPE="text" NAME="ip" VALUE="127.0.0.2" SIZE="20">
<INPUT TYPE="submit">
</FORM>

<?php
  require("footer.php");
?>

</body>
</html>
