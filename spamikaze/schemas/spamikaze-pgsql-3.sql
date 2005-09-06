--
-- PostgreSQL database dump
--

SET client_encoding = 'SQL_ASCII';
SET check_function_bodies = false;

SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 4 (OID 2200)
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


SET SESSION AUTHORIZATION 'postgres';

SET search_path = public, pg_catalog;

--
-- TOC entry 5 (OID 315297)
-- Name: summaries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE summaries (
    summ_interval interval NOT NULL,
    from_table text NOT NULL,
    to_table text
);


--
-- TOC entry 6 (OID 315297)
-- Name: summaries; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE summaries FROM PUBLIC;
GRANT SELECT ON TABLE summaries TO querystats;
GRANT SELECT ON TABLE summaries TO psbl;


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 7 (OID 359560522)
-- Name: qs_hourly; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE qs_hourly (
    querytime timestamp without time zone DEFAULT ('now'::text)::timestamp(6) with time zone NOT NULL,
    ip inet NOT NULL,
    count integer NOT NULL
);


--
-- TOC entry 8 (OID 359560522)
-- Name: qs_hourly; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE qs_hourly FROM PUBLIC;
GRANT INSERT,SELECT,DELETE ON TABLE qs_hourly TO querystats;
GRANT SELECT ON TABLE qs_hourly TO psbl;


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 9 (OID 359560525)
-- Name: qs_monthly; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE qs_monthly (
    querytime timestamp without time zone DEFAULT ('now'::text)::timestamp(6) with time zone NOT NULL,
    ip inet NOT NULL,
    count integer NOT NULL
);


--
-- TOC entry 10 (OID 359560525)
-- Name: qs_monthly; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE qs_monthly FROM PUBLIC;
GRANT INSERT,SELECT,DELETE ON TABLE qs_monthly TO querystats;
GRANT SELECT ON TABLE qs_monthly TO psbl;


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 11 (OID 359734272)
-- Name: qs_daily; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE qs_daily (
    querytime timestamp without time zone DEFAULT ('now'::text)::timestamp(6) with time zone NOT NULL,
    ip inet NOT NULL,
    count integer NOT NULL
);


--
-- TOC entry 12 (OID 359734272)
-- Name: qs_daily; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE qs_daily FROM PUBLIC;
GRANT INSERT,SELECT,DELETE ON TABLE qs_daily TO querystats;
GRANT SELECT ON TABLE qs_daily TO psbl;


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 13 (OID 361494746)
-- Name: eventtypes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE eventtypes (
    id serial NOT NULL,
    eventtext text
);


--
-- Data for TOC entry 6 (OID 361494746)
-- Name: eventtypes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY eventtypes (id, eventtext) FROM stdin;
1	unknown
2	removed through website
3	received spamtrap mail
4	major smtp violation
\.

--
-- TOC entry 14 (OID 361494746)
-- Name: eventtypes; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE eventtypes FROM PUBLIC;
GRANT SELECT ON TABLE eventtypes TO psbl;


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 15 (OID 361499222)
-- Name: blocklist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE blocklist (
    ip inet,
    expires timestamp without time zone
);


--
-- TOC entry 16 (OID 361499222)
-- Name: blocklist; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE blocklist FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE blocklist TO psbl;


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 17 (OID 361499226)
-- Name: ipevents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE ipevents (
    ip inet,
    eventtime timestamp without time zone,
    eventid smallint
);


--
-- TOC entry 18 (OID 361499226)
-- Name: ipevents; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE ipevents FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE ipevents TO psbl;


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 21 (OID 359618684)
-- Name: qs_monthly_ip_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX qs_monthly_ip_key ON qs_monthly USING btree (ip);


--
-- TOC entry 22 (OID 359618685)
-- Name: qs_monthly_time_ip_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX qs_monthly_time_ip_key ON qs_monthly USING btree (querytime, ip);


--
-- TOC entry 19 (OID 359618686)
-- Name: qs_hourly_ip_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX qs_hourly_ip_key ON qs_hourly USING btree (ip);


--
-- TOC entry 20 (OID 359618687)
-- Name: qs_hourly_time_ip_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX qs_hourly_time_ip_key ON qs_hourly USING btree (querytime, ip);


--
-- TOC entry 23 (OID 359734275)
-- Name: qs_daily_ip_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX qs_daily_ip_key ON qs_daily USING btree (ip);


--
-- TOC entry 24 (OID 359734276)
-- Name: qs_daily_time_ip_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX qs_daily_time_ip_key ON qs_daily USING btree (querytime, ip);


--
-- TOC entry 26 (OID 361499224)
-- Name: blocklist_ip_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX blocklist_ip_index ON blocklist USING btree (ip);


--
-- TOC entry 25 (OID 361499225)
-- Name: blocklist_expires_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX blocklist_expires_index ON blocklist USING btree (expires);


--
-- TOC entry 28 (OID 361499228)
-- Name: ipevents_ip_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ipevents_ip_index ON ipevents USING btree (ip);


--
-- TOC entry 27 (OID 361499229)
-- Name: ipevents_eventtime_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ipevents_eventtime_index ON ipevents USING btree (eventtime);


--
-- TOC entry 3 (OID 2200)
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Standard public schema';


