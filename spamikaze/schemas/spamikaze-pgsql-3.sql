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
-- TOC entry 5 (OID 365916455)
-- Name: eventtypes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE eventtypes (
    id serial NOT NULL,
    eventtext text
);


--
-- TOC entry 6 (OID 365916455)
-- Name: eventtypes; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE eventtypes FROM PUBLIC;
GRANT SELECT ON TABLE eventtypes TO spamikaze;


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 7 (OID 365916704)
-- Name: blocklist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE blocklist (
    ip inet,
    expires timestamp without time zone
);


--
-- TOC entry 8 (OID 365916704)
-- Name: blocklist; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE blocklist FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE blocklist TO spamikaze;


SET SESSION AUTHORIZATION 'postgres';

--
-- TOC entry 9 (OID 365916736)
-- Name: ipevents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE ipevents (
    ip inet,
    eventtime timestamp without time zone,
    eventid smallint
);


--
-- TOC entry 10 (OID 365916736)
-- Name: ipevents; Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON TABLE ipevents FROM PUBLIC;
GRANT INSERT,SELECT,UPDATE,DELETE ON TABLE ipevents TO spamikaze;


SET SESSION AUTHORIZATION 'postgres';

--
-- Data for TOC entry 16 (OID 365916455)
-- Name: eventtypes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY eventtypes (id, eventtext) FROM stdin;
1	unknown
2	removed through website
3	received spamtrap mail
4	major smtp violation
\.


--
-- Data for TOC entry 17 (OID 365916704)
-- Name: blocklist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY blocklist (ip, expires) FROM stdin;
\.


--
-- Data for TOC entry 18 (OID 365916736)
-- Name: ipevents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY ipevents (ip, eventtime, eventid) FROM stdin;
\.


--
-- TOC entry 12 (OID 365916837)
-- Name: blocklist_expires_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX blocklist_expires_key ON blocklist USING btree (expires);


--
-- TOC entry 15 (OID 365916850)
-- Name: ipevents_ip_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ipevents_ip_key ON ipevents USING btree (ip);


--
-- TOC entry 14 (OID 365916861)
-- Name: ipevents_eventtime_key; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ipevents_eventtime_key ON ipevents USING btree (eventtime);


--
-- TOC entry 13 (OID 365916706)
-- Name: blocklist_ip_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY blocklist
    ADD CONSTRAINT blocklist_ip_key UNIQUE (ip);


--
-- TOC entry 19 (OID 365916878)
-- Name: upsert; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE upsert AS
	ON INSERT TO blocklist
	WHERE (EXISTS (SELECT 1 FROM blocklist WHERE (blocklist.ip = new.ip)))
		DO INSTEAD UPDATE blocklist SET expires = new.expires
			WHERE (blocklist.ip = new.ip);


--
-- TOC entry 11 (OID 365916453)
-- Name: eventtypes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('eventtypes_id_seq', 1, false);


--
-- TOC entry 3 (OID 2200)
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'Spamikaze PgSQL_3 database schema';


