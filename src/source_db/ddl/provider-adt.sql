--
-- PostgreSQL database dump
--

\restrict BXmRIUsd8tmxSwiyJ9fIbTJCe5kvdcWpbzOxoQgOm0dBv1qeR829ltgSnPDJW5M

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
-- Name: adt; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA adt;


--
-- Name: SCHEMA adt; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA adt IS 'HIS/ADT system: master patient index, encounters, staff, locations, coverage';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: allergen_dictionary; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.allergen_dictionary (
    allergen_code character varying(10) NOT NULL,
    display character varying(100) NOT NULL,
    allergen_type character varying(2) NOT NULL,
    synonyms character varying(200),
    rxnorm_code character varying(15),
    snomed_code character varying(20),
    mapping_note character varying(200),
    active boolean DEFAULT true NOT NULL
);


--
-- Name: TABLE allergen_dictionary; Type: COMMENT; Schema: adt; Owner: -
--

COMMENT ON TABLE adt.allergen_dictionary IS 'Nursing allergen picklist; adt.allergy.allergen_text is free text and only partially matches it';


--
-- Name: allergy; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.allergy (
    allergy_id integer NOT NULL,
    patient_id integer NOT NULL,
    allergen_text character varying(120) NOT NULL,
    allergen_type character varying(10),
    reaction character varying(120),
    severity character varying(10),
    noted_on date,
    status character varying(10) DEFAULT 'ACTIVE'::character varying
);


--
-- Name: allergy_allergy_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.allergy_allergy_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: allergy_allergy_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.allergy_allergy_id_seq OWNED BY adt.allergy.allergy_id;


--
-- Name: code_set; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.code_set (
    code_set_id integer NOT NULL,
    name character varying(30) NOT NULL,
    description character varying(200),
    owner character varying(30),
    hl7_table character varying(10)
);


--
-- Name: TABLE code_set; Type: COMMENT; Schema: adt; Owner: -
--

COMMENT ON TABLE adt.code_set IS 'Generic code set master (HIS). Transactional tables store code_value.code';


--
-- Name: code_value; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.code_value (
    code_value_id integer NOT NULL,
    code_set_id integer NOT NULL,
    code character varying(20) NOT NULL,
    display character varying(100) NOT NULL,
    description character varying(250),
    sort_order smallint,
    active boolean DEFAULT true NOT NULL,
    effective_from date DEFAULT '2008-01-01'::date,
    effective_to date
);


--
-- Name: code_value_alias; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.code_value_alias (
    alias_id integer NOT NULL,
    code_value_id integer NOT NULL,
    direction character varying(3) DEFAULT 'OUT'::character varying NOT NULL,
    contributor character varying(20) NOT NULL,
    alias_system character varying(120),
    alias_code character varying(40) NOT NULL,
    alias_display character varying(120)
);


--
-- Name: TABLE code_value_alias; Type: COMMENT; Schema: adt; Owner: -
--

COMMENT ON TABLE adt.code_value_alias IS 'Outbound/inbound aliases of local codes to external code systems';


--
-- Name: code_value_alias_alias_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.code_value_alias_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: code_value_alias_alias_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.code_value_alias_alias_id_seq OWNED BY adt.code_value_alias.alias_id;


--
-- Name: code_value_code_value_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.code_value_code_value_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: code_value_code_value_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.code_value_code_value_id_seq OWNED BY adt.code_value.code_value_id;


--
-- Name: department; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.department (
    department_id integer NOT NULL,
    facility_id integer NOT NULL,
    dept_code character varying(10) NOT NULL,
    name character varying(80) NOT NULL,
    dept_type character varying(20) NOT NULL
);


--
-- Name: department_department_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.department_department_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: department_department_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.department_department_id_seq OWNED BY adt.department.department_id;


--
-- Name: encounter; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.encounter (
    encounter_id integer NOT NULL,
    visit_number character varying(15) NOT NULL,
    patient_id integer NOT NULL,
    patient_class character(1) NOT NULL,
    admit_type character varying(10),
    department_id integer NOT NULL,
    location_id integer,
    attending_id integer,
    referring_id integer,
    admit_dt timestamp without time zone,
    discharge_dt timestamp without time zone,
    chief_complaint character varying(200),
    discharge_disposition character varying(10),
    status character varying(10) NOT NULL,
    payer_id integer
);


--
-- Name: encounter_diagnosis; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.encounter_diagnosis (
    encounter_diagnosis_id integer NOT NULL,
    encounter_id integer NOT NULL,
    seq smallint NOT NULL,
    icd10_code character varying(10) NOT NULL,
    description character varying(200),
    dx_type character varying(10) NOT NULL
);


--
-- Name: COLUMN encounter_diagnosis.icd10_code; Type: COMMENT; Schema: adt; Owner: -
--

COMMENT ON COLUMN adt.encounter_diagnosis.icd10_code IS 'ICD-10-CM; some legacy feeds store codes without the dot';


--
-- Name: encounter_diagnosis_encounter_diagnosis_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.encounter_diagnosis_encounter_diagnosis_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: encounter_diagnosis_encounter_diagnosis_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.encounter_diagnosis_encounter_diagnosis_id_seq OWNED BY adt.encounter_diagnosis.encounter_diagnosis_id;


--
-- Name: encounter_encounter_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.encounter_encounter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: encounter_encounter_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.encounter_encounter_id_seq OWNED BY adt.encounter.encounter_id;


--
-- Name: encounter_location_history; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.encounter_location_history (
    history_id integer NOT NULL,
    encounter_id integer NOT NULL,
    location_id integer NOT NULL,
    event_type character varying(5) NOT NULL,
    start_dt timestamp without time zone NOT NULL,
    end_dt timestamp without time zone
);


--
-- Name: encounter_location_history_history_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.encounter_location_history_history_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: encounter_location_history_history_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.encounter_location_history_history_id_seq OWNED BY adt.encounter_location_history.history_id;


--
-- Name: facility; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.facility (
    facility_id integer NOT NULL,
    facility_code character varying(10) NOT NULL,
    name character varying(120) NOT NULL,
    npi character(10),
    address_line character varying(120),
    city character varying(60),
    state character(2),
    zip character varying(10),
    phone character varying(20)
);


--
-- Name: facility_facility_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.facility_facility_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: facility_facility_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.facility_facility_id_seq OWNED BY adt.facility.facility_id;


--
-- Name: location; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.location (
    location_id integer NOT NULL,
    department_id integer NOT NULL,
    point_of_care character varying(10) NOT NULL,
    room character varying(10),
    bed character varying(5),
    location_type character varying(10) NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: location_location_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.location_location_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: location_location_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.location_location_id_seq OWNED BY adt.location.location_id;


--
-- Name: patient; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.patient (
    patient_id integer NOT NULL,
    mrn character varying(15) NOT NULL,
    last_name character varying(60) NOT NULL,
    first_name character varying(60) NOT NULL,
    middle_name character varying(60),
    dob date,
    sex character(1),
    ssn character varying(11),
    addr_line1 character varying(120),
    addr_line2 character varying(120),
    city character varying(60),
    state character(2),
    zip character varying(10),
    home_phone character varying(20),
    mobile_phone character varying(20),
    email character varying(120),
    primary_language character varying(20),
    race character varying(40),
    ethnicity character varying(40),
    marital_status character(1),
    deceased_flag character(1) DEFAULT 'N'::bpchar,
    deceased_dt timestamp without time zone,
    pcp_id integer,
    active boolean DEFAULT true NOT NULL,
    merged_into_patient_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone
);


--
-- Name: COLUMN patient.merged_into_patient_id; Type: COMMENT; Schema: adt; Owner: -
--

COMMENT ON COLUMN adt.patient.merged_into_patient_id IS 'Set when this record is a duplicate merged by HIM; the surviving record id';


--
-- Name: patient_contact; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.patient_contact (
    contact_id integer NOT NULL,
    patient_id integer NOT NULL,
    relationship character varying(20) NOT NULL,
    contact_role character varying(10),
    full_name character varying(120) NOT NULL,
    phone character varying(20)
);


--
-- Name: patient_contact_contact_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.patient_contact_contact_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: patient_contact_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.patient_contact_contact_id_seq OWNED BY adt.patient_contact.contact_id;


--
-- Name: patient_coverage; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.patient_coverage (
    coverage_id integer NOT NULL,
    patient_id integer NOT NULL,
    payer_id integer NOT NULL,
    member_id character varying(30),
    group_no character varying(30),
    subscriber_rel character varying(10) DEFAULT 'SELF'::character varying,
    priority smallint DEFAULT 1 NOT NULL,
    effective_from date,
    effective_to date
);


--
-- Name: patient_coverage_coverage_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.patient_coverage_coverage_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: patient_coverage_coverage_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.patient_coverage_coverage_id_seq OWNED BY adt.patient_coverage.coverage_id;


--
-- Name: patient_identifier; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.patient_identifier (
    patient_identifier_id integer NOT NULL,
    patient_id integer NOT NULL,
    id_type character varying(10) NOT NULL,
    id_value character varying(40) NOT NULL,
    assigning_authority character varying(40)
);


--
-- Name: patient_identifier_patient_identifier_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.patient_identifier_patient_identifier_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: patient_identifier_patient_identifier_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.patient_identifier_patient_identifier_id_seq OWNED BY adt.patient_identifier.patient_identifier_id;


--
-- Name: patient_patient_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.patient_patient_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: patient_patient_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.patient_patient_id_seq OWNED BY adt.patient.patient_id;


--
-- Name: payer; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.payer (
    payer_id integer NOT NULL,
    payer_code character varying(10) NOT NULL,
    name character varying(100) NOT NULL,
    payer_type character varying(20) NOT NULL
);


--
-- Name: payer_payer_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.payer_payer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payer_payer_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.payer_payer_id_seq OWNED BY adt.payer.payer_id;


--
-- Name: practitioner; Type: TABLE; Schema: adt; Owner: -
--

CREATE TABLE adt.practitioner (
    practitioner_id integer NOT NULL,
    staff_no character varying(10) NOT NULL,
    npi character(10),
    family_name character varying(60) NOT NULL,
    given_name character varying(60) NOT NULL,
    credentials character varying(20),
    role character varying(20) NOT NULL,
    specialty character varying(60),
    department_id integer,
    phone character varying(20),
    email character varying(120),
    active boolean DEFAULT true NOT NULL
);


--
-- Name: practitioner_practitioner_id_seq; Type: SEQUENCE; Schema: adt; Owner: -
--

CREATE SEQUENCE adt.practitioner_practitioner_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: practitioner_practitioner_id_seq; Type: SEQUENCE OWNED BY; Schema: adt; Owner: -
--

ALTER SEQUENCE adt.practitioner_practitioner_id_seq OWNED BY adt.practitioner.practitioner_id;


--
-- Name: allergy allergy_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.allergy ALTER COLUMN allergy_id SET DEFAULT nextval('adt.allergy_allergy_id_seq'::regclass);


--
-- Name: code_value code_value_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.code_value ALTER COLUMN code_value_id SET DEFAULT nextval('adt.code_value_code_value_id_seq'::regclass);


--
-- Name: code_value_alias alias_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.code_value_alias ALTER COLUMN alias_id SET DEFAULT nextval('adt.code_value_alias_alias_id_seq'::regclass);


--
-- Name: department department_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.department ALTER COLUMN department_id SET DEFAULT nextval('adt.department_department_id_seq'::regclass);


--
-- Name: encounter encounter_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter ALTER COLUMN encounter_id SET DEFAULT nextval('adt.encounter_encounter_id_seq'::regclass);


--
-- Name: encounter_diagnosis encounter_diagnosis_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter_diagnosis ALTER COLUMN encounter_diagnosis_id SET DEFAULT nextval('adt.encounter_diagnosis_encounter_diagnosis_id_seq'::regclass);


--
-- Name: encounter_location_history history_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter_location_history ALTER COLUMN history_id SET DEFAULT nextval('adt.encounter_location_history_history_id_seq'::regclass);


--
-- Name: facility facility_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.facility ALTER COLUMN facility_id SET DEFAULT nextval('adt.facility_facility_id_seq'::regclass);


--
-- Name: location location_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.location ALTER COLUMN location_id SET DEFAULT nextval('adt.location_location_id_seq'::regclass);


--
-- Name: patient patient_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient ALTER COLUMN patient_id SET DEFAULT nextval('adt.patient_patient_id_seq'::regclass);


--
-- Name: patient_contact contact_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_contact ALTER COLUMN contact_id SET DEFAULT nextval('adt.patient_contact_contact_id_seq'::regclass);


--
-- Name: patient_coverage coverage_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_coverage ALTER COLUMN coverage_id SET DEFAULT nextval('adt.patient_coverage_coverage_id_seq'::regclass);


--
-- Name: patient_identifier patient_identifier_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_identifier ALTER COLUMN patient_identifier_id SET DEFAULT nextval('adt.patient_identifier_patient_identifier_id_seq'::regclass);


--
-- Name: payer payer_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.payer ALTER COLUMN payer_id SET DEFAULT nextval('adt.payer_payer_id_seq'::regclass);


--
-- Name: practitioner practitioner_id; Type: DEFAULT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.practitioner ALTER COLUMN practitioner_id SET DEFAULT nextval('adt.practitioner_practitioner_id_seq'::regclass);


--
-- Name: allergen_dictionary allergen_dictionary_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.allergen_dictionary
    ADD CONSTRAINT allergen_dictionary_pkey PRIMARY KEY (allergen_code);


--
-- Name: allergy allergy_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.allergy
    ADD CONSTRAINT allergy_pkey PRIMARY KEY (allergy_id);


--
-- Name: code_set code_set_name_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.code_set
    ADD CONSTRAINT code_set_name_key UNIQUE (name);


--
-- Name: code_set code_set_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.code_set
    ADD CONSTRAINT code_set_pkey PRIMARY KEY (code_set_id);


--
-- Name: code_value_alias code_value_alias_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.code_value_alias
    ADD CONSTRAINT code_value_alias_pkey PRIMARY KEY (alias_id);


--
-- Name: code_value code_value_code_set_id_code_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.code_value
    ADD CONSTRAINT code_value_code_set_id_code_key UNIQUE (code_set_id, code);


--
-- Name: code_value code_value_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.code_value
    ADD CONSTRAINT code_value_pkey PRIMARY KEY (code_value_id);


--
-- Name: department department_dept_code_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.department
    ADD CONSTRAINT department_dept_code_key UNIQUE (dept_code);


--
-- Name: department department_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.department
    ADD CONSTRAINT department_pkey PRIMARY KEY (department_id);


--
-- Name: encounter_diagnosis encounter_diagnosis_encounter_id_seq_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter_diagnosis
    ADD CONSTRAINT encounter_diagnosis_encounter_id_seq_key UNIQUE (encounter_id, seq);


--
-- Name: encounter_diagnosis encounter_diagnosis_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter_diagnosis
    ADD CONSTRAINT encounter_diagnosis_pkey PRIMARY KEY (encounter_diagnosis_id);


--
-- Name: encounter_location_history encounter_location_history_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter_location_history
    ADD CONSTRAINT encounter_location_history_pkey PRIMARY KEY (history_id);


--
-- Name: encounter encounter_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter
    ADD CONSTRAINT encounter_pkey PRIMARY KEY (encounter_id);


--
-- Name: encounter encounter_visit_number_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter
    ADD CONSTRAINT encounter_visit_number_key UNIQUE (visit_number);


--
-- Name: facility facility_facility_code_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.facility
    ADD CONSTRAINT facility_facility_code_key UNIQUE (facility_code);


--
-- Name: facility facility_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.facility
    ADD CONSTRAINT facility_pkey PRIMARY KEY (facility_id);


--
-- Name: location location_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.location
    ADD CONSTRAINT location_pkey PRIMARY KEY (location_id);


--
-- Name: patient_contact patient_contact_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_contact
    ADD CONSTRAINT patient_contact_pkey PRIMARY KEY (contact_id);


--
-- Name: patient_coverage patient_coverage_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_coverage
    ADD CONSTRAINT patient_coverage_pkey PRIMARY KEY (coverage_id);


--
-- Name: patient_identifier patient_identifier_id_type_id_value_assigning_authority_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_identifier
    ADD CONSTRAINT patient_identifier_id_type_id_value_assigning_authority_key UNIQUE (id_type, id_value, assigning_authority);


--
-- Name: patient_identifier patient_identifier_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_identifier
    ADD CONSTRAINT patient_identifier_pkey PRIMARY KEY (patient_identifier_id);


--
-- Name: patient patient_mrn_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient
    ADD CONSTRAINT patient_mrn_key UNIQUE (mrn);


--
-- Name: patient patient_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient
    ADD CONSTRAINT patient_pkey PRIMARY KEY (patient_id);


--
-- Name: payer payer_payer_code_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.payer
    ADD CONSTRAINT payer_payer_code_key UNIQUE (payer_code);


--
-- Name: payer payer_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.payer
    ADD CONSTRAINT payer_pkey PRIMARY KEY (payer_id);


--
-- Name: practitioner practitioner_pkey; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.practitioner
    ADD CONSTRAINT practitioner_pkey PRIMARY KEY (practitioner_id);


--
-- Name: practitioner practitioner_staff_no_key; Type: CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.practitioner
    ADD CONSTRAINT practitioner_staff_no_key UNIQUE (staff_no);


--
-- Name: allergy allergy_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.allergy
    ADD CONSTRAINT allergy_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES adt.patient(patient_id);


--
-- Name: code_value_alias code_value_alias_code_value_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.code_value_alias
    ADD CONSTRAINT code_value_alias_code_value_id_fkey FOREIGN KEY (code_value_id) REFERENCES adt.code_value(code_value_id);


--
-- Name: code_value code_value_code_set_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.code_value
    ADD CONSTRAINT code_value_code_set_id_fkey FOREIGN KEY (code_set_id) REFERENCES adt.code_set(code_set_id);


--
-- Name: department department_facility_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.department
    ADD CONSTRAINT department_facility_id_fkey FOREIGN KEY (facility_id) REFERENCES adt.facility(facility_id);


--
-- Name: encounter encounter_attending_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter
    ADD CONSTRAINT encounter_attending_id_fkey FOREIGN KEY (attending_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: encounter encounter_department_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter
    ADD CONSTRAINT encounter_department_id_fkey FOREIGN KEY (department_id) REFERENCES adt.department(department_id);


--
-- Name: encounter_diagnosis encounter_diagnosis_encounter_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter_diagnosis
    ADD CONSTRAINT encounter_diagnosis_encounter_id_fkey FOREIGN KEY (encounter_id) REFERENCES adt.encounter(encounter_id);


--
-- Name: encounter_location_history encounter_location_history_encounter_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter_location_history
    ADD CONSTRAINT encounter_location_history_encounter_id_fkey FOREIGN KEY (encounter_id) REFERENCES adt.encounter(encounter_id);


--
-- Name: encounter_location_history encounter_location_history_location_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter_location_history
    ADD CONSTRAINT encounter_location_history_location_id_fkey FOREIGN KEY (location_id) REFERENCES adt.location(location_id);


--
-- Name: encounter encounter_location_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter
    ADD CONSTRAINT encounter_location_id_fkey FOREIGN KEY (location_id) REFERENCES adt.location(location_id);


--
-- Name: encounter encounter_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter
    ADD CONSTRAINT encounter_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES adt.patient(patient_id);


--
-- Name: encounter encounter_payer_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter
    ADD CONSTRAINT encounter_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES adt.payer(payer_id);


--
-- Name: encounter encounter_referring_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.encounter
    ADD CONSTRAINT encounter_referring_id_fkey FOREIGN KEY (referring_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: location location_department_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.location
    ADD CONSTRAINT location_department_id_fkey FOREIGN KEY (department_id) REFERENCES adt.department(department_id);


--
-- Name: patient_contact patient_contact_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_contact
    ADD CONSTRAINT patient_contact_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES adt.patient(patient_id);


--
-- Name: patient_coverage patient_coverage_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_coverage
    ADD CONSTRAINT patient_coverage_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES adt.patient(patient_id);


--
-- Name: patient_coverage patient_coverage_payer_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_coverage
    ADD CONSTRAINT patient_coverage_payer_id_fkey FOREIGN KEY (payer_id) REFERENCES adt.payer(payer_id);


--
-- Name: patient_identifier patient_identifier_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient_identifier
    ADD CONSTRAINT patient_identifier_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES adt.patient(patient_id);


--
-- Name: patient patient_merged_into_patient_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient
    ADD CONSTRAINT patient_merged_into_patient_id_fkey FOREIGN KEY (merged_into_patient_id) REFERENCES adt.patient(patient_id);


--
-- Name: patient patient_pcp_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.patient
    ADD CONSTRAINT patient_pcp_id_fkey FOREIGN KEY (pcp_id) REFERENCES adt.practitioner(practitioner_id);


--
-- Name: practitioner practitioner_department_id_fkey; Type: FK CONSTRAINT; Schema: adt; Owner: -
--

ALTER TABLE ONLY adt.practitioner
    ADD CONSTRAINT practitioner_department_id_fkey FOREIGN KEY (department_id) REFERENCES adt.department(department_id);


--
-- PostgreSQL database dump complete
--

\unrestrict BXmRIUsd8tmxSwiyJ9fIbTJCe5kvdcWpbzOxoQgOm0dBv1qeR829ltgSnPDJW5M

