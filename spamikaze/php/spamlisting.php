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
 

/*
 * alter the location of the config.php to your 
 * location, store the config.php above the docroot.
 */

include_once 'config.php';
 
$topset = 0;


function cidr ($fip, $netblock = 32)
{
    $oct        = explode(".",$fip);
    $iprange    = pow(2,(32 - $netblock));
    $ip_list[0] = $fip;

    for ($i=1;$i<$iprange;$i++) 
    {
        if ($oct[3]<256)
            $oct[3]++;

        if ($oct[3]==256)
        {
            $oct[2]++;
            $oct[3]=0;
        }

        if ($oct[2]==256)
        {
            $oct[1]++;
            $oct[2]=0;
        }

        if ($oct[1]==256)
        {
            $oct[0]++;
            $oct[1]=0;
        }

        if ($oct[0]>255)
        {
            return false;
        }
        
        $ip_list[1] = implode(".",$oct);
        return $ip_list;
                                                                                                                   }
}

function ipcalc($ip)
{
    $fiprange   = explode(".", $ip);
    $fipcalc    = ( ($fiprange[0] * 256 * 256 * 256) +
                    ($fiprange[1] * 256 * 256) +
                    ($fiprange[2] * 256) +
                     $fiprange[3] );
    return $fipcalc;
}

function top()
{
        global $topset;
        $topset = 1;
?>
<html>
    <head>
        <title>Spamikaze ip information</title>
    </head>
    <body>
    <form name=spamlisting action="spamlisting.php" method=post>
<?php
}



function iplist($fip, $sip)
{
    if (connect() != true)
            die();
                
    $fip    = ipcalc($fip);
    $sip    = ipcalc($sip);
    $sqlip  = "((octa * 256 * 256 * 256) +
                (octb * 256 * 256) +
                (octc * 256) + octd )";
                
    $sql    = "SELECT COUNT(id) as total, CONCAT_WS('.', octa, octb, octc, octd) 
                   AS ip, spamtime, visible FROM ipnumbers WHERE";
                
    if ($sip > 0 && $sip > $fip)
    {
        $sql    .= $sqlip . " >= " . $fip . " AND " . $sqlip . " <= " . $sip;
    }
    else
    {
        $sql    .= $sqlip . " = " . $fip;
    }
    $sql    .= " GROUP BY ip ORDER BY octa, octb, octc, octd ASC"; 
    

    $result = mysql_query($sql);
    $total  = mysql_num_rows($result);

    if (isset($_REQUEST['offset']))
    {
        $offset = (int)$_REQUEST['offset'];
    }
    else
    {
        $offset = 0;
    }

    if ($total > 10)
    {
        $sql .= " LIMIT $offset,10";
        $result = mysql_query($sql);
    }
   
    top();
    print "<table cellspacing=1 cellpadding=3 border=1 width=\"80%\">
               <th colspan=4>IP numbers in the selected range</th>\n
               <tr>
                <td>Spams received</td>
                <td>IP Number</td>
                <td>Last spam time</td>
                <td>Blocked</td>
               </tr>\n";
               
    while ($row = mysql_fetch_object($result)) 
    {
        echo "<tr>
                <td>" . $row->total . "</td>
                <td>" . $row->ip . "</td>
                <td>" . date("Y M dS H:i T", $row->spamtime) . "</td>
                <td>" . $row->visible . "</td>
              </tr>\n";
              
    }

    if (($offset + 10 <= $total) && $offset == 0)
    {
        $offset += 10;
        print "<td colspan=5 align=right>
               <a href=\"spamlisting.php?ipfirst=" .
               $_REQUEST['ipfirst'] . "&amp;ipsecond=" .
               $_REQUEST['ipsecond'] . "&amp;offset=$offset\"> >> </a></td>";
    }
    elseif (($offset + 10 <= $total) && $offset > 0)
    {
        $boffset = $offset - 10;
        if ($boffset < 0) $boffset = 0;
        $offset += 10;
        print "<td colspan=2 align=left width=\"50%\">
               <a href=\"spamlisting.php?ipfirst=" .
               $_REQUEST['ipfirst'] . "&amp;ipsecond=" .
               $_REQUEST['ipsecond'] . "&amp;offset=$boffset\"> << </a> 
               </td>
               <td colspan=3 align=right>
               <a href=\"spamlisting.php?ipfirst=" .
               $_REQUEST['ipfirst'] . "&amp;ipsecond=" .
               $_REQUEST['ipsecond'] . "&amp;offset=$offset\"> >> </a></td>";
    }
    elseif ($offset - 10 >= 0) 
    {
        $boffset = $offset - 10;
        print "<td colspan=5 align=left>
               <a href=\"spamlisting.php?ipfirst=" .
               $_REQUEST['ipfirst'] . "&amp;ipsecond=" .
               $_REQUEST['ipsecond'] . "&amp;offset=$boffset\"> << </a></td>";
    }
    print "</table>";
    mysql_free_result($result);

}

if (isset($_REQUEST['ipfirst']))
{
    if (ereg( "^([0-9]{1,3}(\.[0-9]{1,3}){3})$", $_REQUEST['ipfirst']))
        $fip = $_REQUEST['ipfirst'];

    if (ereg( "^([0-9]{1,3}(\.[0-9]{1,3}){3})$", $_REQUEST['ipsecond']))
        $sip = $_REQUEST['ipsecond'];


    if (ereg( "^([0-9]{1,3}(\.[0-9]{1,3}){2})$", $_REQUEST['ipfirst']))
    {       
        $fip = $_REQUEST['ipfirst'] . ".0";
        $sip = $_REQUEST['ipfirst'] . ".255";
    }

    if (ereg( "^([0-9]{1,3}(\.[0-9]{1,3}){1})$", $_REQUEST['ipfirst']))
    {
        $fip = $_REQUEST['ipfirst'] . ".0.0";
        $sip = $_REQUEST['ipfirst'] . ".255.255";
    }

    if (ereg( "^([0-9]{1,3}(\.[0-9]{1,3}){3}(\/[0-9]{1,2}))$", $_REQUEST['ipfirst']))
    {
        $netblock = explode('/', $_REQUEST['ipfirst']);

        if ((int)$netblock[1] > 1 && (int)$netblock[1] < 32)
        {
            $iprange = cidr($netblock[0], $netblock[1]);
            if (count($iprange) > 1)
            {
                $fip = $_REQUEST['ipfirst'];
                $sip = $iprange[1];
            }
        }
    }

    if (!empty($fip) && !empty($sip))
    {
       iplist($fip, $sip);
    }
    elseif (!empty($fip))
    {
       iplist($fip, 0);
    }
}

if ($topset == 0)
    top();

?>
        <table>
            <th colspan=2>Give the iprange you would like to list</th>
            <tr>
                <td>Lower bound (or use /2 to /32 to select a subnet).</td>
                <td>
                    <input type=text name="ipfirst" size=30 maxlength=22>
                </td>
            </tr>
            <tr>
                <td>Higher bound</td>
                <td>
                    <input type=text name="ipsecond" size=30 maxlength=22>
                </td>
            </tr>
            <tr>
                <td colspan=2>
                    <input type=submit name=submit value="Submit">
                </td>
            </tr>
        </table>
        </form>
    </body>
</html>


