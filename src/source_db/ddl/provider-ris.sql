--
-- PostgreSQL database dump
--

\restrict lqYWYeDunMsEWa4ehhxCU6yWBtCvfrd2D8JfDWfB8DLJ42aT6YrI7BkAMMZ2cln

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
-- Name: ris; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ris;


--
-- Name: SCHEMA ris; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA ris IS 'Radiology Information System';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: birads; Type: TABLE; Schema: ris; Owner: -
--

CREATE TABLE ris.birads (
    category character varying(2) NOT NULL,
    display character varying(80) NOT NULL,
    management character varying(150)
);


--
-- Name: code_table; Type: TABLE; Schema: ris; Owner: -
--

CREATE TABLE ris.code_table (
    table_name character varying(20) NOT NULL,
    code character varying(15) NOT NULL,
    display character varying(120) NOT NULL,
    ext_code character varying(40),
    ext_system character varying(120),
    active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE code_table; Type: COMMENT; Schema: ris; Owner: -
--

COMMENT ON TABLE ris.code_table IS 'Flat RIS code table with a single external code slot';


--
-- Name: exam; Type: TABLE; Schema: ris; Owner: -
--

CREATE TABLE ris.exam (
    exam_id integer NOT NULL,
    imaging_order_id integer NOT NULL,
    scheduled_dt timestamp without time zone,
    begin_dt timestamp without time zone,
    end_dt timestamp without time zone,
    technologist_id integer,
    room character varying(20),
    ae_title character varying(16),
    contrast_agent character varying(60),
    contrast_ml numeric(6,1),
    dose_dlp_mgycm numeric(8,1),
    tech_notes text
);


--
-- Name: exam_exam_id_seq; Type: SEQUENCE; Schema: ris; Owner: -
--

CREATE SEQUENCE ris.exam_exam_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: exam_exam_id_seq; Type: SEQUENCE OWNED BY; Schema: ris; Owner: -
--

ALTER SEQUENCE ris.exam_exam_id_seq OWNED BY ris.exam.exam_id;


--
-- Name: imaging_order; Type: TABLE; Schema: ris; Owner: -
--

CREATE TABLE ris.imaging_order (
    imaging_order_id integer NOT NULL,
    accession_no character varying(16) NOT NULL,
    placer_order_no character varying(20),
    patient_id integer NOT NULL,
    encounter_id integer,
    procedure_id integer NOT NULL,
    laterality character(1),
    priority character varying(5) NOT NULL,
    ordering_provider_id integer,
    reason_for_exam character varying(250),
    reason_icd10 character varying(10),
    order_dt timestamp without time zone NOT NULL,
    status character varying(10) NOT NULL,
    cancel_reason_code character varying(10)
);


--
-- Name: imaging_order_imaging_order_id_seq; Type: SEQUENCE; Schema: ris; Owner: -
--

CREATE SEQUENCE ris.imaging_order_imaging_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: imaging_order_imaging_order_id_seq; Type: SEQUENCE OWNED BY; Schema: ris; Owner: -
--

ALTER SEQUENCE ris.imaging_order_imaging_order_id_seq OWNED BY ris.imaging_order.imaging_order_id;


--
-- Name: modality; Type: TABLE; Schema: ris; Owner: -
--

CREATE TABLE ris.modality (
    modality_code character varying(4) NOT NULL,
    description character varying(60) NOT NULL
);


--
-- Name: procedure_catalog; Type: TABLE; Schema: ris; Owner: -
--

CREATE TABLE ris.procedure_catalog (
    procedure_id integer NOT NULL,
    procedure_code character varying(20) NOT NULL,
    description character varying(120) NOT NULL,
    modality_code character varying(4) NOT NULL,
    body_part character varying(30),
    laterality_required boolean DEFAULT false NOT NULL,
    contrast character varying(10),
    cpt_code character varying(10),
    loinc_code character varying(10),
    duration_min smallint,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: procedure_catalog_procedure_id_seq; Type: SEQUENCE; Schema: ris; Owner: -
--

CREATE SEQUENCE ris.procedure_catalog_procedure_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: procedure_catalog_procedure_id_seq; Type: SEQUENCE OWNED BY; Schema: ris; Owner: -
--

ALTER SEQUENCE ris.procedure_catalog_procedure_id_seq OWNED BY ris.procedure_catalog.procedure_id;


--
-- Name: report; Type: TABLE; Schema: ris; Owner: -
--

CREATE TABLE ris.report (
    report_id integer NOT NULL,
    exam_id integer NOT NULL,
    version smallint DEFAULT 1 NOT NULL,
    status character(1) NOT NULL,
    dictated_by_id integer,
    signed_by_id integer,
    dictated_dt timestamp without time zone,
    signed_dt timestamp without time zone,
    clinical_history text,
    technique text,
    comparison text,
    findings text,
    impression text,
    birads character varying(2),
    critical_flag boolean DEFAULT false NOT NULL
);


--
-- Name: report_report_id_seq; Type: SEQUENCE; Schema: ris; Owner: -
--

CREATE SEQUENCE ris.report_report_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: report_report_id_seq; Type: SEQUENCE OWNED BY; Schema: ris; Owner: -
--

ALTER SEQUENCE ris.report_report_id_seq OWNED BY ris.report.report_id;


--
-- Name: exam exam_id; Type: DEFAULT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.exam ALTER COLUMN exam_id SET DEFAULT nextval('ris.exam_exam_id_seq'::regclass);


--
-- Name: imaging_order imaging_order_id; Type: DEFAULT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.imaging_order ALTER COLUMN imaging_order_id SET DEFAULT nextval('ris.imaging_order_imaging_order_id_seq'::regclass);


--
-- Name: procedure_catalog procedure_id; Type: DEFAULT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.procedure_catalog ALTER COLUMN procedure_id SET DEFAULT nextval('ris.procedure_catalog_procedure_id_seq'::regclass);


--
-- Name: report report_id; Type: DEFAULT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.report ALTER COLUMN report_id SET DEFAULT nextval('ris.report_report_id_seq'::regclass);


--
-- Name: birads birads_pkey; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.birads
    ADD CONSTRAINT birads_pkey PRIMARY KEY (category);


--
-- Name: code_table code_table_pkey; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.code_table
    ADD CONSTRAINT code_table_pkey PRIMARY KEY (table_name, code);


--
-- Name: exam exam_imaging_order_id_key; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.exam
    ADD CONSTRAINT exam_imaging_order_id_key UNIQUE (imaging_order_id);


--
-- Name: exam exam_pkey; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.exam
    ADD CONSTRAINT exam_pkey PRIMARY KEY (exam_id);


--
-- Name: imaging_order imaging_order_accession_no_key; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.imaging_order
    ADD CONSTRAINT imaging_order_accession_no_key UNIQUE (accession_no);


--
-- Name: imaging_order imaging_order_pkey; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.imaging_order
    ADD CONSTRAINT imaging_order_pkey PRIMARY KEY (imaging_order_id);


--
-- Name: modality modality_pkey; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.modality
    ADD CONSTRAINT modality_pkey PRIMARY KEY (modality_code);


--
-- Name: procedure_catalog procedure_catalog_pkey; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.procedure_catalog
    ADD CONSTRAINT procedure_catalog_pkey PRIMARY KEY (procedure_id);


--
-- Name: procedure_catalog procedure_catalog_procedure_code_key; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.procedure_catalog
    ADD CONSTRAINT procedure_catalog_procedure_code_key UNIQUE (procedure_code);


--
-- Name: report report_exam_id_version_key; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.report
    ADD CONSTRAINT report_exam_id_version_key UNIQUE (exam_id, version);


--
-- Name: report report_pkey; Type: CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.report
    ADD CONSTRAINT report_pkey PRIMARY KEY (report_id);


--
-- Name: exam exam_imaging_order_id_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.exam
    ADD CONSTRAINT exam_imaging_order_id_fkey FOREIGN KEY (imaging_order_id) REFERENCES ris.imaging_order(imaging_order_id);


--
-- Name: exam exam_technologist_id_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.exam
    ADD CONSTRAINT exam_technologist_id_fkey FOREIGN KEY (technologist_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: imaging_order imaging_order_encounter_id_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.imaging_order
    ADD CONSTRAINT imaging_order_encounter_id_fkey FOREIGN KEY (encounter_id) REFERENCES adt.encounter(encounter_id);


--
-- Name: imaging_order imaging_order_ordering_provider_id_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.imaging_order
    ADD CONSTRAINT imaging_order_ordering_provider_id_fkey FOREIGN KEY (ordering_provider_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: imaging_order imaging_order_patient_id_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.imaging_order
    ADD CONSTRAINT imaging_order_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES adt.patient(patient_id);


--
-- Name: imaging_order imaging_order_procedure_id_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.imaging_order
    ADD CONSTRAINT imaging_order_procedure_id_fkey FOREIGN KEY (procedure_id) REFERENCES ris.procedure_catalog(procedure_id);


--
-- Name: procedure_catalog procedure_catalog_modality_code_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.procedure_catalog
    ADD CONSTRAINT procedure_catalog_modality_code_fkey FOREIGN KEY (modality_code) REFERENCES ris.modality(modality_code);


--
-- Name: report report_dictated_by_id_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.report
    ADD CONSTRAINT report_dictated_by_id_fkey FOREIGN KEY (dictated_by_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: report report_exam_id_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.report
    ADD CONSTRAINT report_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES ris.exam(exam_id);


--
-- Name: report report_signed_by_id_fkey; Type: FK CONSTRAINT; Schema: ris; Owner: -
--

ALTER TABLE ONLY ris.report
    ADD CONSTRAINT report_signed_by_id_fkey FOREIGN KEY (signed_by_id) REFERENCES adt.practitioner(practitioner_id);


--
-- PostgreSQL database dump complete
--

\unrestrict lqYWYeDunMsEWa4ehhxCU6yWBtCvfrd2D8JfDWfB8DLJ42aT6YrI7BkAMMZ2cln

