<?php

/*
 * remove.php, part of spamikaze.
 * Copyright 2003 Hans Wolters, <h-wolters@nl.linux.org>
 * Released under the GNU GPL
 *
 * NO WARRANTY, see the file COPYING for details.
 *
 * This file is part of the spamikaze project:
 *     http://spamikaze.surriel.com/
 */

include_once 'config.php';

function removeip($a, $b, $c, $d)
{
    global $msg;
    if (connect() == true)
    {
        $sql = "UPDATE ipnumbers SET visible = 0 WHERE
                    octa = '" . $a . "' AND
                    octb = '" . $b . "' AND
                    octc = '" . $c . "' AND
                    octd = '" . $d . "'";

        $result = mysql_query($sql);

        if (mysql_affected_rows() > 0)
        {
            $rmtime = time();
                
            $sql = "INSERT INTO ipremove 
                    (removetime, octa, octb, octc, octd)
                    VALUES ('" . $rmtime . "', 
                            '" . $a . "',
                            '" . $b . "',
                            '" . $c . "',
                            '" . $d . "')";
            mysql_query($sql);
                
            $msg = "The ip number has been queued for the nonblock
                        list. Do remember that it can be triggered again
                        once spam from that address triggers the queue.";
        }
        else
        {
            $msg = "The ip number is not found in our blocklist";
        }
        mysql_free_result($result);
    }
}


function checkip()
{
    global $msg;
    $ip_long = ip2long($_POST['inputip']);
    $ip_reverse = long2ip($ip_long);

    if($_POST['inputip'] == $ip_reverse)
    {
        global $octa, $octb, $octc, $octd;
        $iparray    = explode(".", $_POST['inputip']);
   
        $octa       = $iparray[0];
        $octb       = $iparray[1];
        $octc       = $iparray[2];
        $octd       = $iparray[3];
       
        removeip($octa, $octb, $octc, $octd);
    }
    else
    {
        $msg = "Enter a valid ip number";
    }
}

function whitelist($email)
{
    global $msg;

    if (connect() != true)
            die();
            
            $sql = "INSERT INTO whitelist (email) VALUES ('" . $email . "')";
            if (!mysql_query($sql))
            {
                if (mysql_error() == 1062)
                {
                    $msg = "This address is already whitelisted";
                }
                else
                {
                    print mysql_error();
                }
                return false;
            }
            else
            {
                return true;
            }
}

function validate_email() 
{
    global $msg;
    $email = $_POST['inputemail'];
    if (!eregi ("^([a-z0-9_]|\\-|\\.)+@(([a-z0-9_]|\\-)+\\.)+[a-z]{2,4}$", 
            $email))
    {
        $msg = "This isn't a valid email address.<br><br>";
        return false;
    } 
    else 
    {
        if (whitelist($email))
        {
            $msg = 'Your email address has been queued to appear on 
                  the whitelist. It can take up to 10 minutes before
                  you are able to send mail again<br><br>';
        }
        else
        {
            $msg =  'There was an error whitelisting your emailaddress<br><br>';
        }
    }
}

$msg = '';

if (isset($_POST['inputip']) && !empty($_POST['inputip']))
{
    checkip();
}
elseif (isset($_POST['inputemail']))
{
    validate_email();
}
        
?>

<html>
    <head>
        <title>Remove your IP from our list</title>
    </head>
    <body>

        <?php

        if (empty($msg))
        {

        ?>
        <p>
         Either you or someone using the machine with the same ip number 
         has been triggering our ip blocker. To remove yourself from this 
         blocklist you can enter the ip number in the form and submit it. 
         Do remember that sending spam to users on this machine might get 
         it blocked again.

        <p>
         Another option is to submit your email address in our whitelist.
        <p>
         It might take up to 10 minutes to get removed or to whitelist 
         your e-mail address. 
   
        <?php
        
        } else {
        
                echo $msg;

        }
        ?>
        <form name="" action="remove.php" method=post>
        <table>
            <tr>
                <td>Ip number</td>
                <td><input type=text name="inputip"></td>
            </tr>
            <tr>
                <td>E-mail address</td>
                <td><input type=text name="inputemail"></td>
            </tr>
            <tr>
                <td colspan=2><input type=submit name=submit value="Submit"><td>
            </tr>
        </table>
        </form>
    </body>
</html>
