--
-- PostgreSQL database dump
--

\restrict iS6Pw15m3uKaNCoWWo6zaJI9OoqyDzpLVOf5PW0We8E4WsE90pzjoB2OFWgt2a1

-- Dumped from database version 18.6 (Debian 18.6-1.pgdg13+2)
-- Dumped by pg_dump version 18.6 (Debian 18.6-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: integration; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA integration;


--
-- Name: SCHEMA integration; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA integration IS 'Interface engine message log (HL7 v2)';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: hl7_message; Type: TABLE; Schema: integration; Owner: -
--

CREATE TABLE integration.hl7_message (
    message_id bigint NOT NULL,
    direction character varying(3) NOT NULL,
    source_system character varying(20) NOT NULL,
    dest_system character varying(20) NOT NULL,
    message_type character varying(10) NOT NULL,
    control_id character varying(30) NOT NULL,
    received_dt timestamp without time zone NOT NULL,
    ack_code character varying(2),
    raw_message text NOT NULL
);


--
-- Name: hl7_message_message_id_seq; Type: SEQUENCE; Schema: integration; Owner: -
--

CREATE SEQUENCE integration.hl7_message_message_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hl7_message_message_id_seq; Type: SEQUENCE OWNED BY; Schema: integration; Owner: -
--

ALTER SEQUENCE integration.hl7_message_message_id_seq OWNED BY integration.hl7_message.message_id;


--
-- Name: lookup_table; Type: TABLE; Schema: integration; Owner: -
--

CREATE TABLE integration.lookup_table (
    table_name character varying(40) NOT NULL,
    source_value character varying(60) NOT NULL,
    target_value character varying(60),
    description character varying(200),
    last_modified date,
    modified_by character varying(20)
);


--
-- Name: TABLE lookup_table; Type: COMMENT; Schema: integration; Owner: -
--

COMMENT ON TABLE integration.lookup_table IS 'Interface engine translation tables';


--
-- Name: hl7_message message_id; Type: DEFAULT; Schema: integration; Owner: -
--

ALTER TABLE ONLY integration.hl7_message ALTER COLUMN message_id SET DEFAULT nextval('integration.hl7_message_message_id_seq'::regclass);


--
-- Name: hl7_message hl7_message_pkey; Type: CONSTRAINT; Schema: integration; Owner: -
--

ALTER TABLE ONLY integration.hl7_message
    ADD CONSTRAINT hl7_message_pkey PRIMARY KEY (message_id);


--
-- Name: lookup_table lookup_table_pkey; Type: CONSTRAINT; Schema: integration; Owner: -
--

ALTER TABLE ONLY integration.lookup_table
    ADD CONSTRAINT lookup_table_pkey PRIMARY KEY (table_name, source_value);


--
-- PostgreSQL database dump complete
--

\unrestrict iS6Pw15m3uKaNCoWWo6zaJI9OoqyDzpLVOf5PW0We8E4WsE90pzjoB2OFWgt2a1

