--
-- PostgreSQL database dump
--

-- Dumped from database version 13.14
-- Dumped by pg_dump version 13.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: merge_blocklist(inet, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.merge_blocklist(ipaddr inet, expiry_time timestamp without time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    LOOP 
        UPDATE blocklist SET expires = expiry_time WHERE ip = ipaddr;
        IF found THEN
            RETURN;
        END IF;

        BEGIN
            INSERT INTO blocklist(ip,expires) VALUES (ipaddr, expiry_time);
            RETURN;
        EXCEPTION WHEN unique_violation THEN
            -- do nothing
        END;
    END LOOP;
END;
$$;


ALTER FUNCTION public.merge_blocklist(ipaddr inet, expiry_time timestamp without time zone) OWNER TO postgres;

--
-- Name: merge_blocklist(inet, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.merge_blocklist(ipaddr inet, expiry_time timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
        UPDATE blocklist SET expires = expiry_time WHERE ip = ipaddr;
        IF found THEN
            RETURN;
        END IF;

        BEGIN
            INSERT INTO blocklist(ip,expires) VALUES (ipaddr, expiry_time);
            RETURN;
        END;
END;
$$;


ALTER FUNCTION public.merge_blocklist(ipaddr inet, expiry_time timestamp with time zone) OWNER TO postgres;

--
-- Name: merge_db(inet, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.merge_db(ipaddr inet, expiry_time timestamp without time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    LOOP 
        UPDATE blocklist SET expires = expiry_time WHERE ip = ipaddr;
        IF found THEN
            RETURN;
        END IF;

        BEGIN
            INSERT INTO blocklist(ip,expires) VALUES (ipaddr, expiry_time);
            RETURN;
        EXCEPTION WHEN unique_violation THEN 
            -- do nothing
        END;
    END LOOP;
END;
$$;


ALTER FUNCTION public.merge_db(ipaddr inet, expiry_time timestamp without time zone) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: blocklist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blocklist (
    ip inet,
    expires timestamp without time zone
);


ALTER TABLE public.blocklist OWNER TO postgres;

--
-- Name: emails; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emails (
    ip inet,
    "time" timestamp without time zone,
    spam boolean,
    email text
);


ALTER TABLE public.emails OWNER TO postgres;

--
-- Name: eventtypes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.eventtypes (
    id integer NOT NULL,
    eventtext text
);


ALTER TABLE public.eventtypes OWNER TO postgres;

--
-- Name: eventtypes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.eventtypes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.eventtypes_id_seq OWNER TO postgres;

--
-- Name: eventtypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.eventtypes_id_seq OWNED BY public.eventtypes.id;


--
-- Name: ipevents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ipevents (
    ip inet,
    eventtime timestamp without time zone,
    eventid smallint
);


ALTER TABLE public.ipevents OWNER TO postgres;

--
-- Name: eventtypes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.eventtypes ALTER COLUMN id SET DEFAULT nextval('public.eventtypes_id_seq'::regclass);


--
-- Data for Name: emails; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.emails (ip, "time", spam, email) FROM stdin;
\.


--
-- Data for Name: eventtypes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.eventtypes (id, eventtext) FROM stdin;
1	unknown
2	removed through website
3	received spamtrap mail
4	major smtp violation
5	open relay test
\.


--
-- Name: eventtypes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.eventtypes_id_seq', 1, false);


--
-- Name: blocklist_expires_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX blocklist_expires_index ON public.blocklist USING btree (expires);


--
-- Name: blocklist_ip_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX blocklist_ip_index ON public.blocklist USING btree (ip);


--
-- Name: email_ip; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX email_ip ON public.emails USING btree (ip);


--
-- Name: email_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX email_time ON public.emails USING btree ("time");


--
-- Name: ipevents_eventtime_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ipevents_eventtime_index ON public.ipevents USING btree (eventtime);


--
-- Name: ipevents_ip_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ipevents_ip_index ON public.ipevents USING btree (ip);


--
-- Name: blocklist upsert; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE upsert AS
    ON INSERT TO public.blocklist
   WHERE (EXISTS ( SELECT 1
           FROM public.blocklist blocklist_1
          WHERE (blocklist_1.ip = new.ip))) DO INSTEAD  UPDATE public.blocklist SET expires = new.expires
  WHERE (blocklist.ip = new.ip);


--
-- Name: TABLE blocklist; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.blocklist TO psbl;


--
-- Name: TABLE emails; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.emails TO psbl;


--
-- Name: TABLE eventtypes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.eventtypes TO psbl;


--
-- Name: TABLE ipevents; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.ipevents TO psbl;


--
-- PostgreSQL database dump complete
--

