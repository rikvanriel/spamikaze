--
-- First try to get Spamikaze running with PostgreSQL 7
--

-- Note : removetime should be timestamp with time zone
--        oct[a-d] should be cidr
CREATE TABLE "ipremove" (
  "id"                 bigserial,
  "removetime"         integer NOT NULL default '0',
  "octa"               smallint NOT NULL default '0',
  "octb"               smallint NOT NULL default '0',
  "octc"               smallint NOT NULL default '0',
  "octd"               smallint NOT NULL default '0',
  primary key ("id")
);

CREATE INDEX idx_remove ON ipremove ( octa, octb, octc, octd );

-- Note : oct[a-d] should be cidr
--        spamtime should be timestamp with time zone
CREATE TABLE "spammers" (
  "id"                 bigserial,
  "octa"               smallint NOT NULL default '0',
  "octb"               smallint NOT NULL default '0',
  "octc"               smallint NOT NULL default '0',
  "octd"               smallint NOT NULL default '0',
  "spamtime"           integer NOT NULL default '0',
  "visible"            integer NOT NULL default '1',
  primary key ("id")
);

CREATE INDEX idx_ip ON spammers ( octa, octb, octc, octd );

CREATE TABLE "whitelist" (
  "id"                 bigserial,
  "email"              varchar(100) NOT NULL default'',
  primary key ("id")
);

CREATE UNIQUE INDEX idx_email ON whitelist ( email );

