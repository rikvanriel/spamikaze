# MySQL dump 8.16
#
# Host: localhost    Database: spammers
#--------------------------------------------------------
# Server version	3.23.46

#
# Table structure for table 'ipremove'
#

CREATE TABLE ipremove (
  id int(11) NOT NULL auto_increment,
  removetime int(11) NOT NULL default '0',
  octa smallint(6) NOT NULL default '0',
  octb smallint(6) NOT NULL default '0',
  octc smallint(6) NOT NULL default '0',
  octd smallint(6) NOT NULL default '0',
  PRIMARY KEY  (id),
  KEY idx_remove (octa,octb,octc,octd)
) TYPE=MyISAM;

#
# Table structure for table 'spammers'
#

CREATE TABLE ipnumbers (
  id int(11) NOT NULL auto_increment,
  octa smallint(6) NOT NULL default '0',
  octb smallint(6) NOT NULL default '0',
  octc smallint(6) NOT NULL default '0',
  octd smallint(6) NOT NULL default '0',
  spamtime int(11) NOT NULL default '0',
  visible tinyint(1) NOT NULL default '1',
  PRIMARY KEY  (id),
  KEY idx_ip (octa,octb,octc,octd)
) TYPE=MyISAM;

#
# Table structure for table 'whitelist'
#

CREATE TABLE whitelist (
  id int(11) NOT NULL auto_increment,
  email varchar(100) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY idx_email (email)
) TYPE=MyISAM;

