--
-- PostgreSQL database dump
--

\restrict 81mo8dKjKCdGAHNRxuTr3JgtaPvDn0VbTtKYUhBgLM5MDeRz620wQQTRqdGv2Cn

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
-- Name: lis; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA lis;


--
-- Name: SCHEMA lis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA lis IS 'Laboratory Information System';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: antibiotic; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.antibiotic (
    antibiotic_id integer NOT NULL,
    code character varying(10) NOT NULL,
    name character varying(80) NOT NULL,
    loinc_mic_code character varying(10)
);


--
-- Name: antibiotic_antibiotic_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.antibiotic_antibiotic_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: antibiotic_antibiotic_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.antibiotic_antibiotic_id_seq OWNED BY lis.antibiotic.antibiotic_id;


--
-- Name: critical_call; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.critical_call (
    critical_call_id integer NOT NULL,
    result_id integer NOT NULL,
    called_dt timestamp without time zone NOT NULL,
    called_by_id integer,
    called_to character varying(120) NOT NULL,
    read_back boolean DEFAULT true NOT NULL
);


--
-- Name: critical_call_critical_call_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.critical_call_critical_call_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: critical_call_critical_call_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.critical_call_critical_call_id_seq OWNED BY lis.critical_call.critical_call_id;


--
-- Name: dictionary; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.dictionary (
    dict_name character varying(20) NOT NULL,
    code character varying(10) NOT NULL,
    display character varying(100) NOT NULL,
    description character varying(250),
    sort_order smallint,
    active character(1) DEFAULT 'Y'::bpchar NOT NULL
);


--
-- Name: TABLE dictionary; Type: COMMENT; Schema: lis; Owner: -
--

COMMENT ON TABLE lis.dictionary IS 'Generic LIS dictionary (flags, statuses, reject reasons, canned comments)';


--
-- Name: dictionary_map; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.dictionary_map (
    dict_name character varying(20) NOT NULL,
    code character varying(10) NOT NULL,
    target_system character varying(120) NOT NULL,
    target_code character varying(40) NOT NULL,
    target_display character varying(120)
);


--
-- Name: instrument; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.instrument (
    instrument_id integer NOT NULL,
    instrument_code character varying(10) NOT NULL,
    manufacturer character varying(60),
    model character varying(60),
    serial_no character varying(30),
    section_id integer
);


--
-- Name: instrument_instrument_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.instrument_instrument_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instrument_instrument_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.instrument_instrument_id_seq OWNED BY lis.instrument.instrument_id;


--
-- Name: lab_order; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.lab_order (
    order_id integer NOT NULL,
    accession_no character varying(15) NOT NULL,
    placer_order_no character varying(20),
    patient_id integer NOT NULL,
    encounter_id integer,
    ordering_provider_id integer,
    priority character(1) DEFAULT 'R'::bpchar NOT NULL,
    order_dt timestamp without time zone NOT NULL,
    clinical_info character varying(200),
    status character varying(2) NOT NULL
);


--
-- Name: lab_order_order_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.lab_order_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lab_order_order_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.lab_order_order_id_seq OWNED BY lis.lab_order.order_id;


--
-- Name: micro_isolate; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.micro_isolate (
    isolate_id integer NOT NULL,
    result_id integer NOT NULL,
    isolate_no smallint NOT NULL,
    organism_code character varying(20),
    organism_name character varying(120) NOT NULL,
    quantity character varying(40),
    gram_stain character varying(60)
);


--
-- Name: micro_isolate_isolate_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.micro_isolate_isolate_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: micro_isolate_isolate_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.micro_isolate_isolate_id_seq OWNED BY lis.micro_isolate.isolate_id;


--
-- Name: order_item; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.order_item (
    order_item_id integer NOT NULL,
    order_id integer NOT NULL,
    test_id integer NOT NULL,
    status character varying(2) NOT NULL
);


--
-- Name: order_item_order_item_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.order_item_order_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_item_order_item_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.order_item_order_item_id_seq OWNED BY lis.order_item.order_item_id;


--
-- Name: organism; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.organism (
    organism_code character varying(10) NOT NULL,
    organism_name character varying(120) NOT NULL,
    gram_reaction character varying(10),
    organism_group character varying(30),
    snomed_code character varying(20),
    alert_flag boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE organism; Type: COMMENT; Schema: lis; Owner: -
--

COMMENT ON TABLE lis.organism IS 'Microbiology organism master; local codes, partially mapped to SNOMED CT';


--
-- Name: panel_component; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.panel_component (
    panel_test_id integer NOT NULL,
    component_test_id integer NOT NULL,
    seq smallint NOT NULL
);


--
-- Name: result; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.result (
    result_id integer NOT NULL,
    order_item_id integer NOT NULL,
    specimen_id integer,
    test_id integer NOT NULL,
    value_text character varying(200) NOT NULL,
    value_num numeric,
    units character varying(20),
    ref_range character varying(40),
    abnormal_flag character varying(2),
    result_status character(1) NOT NULL,
    instrument_id integer,
    performed_dt timestamp without time zone,
    verified_dt timestamp without time zone,
    verified_by_id integer,
    comment text
);


--
-- Name: COLUMN result.value_text; Type: COMMENT; Schema: lis; Owner: -
--

COMMENT ON COLUMN lis.result.value_text IS 'Raw value as reported; value_num is populated only when value_text is numeric';


--
-- Name: result_choice; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.result_choice (
    test_code character varying(15) NOT NULL,
    choice_code character varying(10) NOT NULL,
    display character varying(60) NOT NULL,
    abnormal_flag character varying(2),
    snomed_code character varying(20),
    sort_order smallint
);


--
-- Name: result_result_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.result_result_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: result_result_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.result_result_id_seq OWNED BY lis.result.result_id;


--
-- Name: section; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.section (
    section_id integer NOT NULL,
    section_code character varying(10) NOT NULL,
    name character varying(60) NOT NULL
);


--
-- Name: section_section_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.section_section_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: section_section_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.section_section_id_seq OWNED BY lis.section.section_id;


--
-- Name: specimen; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.specimen (
    specimen_id integer NOT NULL,
    order_id integer NOT NULL,
    barcode character varying(20) NOT NULL,
    specimen_type_id integer NOT NULL,
    body_site character varying(40),
    collected_dt timestamp without time zone,
    collected_by_id integer,
    received_dt timestamp without time zone,
    condition character varying(20),
    rejected boolean DEFAULT false NOT NULL,
    reject_reason character varying(100)
);


--
-- Name: specimen_specimen_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.specimen_specimen_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: specimen_specimen_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.specimen_specimen_id_seq OWNED BY lis.specimen.specimen_id;


--
-- Name: specimen_type; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.specimen_type (
    specimen_type_id integer NOT NULL,
    code character varying(10) NOT NULL,
    description character varying(80) NOT NULL,
    container character varying(60),
    snomed_code character varying(20)
);


--
-- Name: specimen_type_specimen_type_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.specimen_type_specimen_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: specimen_type_specimen_type_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.specimen_type_specimen_type_id_seq OWNED BY lis.specimen_type.specimen_type_id;


--
-- Name: susceptibility; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.susceptibility (
    susceptibility_id integer NOT NULL,
    isolate_id integer NOT NULL,
    antibiotic_id integer NOT NULL,
    method character varying(10) NOT NULL,
    mic_value character varying(10),
    interpretation character(1) NOT NULL,
    reported boolean DEFAULT true NOT NULL
);


--
-- Name: susceptibility_susceptibility_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.susceptibility_susceptibility_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: susceptibility_susceptibility_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.susceptibility_susceptibility_id_seq OWNED BY lis.susceptibility.susceptibility_id;


--
-- Name: test_catalog; Type: TABLE; Schema: lis; Owner: -
--

CREATE TABLE lis.test_catalog (
    test_id integer NOT NULL,
    test_code character varying(15) NOT NULL,
    test_name character varying(120) NOT NULL,
    short_name character varying(20),
    is_panel boolean DEFAULT false NOT NULL,
    orderable boolean DEFAULT true NOT NULL,
    section_id integer,
    specimen_type_id integer,
    loinc_code character varying(10),
    result_type character varying(5),
    units character varying(20),
    ref_low numeric,
    ref_high numeric,
    ref_text character varying(40),
    critical_low numeric,
    critical_high numeric,
    default_instrument_id integer,
    cpt_code character varying(10),
    active boolean DEFAULT true NOT NULL
);


--
-- Name: COLUMN test_catalog.loinc_code; Type: COMMENT; Schema: lis; Owner: -
--

COMMENT ON COLUMN lis.test_catalog.loinc_code IS 'LOINC mapping maintained by lab IT; NULL = not mapped';


--
-- Name: test_catalog_test_id_seq; Type: SEQUENCE; Schema: lis; Owner: -
--

CREATE SEQUENCE lis.test_catalog_test_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: test_catalog_test_id_seq; Type: SEQUENCE OWNED BY; Schema: lis; Owner: -
--

ALTER SEQUENCE lis.test_catalog_test_id_seq OWNED BY lis.test_catalog.test_id;


--
-- Name: antibiotic antibiotic_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.antibiotic ALTER COLUMN antibiotic_id SET DEFAULT nextval('lis.antibiotic_antibiotic_id_seq'::regclass);


--
-- Name: critical_call critical_call_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.critical_call ALTER COLUMN critical_call_id SET DEFAULT nextval('lis.critical_call_critical_call_id_seq'::regclass);


--
-- Name: instrument instrument_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.instrument ALTER COLUMN instrument_id SET DEFAULT nextval('lis.instrument_instrument_id_seq'::regclass);


--
-- Name: lab_order order_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.lab_order ALTER COLUMN order_id SET DEFAULT nextval('lis.lab_order_order_id_seq'::regclass);


--
-- Name: micro_isolate isolate_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.micro_isolate ALTER COLUMN isolate_id SET DEFAULT nextval('lis.micro_isolate_isolate_id_seq'::regclass);


--
-- Name: order_item order_item_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.order_item ALTER COLUMN order_item_id SET DEFAULT nextval('lis.order_item_order_item_id_seq'::regclass);


--
-- Name: result result_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.result ALTER COLUMN result_id SET DEFAULT nextval('lis.result_result_id_seq'::regclass);


--
-- Name: section section_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.section ALTER COLUMN section_id SET DEFAULT nextval('lis.section_section_id_seq'::regclass);


--
-- Name: specimen specimen_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.specimen ALTER COLUMN specimen_id SET DEFAULT nextval('lis.specimen_specimen_id_seq'::regclass);


--
-- Name: specimen_type specimen_type_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.specimen_type ALTER COLUMN specimen_type_id SET DEFAULT nextval('lis.specimen_type_specimen_type_id_seq'::regclass);


--
-- Name: susceptibility susceptibility_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.susceptibility ALTER COLUMN susceptibility_id SET DEFAULT nextval('lis.susceptibility_susceptibility_id_seq'::regclass);


--
-- Name: test_catalog test_id; Type: DEFAULT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.test_catalog ALTER COLUMN test_id SET DEFAULT nextval('lis.test_catalog_test_id_seq'::regclass);


--
-- Name: antibiotic antibiotic_code_key; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.antibiotic
    ADD CONSTRAINT antibiotic_code_key UNIQUE (code);


--
-- Name: antibiotic antibiotic_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.antibiotic
    ADD CONSTRAINT antibiotic_pkey PRIMARY KEY (antibiotic_id);


--
-- Name: critical_call critical_call_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.critical_call
    ADD CONSTRAINT critical_call_pkey PRIMARY KEY (critical_call_id);


--
-- Name: dictionary dictionary_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.dictionary
    ADD CONSTRAINT dictionary_pkey PRIMARY KEY (dict_name, code);


--
-- Name: instrument instrument_instrument_code_key; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.instrument
    ADD CONSTRAINT instrument_instrument_code_key UNIQUE (instrument_code);


--
-- Name: instrument instrument_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.instrument
    ADD CONSTRAINT instrument_pkey PRIMARY KEY (instrument_id);


--
-- Name: lab_order lab_order_accession_no_key; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.lab_order
    ADD CONSTRAINT lab_order_accession_no_key UNIQUE (accession_no);


--
-- Name: lab_order lab_order_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.lab_order
    ADD CONSTRAINT lab_order_pkey PRIMARY KEY (order_id);


--
-- Name: micro_isolate micro_isolate_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.micro_isolate
    ADD CONSTRAINT micro_isolate_pkey PRIMARY KEY (isolate_id);


--
-- Name: order_item order_item_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.order_item
    ADD CONSTRAINT order_item_pkey PRIMARY KEY (order_item_id);


--
-- Name: organism organism_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.organism
    ADD CONSTRAINT organism_pkey PRIMARY KEY (organism_code);


--
-- Name: panel_component panel_component_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.panel_component
    ADD CONSTRAINT panel_component_pkey PRIMARY KEY (panel_test_id, component_test_id);


--
-- Name: result_choice result_choice_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.result_choice
    ADD CONSTRAINT result_choice_pkey PRIMARY KEY (test_code, choice_code);


--
-- Name: result result_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.result
    ADD CONSTRAINT result_pkey PRIMARY KEY (result_id);


--
-- Name: section section_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.section
    ADD CONSTRAINT section_pkey PRIMARY KEY (section_id);


--
-- Name: section section_section_code_key; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.section
    ADD CONSTRAINT section_section_code_key UNIQUE (section_code);


--
-- Name: specimen specimen_barcode_key; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.specimen
    ADD CONSTRAINT specimen_barcode_key UNIQUE (barcode);


--
-- Name: specimen specimen_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.specimen
    ADD CONSTRAINT specimen_pkey PRIMARY KEY (specimen_id);


--
-- Name: specimen_type specimen_type_code_key; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.specimen_type
    ADD CONSTRAINT specimen_type_code_key UNIQUE (code);


--
-- Name: specimen_type specimen_type_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.specimen_type
    ADD CONSTRAINT specimen_type_pkey PRIMARY KEY (specimen_type_id);


--
-- Name: susceptibility susceptibility_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.susceptibility
    ADD CONSTRAINT susceptibility_pkey PRIMARY KEY (susceptibility_id);


--
-- Name: test_catalog test_catalog_pkey; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.test_catalog
    ADD CONSTRAINT test_catalog_pkey PRIMARY KEY (test_id);


--
-- Name: test_catalog test_catalog_test_code_key; Type: CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.test_catalog
    ADD CONSTRAINT test_catalog_test_code_key UNIQUE (test_code);


--
-- Name: critical_call critical_call_called_by_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.critical_call
    ADD CONSTRAINT critical_call_called_by_id_fkey FOREIGN KEY (called_by_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: critical_call critical_call_result_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.critical_call
    ADD CONSTRAINT critical_call_result_id_fkey FOREIGN KEY (result_id) REFERENCES lis.result(result_id);


--
-- Name: dictionary_map dictionary_map_dict_name_code_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.dictionary_map
    ADD CONSTRAINT dictionary_map_dict_name_code_fkey FOREIGN KEY (dict_name, code) REFERENCES lis.dictionary(dict_name, code);


--
-- Name: instrument instrument_section_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.instrument
    ADD CONSTRAINT instrument_section_id_fkey FOREIGN KEY (section_id) REFERENCES lis.section(section_id);


--
-- Name: lab_order lab_order_encounter_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.lab_order
    ADD CONSTRAINT lab_order_encounter_id_fkey FOREIGN KEY (encounter_id) REFERENCES adt.encounter(encounter_id);


--
-- Name: lab_order lab_order_ordering_provider_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.lab_order
    ADD CONSTRAINT lab_order_ordering_provider_id_fkey FOREIGN KEY (ordering_provider_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: lab_order lab_order_patient_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.lab_order
    ADD CONSTRAINT lab_order_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES adt.patient(patient_id);


--
-- Name: micro_isolate micro_isolate_result_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.micro_isolate
    ADD CONSTRAINT micro_isolate_result_id_fkey FOREIGN KEY (result_id) REFERENCES lis.result(result_id);


--
-- Name: order_item order_item_order_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.order_item
    ADD CONSTRAINT order_item_order_id_fkey FOREIGN KEY (order_id) REFERENCES lis.lab_order(order_id);


--
-- Name: order_item order_item_test_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.order_item
    ADD CONSTRAINT order_item_test_id_fkey FOREIGN KEY (test_id) REFERENCES lis.test_catalog(test_id);


--
-- Name: panel_component panel_component_component_test_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.panel_component
    ADD CONSTRAINT panel_component_component_test_id_fkey FOREIGN KEY (component_test_id) REFERENCES lis.test_catalog(test_id);


--
-- Name: panel_component panel_component_panel_test_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.panel_component
    ADD CONSTRAINT panel_component_panel_test_id_fkey FOREIGN KEY (panel_test_id) REFERENCES lis.test_catalog(test_id);


--
-- Name: result_choice result_choice_test_code_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.result_choice
    ADD CONSTRAINT result_choice_test_code_fkey FOREIGN KEY (test_code) REFERENCES lis.test_catalog(test_code);


--
-- Name: result result_instrument_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.result
    ADD CONSTRAINT result_instrument_id_fkey FOREIGN KEY (instrument_id) REFERENCES lis.instrument(instrument_id);


--
-- Name: result result_order_item_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.result
    ADD CONSTRAINT result_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES lis.order_item(order_item_id);


--
-- Name: result result_specimen_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.result
    ADD CONSTRAINT result_specimen_id_fkey FOREIGN KEY (specimen_id) REFERENCES lis.specimen(specimen_id);


--
-- Name: result result_test_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.result
    ADD CONSTRAINT result_test_id_fkey FOREIGN KEY (test_id) REFERENCES lis.test_catalog(test_id);


--
-- Name: result result_verified_by_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.result
    ADD CONSTRAINT result_verified_by_id_fkey FOREIGN KEY (verified_by_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: specimen specimen_collected_by_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.specimen
    ADD CONSTRAINT specimen_collected_by_id_fkey FOREIGN KEY (collected_by_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: specimen specimen_order_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.specimen
    ADD CONSTRAINT specimen_order_id_fkey FOREIGN KEY (order_id) REFERENCES lis.lab_order(order_id);


--
-- Name: specimen specimen_specimen_type_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.specimen
    ADD CONSTRAINT specimen_specimen_type_id_fkey FOREIGN KEY (specimen_type_id) REFERENCES lis.specimen_type(specimen_type_id);


--
-- Name: susceptibility susceptibility_antibiotic_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.susceptibility
    ADD CONSTRAINT susceptibility_antibiotic_id_fkey FOREIGN KEY (antibiotic_id) REFERENCES lis.antibiotic(antibiotic_id);


--
-- Name: susceptibility susceptibility_isolate_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.susceptibility
    ADD CONSTRAINT susceptibility_isolate_id_fkey FOREIGN KEY (isolate_id) REFERENCES lis.micro_isolate(isolate_id);


--
-- Name: test_catalog test_catalog_default_instrument_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.test_catalog
    ADD CONSTRAINT test_catalog_default_instrument_id_fkey FOREIGN KEY (default_instrument_id) REFERENCES lis.instrument(instrument_id);


--
-- Name: test_catalog test_catalog_section_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.test_catalog
    ADD CONSTRAINT test_catalog_section_id_fkey FOREIGN KEY (section_id) REFERENCES lis.section(section_id);


--
-- Name: test_catalog test_catalog_specimen_type_id_fkey; Type: FK CONSTRAINT; Schema: lis; Owner: -
--

ALTER TABLE ONLY lis.test_catalog
    ADD CONSTRAINT test_catalog_specimen_type_id_fkey FOREIGN KEY (specimen_type_id) REFERENCES lis.specimen_type(specimen_type_id);


--
-- PostgreSQL database dump complete
--

\unrestrict 81mo8dKjKCdGAHNRxuTr3JgtaPvDn0VbTtKYUhBgLM5MDeRz620wQQTRqdGv2Cn

