--
-- PostgreSQL database dump
--

\restrict 8PZEn7d4Ph6xsnXwpVnfPEHI4zWNx8YgKvB6EJAgDpAQVSkC9IE0ZoeMOmMtQvp

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
-- Name: pacs; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pacs;


--
-- Name: SCHEMA pacs; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA pacs IS 'PACS DICOM index (separate vendor; linked to RIS only by accession number and MRN)';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ae; Type: TABLE; Schema: pacs; Owner: -
--

CREATE TABLE pacs.ae (
    ae_title character varying(16) NOT NULL,
    modality_code character varying(4),
    manufacturer character varying(60),
    model character varying(60),
    station_name character varying(30),
    ip_address inet,
    port integer
);


--
-- Name: body_part; Type: TABLE; Schema: pacs; Owner: -
--

CREATE TABLE pacs.body_part (
    body_part character varying(16) NOT NULL,
    display character varying(60) NOT NULL,
    snomed_code character varying(20)
);


--
-- Name: instance; Type: TABLE; Schema: pacs; Owner: -
--

CREATE TABLE pacs.instance (
    instance_pk bigint NOT NULL,
    series_pk bigint NOT NULL,
    sop_instance_uid character varying(64) NOT NULL,
    sop_class_uid character varying(64) NOT NULL,
    instance_number integer,
    rows integer,
    columns integer,
    file_path character varying(200),
    transfer_syntax_uid character varying(64)
);


--
-- Name: instance_instance_pk_seq; Type: SEQUENCE; Schema: pacs; Owner: -
--

CREATE SEQUENCE pacs.instance_instance_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instance_instance_pk_seq; Type: SEQUENCE OWNED BY; Schema: pacs; Owner: -
--

ALTER SEQUENCE pacs.instance_instance_pk_seq OWNED BY pacs.instance.instance_pk;


--
-- Name: series; Type: TABLE; Schema: pacs; Owner: -
--

CREATE TABLE pacs.series (
    series_pk bigint NOT NULL,
    study_pk bigint NOT NULL,
    series_instance_uid character varying(64) NOT NULL,
    series_number integer,
    modality_code character varying(4) NOT NULL,
    series_description character varying(64),
    body_part_examined character varying(16),
    laterality character(1),
    view_position character varying(16),
    source_ae_title character varying(16),
    num_instances integer NOT NULL
);


--
-- Name: series_series_pk_seq; Type: SEQUENCE; Schema: pacs; Owner: -
--

CREATE SEQUENCE pacs.series_series_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: series_series_pk_seq; Type: SEQUENCE OWNED BY; Schema: pacs; Owner: -
--

ALTER SEQUENCE pacs.series_series_pk_seq OWNED BY pacs.series.series_pk;


--
-- Name: study; Type: TABLE; Schema: pacs; Owner: -
--

CREATE TABLE pacs.study (
    study_pk bigint NOT NULL,
    study_instance_uid character varying(64) NOT NULL,
    accession_no character varying(16),
    patient_mrn character varying(15) NOT NULL,
    patient_name character varying(120),
    patient_birth_date character(8),
    patient_sex character(1),
    study_date character(8),
    study_time character varying(14),
    study_description character varying(64),
    modalities_in_study character varying(20),
    referring_physician character varying(120),
    num_series integer,
    num_instances integer,
    storage_size_mb numeric(10,1),
    received_dt timestamp without time zone
);


--
-- Name: study_study_pk_seq; Type: SEQUENCE; Schema: pacs; Owner: -
--

CREATE SEQUENCE pacs.study_study_pk_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: study_study_pk_seq; Type: SEQUENCE OWNED BY; Schema: pacs; Owner: -
--

ALTER SEQUENCE pacs.study_study_pk_seq OWNED BY pacs.study.study_pk;


--
-- Name: uid_registry; Type: TABLE; Schema: pacs; Owner: -
--

CREATE TABLE pacs.uid_registry (
    uid character varying(64) NOT NULL,
    name character varying(120) NOT NULL,
    uid_type character varying(20) NOT NULL,
    retired boolean DEFAULT false NOT NULL
);


--
-- Name: instance instance_pk; Type: DEFAULT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.instance ALTER COLUMN instance_pk SET DEFAULT nextval('pacs.instance_instance_pk_seq'::regclass);


--
-- Name: series series_pk; Type: DEFAULT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.series ALTER COLUMN series_pk SET DEFAULT nextval('pacs.series_series_pk_seq'::regclass);


--
-- Name: study study_pk; Type: DEFAULT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.study ALTER COLUMN study_pk SET DEFAULT nextval('pacs.study_study_pk_seq'::regclass);


--
-- Name: ae ae_pkey; Type: CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.ae
    ADD CONSTRAINT ae_pkey PRIMARY KEY (ae_title);


--
-- Name: body_part body_part_pkey; Type: CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.body_part
    ADD CONSTRAINT body_part_pkey PRIMARY KEY (body_part);


--
-- Name: instance instance_pkey; Type: CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.instance
    ADD CONSTRAINT instance_pkey PRIMARY KEY (instance_pk);


--
-- Name: instance instance_sop_instance_uid_key; Type: CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.instance
    ADD CONSTRAINT instance_sop_instance_uid_key UNIQUE (sop_instance_uid);


--
-- Name: series series_pkey; Type: CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.series
    ADD CONSTRAINT series_pkey PRIMARY KEY (series_pk);


--
-- Name: series series_series_instance_uid_key; Type: CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.series
    ADD CONSTRAINT series_series_instance_uid_key UNIQUE (series_instance_uid);


--
-- Name: study study_pkey; Type: CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.study
    ADD CONSTRAINT study_pkey PRIMARY KEY (study_pk);


--
-- Name: study study_study_instance_uid_key; Type: CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.study
    ADD CONSTRAINT study_study_instance_uid_key UNIQUE (study_instance_uid);


--
-- Name: uid_registry uid_registry_pkey; Type: CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.uid_registry
    ADD CONSTRAINT uid_registry_pkey PRIMARY KEY (uid);


--
-- Name: instance instance_series_pk_fkey; Type: FK CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.instance
    ADD CONSTRAINT instance_series_pk_fkey FOREIGN KEY (series_pk) REFERENCES pacs.series(series_pk);


--
-- Name: series series_source_ae_title_fkey; Type: FK CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.series
    ADD CONSTRAINT series_source_ae_title_fkey FOREIGN KEY (source_ae_title) REFERENCES pacs.ae(ae_title);


--
-- Name: series series_study_pk_fkey; Type: FK CONSTRAINT; Schema: pacs; Owner: -
--

ALTER TABLE ONLY pacs.series
    ADD CONSTRAINT series_study_pk_fkey FOREIGN KEY (study_pk) REFERENCES pacs.study(study_pk);


--
-- PostgreSQL database dump complete
--

\unrestrict 8PZEn7d4Ph6xsnXwpVnfPEHI4zWNx8YgKvB6EJAgDpAQVSkC9IE0ZoeMOmMtQvp

