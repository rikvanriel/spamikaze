<?php

/*
 * config.php, part of spamikaze.
 * Copyright 2003 Hans Wolters, <h-wolters@nl.linux.org>
 * Released under the GNU GPL
 *
 * This file is part of the spamikaze project:
 *     http://spamikaze.surriel.com/
 */


/*
 * Some setting to make sure it will not
 * not have path disclosures and isn't
 * able to open remote files.
 */

ini_set("display_errors",0);
ini_set("allow_url_fopen", 0);

$octa = 0;
$octb = 0;
$octc = 0;
$octd = 0;

$host   = "localhost";
$port   = 3306;
$dbuser = "spammers";
$dbpwd  = "spammers";
$dba    = "root@localhost";
$dbname = "spammers";


function connect()
{
    global $host, $port, $dbuser, $dbpwd, $dba, $dbname, $msg;
    if (!mysql_connect( $host .":". $port, $dbuser, $dbpwd ))
    {
        mail (  $dba, 'Connect', "Could not connect the database server");
        return false;
    }
    else
    {
        if (!mysql_select_db( $dbname ))
        {
            mail (  $dba, 'Selectdb', "Could not select the database");
            return false;
        }
        else
        {
            return true;
        }
    }
}
