-- MySQL dump 8.23
--
-- Host: localhost    Database: spammers
---------------------------------------------------------
-- Server version	3.23.58

--
-- Table structure for table `agents`
--

CREATE TABLE agents (
  id int(11) NOT NULL auto_increment,
  agent varchar(255) NOT NULL default '',
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `country`
--

CREATE TABLE country (
  id int(11) NOT NULL auto_increment,
  country char(2) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY idx_country (country)
) TYPE=MyISAM;

--
-- Table structure for table `fqdn`
--

CREATE TABLE fqdn (
  id int(11) NOT NULL auto_increment,
  hostname varchar(200) NOT NULL default '',
  abuse varchar(80) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY idx_hostname (hostname(40))
) TYPE=MyISAM;

--
-- Table structure for table `ipentries`
--

CREATE TABLE ipentries (
  id int(11) NOT NULL auto_increment,
  date_received int(11) NOT NULL default '0',
  date_logged int(11) NOT NULL default '0',
  date_mail int(11) NOT NULL default '0',
  id_subject int(11) NOT NULL default '0',
  id_ip int(11) NOT NULL default '0',
  PRIMARY KEY  (id),
  KEY idx_idip (id_ip),
  KEY idx_dl (date_logged)
) TYPE=MyISAM;

--
-- Table structure for table `ipnumbers`
--

CREATE TABLE ipnumbers (
  id int(11) NOT NULL auto_increment,
  octa tinyint(3) unsigned NOT NULL default '0',
  octb tinyint(3) unsigned NOT NULL default '0',
  octc tinyint(3) unsigned NOT NULL default '0',
  octd tinyint(3) unsigned NOT NULL default '0',
  visible tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (id),
  UNIQUE KEY idx_ipuniq (octa,octb,octc,octd),
  KEY idx_visible(visible)
) TYPE=MyISAM;

--
-- Table structure for table `ipremove`
--
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

--
-- Table structure for table `popheaders`
--

CREATE TABLE popheaders (
  id int(11) NOT NULL auto_increment,
  dt date NOT NULL default '0000-00-00',
  headers text NOT NULL,
  PRIMARY KEY  (id)
) TYPE=MyISAM;

--
-- Table structure for table `spammers`
--

CREATE TABLE spammers (
  id int(11) NOT NULL auto_increment,
  octa smallint(6) NOT NULL default '0',
  octb smallint(6) NOT NULL default '0',
  octc smallint(6) NOT NULL default '0',
  octd smallint(6) NOT NULL default '0',
  spamtime int(11) NOT NULL default '0',
  hostname varchar(150) NOT NULL default '',
  visible tinyint(1) NOT NULL default '1',
  c_id smallint(6) NOT NULL default '0',
  fqdn_id int(11) NOT NULL default '0',
  PRIMARY KEY  (id),
  KEY idx_ip (octa,octb,octc,octd),
  KEY idx_view (id,octa,octb,octc,octd,hostname,visible,c_id)
) TYPE=MyISAM;

--
-- Table structure for table `subjects`
--

CREATE TABLE subjects (
  id int(11) NOT NULL auto_increment,
  subject varchar(150) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY idx_subject (subject)
) TYPE=MyISAM;

--
-- Table structure for table `url`
--

CREATE TABLE url (
  id int(11) NOT NULL auto_increment,
  id_spammers int(11) NOT NULL default '0',
  url varchar(255) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY idx_url (url)
) TYPE=MyISAM;

--
-- Table structure for table `whitelist`
--

CREATE TABLE whitelist (
  id int(11) NOT NULL auto_increment,
  email varchar(100) NOT NULL default '',
  PRIMARY KEY  (id),
  UNIQUE KEY idx_email (email)
) TYPE=MyISAM;

