--
-- MySQL schema for Spamikaze 3
--
-- This is the MySQL equivalent of schemas/spamikaze-pgsql-3.sql
-- It uses the same table layout as PgSQL_3: IP stored as a string
-- in a single column, timestamps for expiry, and an event log.
--

--
-- Table structure for table `blocklist`
--

CREATE TABLE blocklist (
  ip VARCHAR(45) NOT NULL,
  expires DATETIME NOT NULL,
  PRIMARY KEY (ip),
  KEY idx_blocklist_expires (expires)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Table structure for table `eventtypes`
--

CREATE TABLE eventtypes (
  id INT NOT NULL AUTO_INCREMENT,
  eventtext VARCHAR(255) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Seed data for eventtypes
--

INSERT INTO eventtypes (id, eventtext) VALUES
  (1, 'unknown'),
  (2, 'removed through website'),
  (3, 'received spamtrap mail'),
  (4, 'major smtp violation'),
  (5, 'open relay test');

--
-- Table structure for table `ipevents`
--

CREATE TABLE ipevents (
  ip VARCHAR(45) NOT NULL,
  eventtime DATETIME NOT NULL,
  eventid INT NOT NULL,
  KEY idx_ipevents_ip (ip),
  KEY idx_ipevents_eventtime (eventtime),
  KEY idx_ipevents_eventid (eventid),
  CONSTRAINT fk_ipevents_eventid FOREIGN KEY (eventid) REFERENCES eventtypes(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Table structure for table `emails`
--

CREATE TABLE emails (
  ip VARCHAR(45) NOT NULL,
  `time` DATETIME NOT NULL,
  spam BOOLEAN NOT NULL DEFAULT FALSE,
  email MEDIUMTEXT,
  KEY idx_emails_ip (ip),
  KEY idx_emails_time (`time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
