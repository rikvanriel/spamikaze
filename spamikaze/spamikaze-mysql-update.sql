-- MySQL dump 8.23
--
-- Host: localhost    Database: spammers
---------------------------------------------------------
-- Server version	3.23.58

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
  octa smallint(6) NOT NULL default '0',
  octb smallint(6) NOT NULL default '0',
  octc smallint(6) NOT NULL default '0',
  octd smallint(6) NOT NULL default '0',
  visible tinyint(4) NOT NULL default '0',
  PRIMARY KEY  (id),
  UNIQUE KEY idx_ip (octa,octb,octc,octd),
  UNIQUE KEY idx_ipuniq (octa,octb,octc,octd)
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

