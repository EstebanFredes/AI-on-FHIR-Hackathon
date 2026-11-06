--
-- PostgreSQL database dump
--

\restrict D6hbSyg5RPcKUnO6c2sG5rWC51Lvzg2qtFFQrnJRAkvmaPJVBY6tCeeASazZc6s

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


--
-- Name: integration; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA integration;


--
-- Name: SCHEMA integration; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA integration IS 'Interface engine message log (HL7 v2)';


--
-- Name: lis; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA lis;


--
-- Name: SCHEMA lis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA lis IS 'Laboratory Information System';


--
-- Name: pacs; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pacs;


--
-- Name: SCHEMA pacs; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA pacs IS 'PACS DICOM index (separate vendor; linked to RIS only by accession number and MRN)';


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
-- Name: hl7_message message_id; Type: DEFAULT; Schema: integration; Owner: -
--

ALTER TABLE ONLY integration.hl7_message ALTER COLUMN message_id SET DEFAULT nextval('integration.hl7_message_message_id_seq'::regclass);


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

\unrestrict D6hbSyg5RPcKUnO6c2sG5rWC51Lvzg2qtFFQrnJRAkvmaPJVBY6tCeeASazZc6s

