# Host: 192.168.1.10
# Database: spammers
# Table: 'country'
# 
CREATE TABLE `country` (
  `id` int(11) NOT NULL auto_increment,
    `country` char(2) NOT NULL default '',
      PRIMARY KEY  (`id`),
        UNIQUE KEY `idx_country` (`country`)
        ) TYPE=MyISAM; 

# Host: 192.168.1.10
# Database: spammers
# Table: 'fqdn'
# 
CREATE TABLE `fqdn` (
  `id` int(11) NOT NULL auto_increment,
    `hostname` varchar(200) NOT NULL default '',
      `abuse` varchar(80) NOT NULL default '',
        PRIMARY KEY  (`id`),
          UNIQUE KEY `idx_hostname` (`hostname`(40))
          ) TYPE=MyISAM; 

# Host: 192.168.1.10
# Database: spammers
# Table: 'ipremove'
# 
CREATE TABLE `ipremove` (
  `id` int(11) NOT NULL auto_increment,
    `removetime` int(11) NOT NULL default '0',
      `octa` smallint(6) NOT NULL default '0',
        `octb` smallint(6) NOT NULL default '0',
          `octc` smallint(6) NOT NULL default '0',
            `octd` smallint(6) NOT NULL default '0',
              PRIMARY KEY  (`id`),
                KEY `idx_remove` (`octa`,`octb`,`octc`,`octd`)
                ) TYPE=MyISAM; 

# Host: 192.168.1.10
# Database: spammers
# Table: 'spammers'
# 
CREATE TABLE `spammers` (
  `id` int(11) NOT NULL auto_increment,
    `octa` smallint(6) NOT NULL default '0',
      `octb` smallint(6) NOT NULL default '0',
        `octc` smallint(6) NOT NULL default '0',
          `octd` smallint(6) NOT NULL default '0',
            `spamtime` int(11) NOT NULL default '0',
              `hostname` varchar(150) NOT NULL default '',
                `visible` tinyint(1) NOT NULL default '1',
                  `c_id` smallint(6) NOT NULL default '0',
                    `fqdn_id` int(11) NOT NULL default '0',
                      PRIMARY KEY  (`id`),
                        KEY `idx_ip` (`octa`,`octb`,`octc`,`octd`),
                          KEY `idx_view` (`id`,`octa`,`octb`,`octc`,`octd`,`hostname`,`visible`,`c_id`)
                          ) TYPE=MyISAM; 

# Host: 192.168.1.10
# Database: spammers
# Table: 'whitelist'
# 
CREATE TABLE `whitelist` (
  `id` int(11) NOT NULL auto_increment,
    `email` varchar(100) NOT NULL default '',
      PRIMARY KEY  (`id`),
        UNIQUE KEY `idx_email` (`email`)
        ) TYPE=MyISAM; 


