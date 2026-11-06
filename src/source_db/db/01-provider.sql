-- =============================================================================
-- provider  —  simulated data of a mid-size hospital ("St. Example General")
--
-- Each schema stands for a separate source system, the way they usually live
-- side by side at a healthcare provider:
--   adt          HIS / ADT: master patient index, encounters, staff, locations, coverage
--   lis          Laboratory Information System: catalog, orders, specimens, results, micro
--   ris          Radiology Information System: procedure catalog, orders, exams, reports
--   pacs         PACS / DICOM index: AE titles, studies, series, instances
--   integration  Interface engine: raw HL7 v2 message log
--
-- The design keeps some legacy quirks on purpose (local codes next to standard codes,
-- values stored as text, HL7 v2-style status/flag codes, timestamps without time zone,
-- a merged duplicate patient, a corrected result, a preliminary report, a pending test)
-- because that is what real provider data looks like.
--
-- All people, identifiers and UIDs are made up.
-- =============================================================================

SET client_min_messages = warning;

CREATE SCHEMA adt;
CREATE SCHEMA lis;
CREATE SCHEMA ris;
CREATE SCHEMA pacs;
CREATE SCHEMA integration;

-- =============================================================================
-- ADT / HIS
-- =============================================================================

CREATE TABLE adt.facility (
  facility_id     serial PRIMARY KEY,
  facility_code   varchar(10) NOT NULL UNIQUE,
  name            varchar(120) NOT NULL,
  npi             char(10),
  address_line    varchar(120),
  city            varchar(60),
  state           char(2),
  zip             varchar(10),
  phone           varchar(20)
);

CREATE TABLE adt.department (
  department_id   serial PRIMARY KEY,
  facility_id     int NOT NULL REFERENCES adt.facility,
  dept_code       varchar(10) NOT NULL UNIQUE,
  name            varchar(80) NOT NULL,
  dept_type       varchar(20) NOT NULL  -- CLINICAL | ANCILLARY | INPATIENT | EMERGENCY
);

CREATE TABLE adt.location (
  location_id     serial PRIMARY KEY,
  department_id   int NOT NULL REFERENCES adt.department,
  point_of_care   varchar(10) NOT NULL,     -- HL7 PL.1 (unit)
  room            varchar(10),              -- HL7 PL.2
  bed             varchar(5),               -- HL7 PL.3
  location_type   varchar(10) NOT NULL,     -- WARD | ROOM | BED | EXAM | BAY
  active          boolean NOT NULL DEFAULT true
);

CREATE TABLE adt.practitioner (
  practitioner_id serial PRIMARY KEY,
  staff_no        varchar(10) NOT NULL UNIQUE,   -- local HR / login id
  npi             char(10),
  family_name     varchar(60) NOT NULL,
  given_name      varchar(60) NOT NULL,
  credentials     varchar(20),                   -- MD, RN, MT(ASCP), RT(R) ...
  role            varchar(20) NOT NULL,          -- PHYSICIAN | NURSE | TECHNOLOGIST | PATHOLOGIST
  specialty       varchar(60),
  department_id   int REFERENCES adt.department,
  phone           varchar(20),
  email           varchar(120),
  active          boolean NOT NULL DEFAULT true
);

CREATE TABLE adt.payer (
  payer_id        serial PRIMARY KEY,
  payer_code      varchar(10) NOT NULL UNIQUE,
  name            varchar(100) NOT NULL,
  payer_type      varchar(20) NOT NULL   -- MEDICARE | MEDICAID | COMMERCIAL | SELF
);

CREATE TABLE adt.patient (
  patient_id      serial PRIMARY KEY,
  mrn             varchar(15) NOT NULL UNIQUE,
  last_name       varchar(60) NOT NULL,
  first_name      varchar(60) NOT NULL,
  middle_name     varchar(60),
  dob             date,
  sex             char(1),                 -- M | F | U   (HL7 v2 table 0001 subset)
  ssn             varchar(11),
  addr_line1      varchar(120),
  addr_line2      varchar(120),
  city            varchar(60),
  state           char(2),
  zip             varchar(10),
  home_phone      varchar(20),
  mobile_phone    varchar(20),
  email           varchar(120),
  primary_language varchar(20),            -- free text, mixed values on purpose
  race            varchar(40),
  ethnicity       varchar(40),
  marital_status  char(1),                 -- S M D W U (HL7 table 0002 subset)
  deceased_flag   char(1) DEFAULT 'N',
  deceased_dt     timestamp,
  pcp_id          int REFERENCES adt.practitioner,
  active          boolean NOT NULL DEFAULT true,
  merged_into_patient_id int REFERENCES adt.patient,   -- MPI merge (duplicate resolved)
  created_at      timestamp NOT NULL DEFAULT now(),
  updated_at      timestamp
);

CREATE TABLE adt.patient_identifier (
  patient_identifier_id serial PRIMARY KEY,
  patient_id      int NOT NULL REFERENCES adt.patient,
  id_type         varchar(10) NOT NULL,    -- MR | SS | DL | MB (member) | PI (portal)
  id_value        varchar(40) NOT NULL,
  assigning_authority varchar(40),
  UNIQUE (id_type, id_value, assigning_authority)
);

CREATE TABLE adt.patient_contact (
  contact_id      serial PRIMARY KEY,
  patient_id      int NOT NULL REFERENCES adt.patient,
  relationship    varchar(20) NOT NULL,    -- SPOUSE, MOTHER, FATHER, CHILD, FRIEND ...
  contact_role    varchar(10),             -- EMC (emergency) | NOK (next of kin) | GRD (guardian)
  full_name       varchar(120) NOT NULL,
  phone           varchar(20)
);

CREATE TABLE adt.patient_coverage (
  coverage_id     serial PRIMARY KEY,
  patient_id      int NOT NULL REFERENCES adt.patient,
  payer_id        int NOT NULL REFERENCES adt.payer,
  member_id       varchar(30),
  group_no        varchar(30),
  subscriber_rel  varchar(10) DEFAULT 'SELF',
  priority        smallint NOT NULL DEFAULT 1,
  effective_from  date,
  effective_to    date
);

CREATE TABLE adt.allergy (
  allergy_id      serial PRIMARY KEY,
  patient_id      int NOT NULL REFERENCES adt.patient,
  allergen_text   varchar(120) NOT NULL,   -- free text; no standard coding in the source
  allergen_type   varchar(10),             -- DA (drug) | FA (food) | EA (environmental)
  reaction        varchar(120),
  severity        varchar(10),             -- MI | MO | SV
  noted_on        date,
  status          varchar(10) DEFAULT 'ACTIVE'
);

CREATE TABLE adt.encounter (
  encounter_id    serial PRIMARY KEY,
  visit_number    varchar(15) NOT NULL UNIQUE,   -- HL7 PV1-19
  patient_id      int NOT NULL REFERENCES adt.patient,
  patient_class   char(1) NOT NULL,              -- E emergency | I inpatient | O outpatient | P preadmit
  admit_type      varchar(10),                   -- EMERGENCY | URGENT | ELECTIVE | ROUTINE
  department_id   int NOT NULL REFERENCES adt.department,
  location_id     int REFERENCES adt.location,
  attending_id    int REFERENCES adt.practitioner,
  referring_id    int REFERENCES adt.practitioner,
  admit_dt        timestamp,
  discharge_dt    timestamp,
  chief_complaint varchar(200),
  discharge_disposition varchar(10),             -- 01 home | 03 SNF | 20 expired ... (UB-04)
  status          varchar(10) NOT NULL,          -- PREADMIT | ARRIVED | ADMITTED | DISCHARGED | CANCELLED
  payer_id        int REFERENCES adt.payer
);

CREATE TABLE adt.encounter_diagnosis (
  encounter_diagnosis_id serial PRIMARY KEY,
  encounter_id    int NOT NULL REFERENCES adt.encounter,
  seq             smallint NOT NULL,
  icd10_code      varchar(10) NOT NULL,          -- stored without decimals sometimes!
  description     varchar(200),
  dx_type         varchar(10) NOT NULL,          -- A admitting | W working | F final
  UNIQUE (encounter_id, seq)
);

CREATE TABLE adt.encounter_location_history (
  history_id      serial PRIMARY KEY,
  encounter_id    int NOT NULL REFERENCES adt.encounter,
  location_id     int NOT NULL REFERENCES adt.location,
  event_type      varchar(5) NOT NULL,           -- HL7 trigger: A01 A02 A03 A04 A08
  start_dt        timestamp NOT NULL,
  end_dt          timestamp
);

-- =============================================================================
-- LIS
-- =============================================================================

CREATE TABLE lis.section (
  section_id      serial PRIMARY KEY,
  section_code    varchar(10) NOT NULL UNIQUE,
  name            varchar(60) NOT NULL
);

CREATE TABLE lis.instrument (
  instrument_id   serial PRIMARY KEY,
  instrument_code varchar(10) NOT NULL UNIQUE,
  manufacturer    varchar(60),
  model           varchar(60),
  serial_no       varchar(30),
  section_id      int REFERENCES lis.section
);

CREATE TABLE lis.specimen_type (
  specimen_type_id serial PRIMARY KEY,
  code            varchar(10) NOT NULL UNIQUE,
  description     varchar(80) NOT NULL,
  container       varchar(60),
  snomed_code     varchar(20)                    -- partially mapped
);

CREATE TABLE lis.test_catalog (
  test_id         serial PRIMARY KEY,
  test_code       varchar(15) NOT NULL UNIQUE,   -- local LIS code
  test_name       varchar(120) NOT NULL,
  short_name      varchar(20),
  is_panel        boolean NOT NULL DEFAULT false,
  orderable       boolean NOT NULL DEFAULT true,
  section_id      int REFERENCES lis.section,
  specimen_type_id int REFERENCES lis.specimen_type,
  loinc_code      varchar(10),                   -- NULL = not mapped yet
  result_type     varchar(5),                    -- NM numeric | ST string | CE coded | CULT
  units           varchar(20),                   -- local unit strings (not always UCUM)
  ref_low         numeric,
  ref_high        numeric,
  ref_text        varchar(40),
  critical_low    numeric,
  critical_high   numeric,
  default_instrument_id int REFERENCES lis.instrument,
  cpt_code        varchar(10),
  active          boolean NOT NULL DEFAULT true
);

CREATE TABLE lis.panel_component (
  panel_test_id     int NOT NULL REFERENCES lis.test_catalog,
  component_test_id int NOT NULL REFERENCES lis.test_catalog,
  seq               smallint NOT NULL,
  PRIMARY KEY (panel_test_id, component_test_id)
);

CREATE TABLE lis.lab_order (
  order_id        serial PRIMARY KEY,
  accession_no    varchar(15) NOT NULL UNIQUE,   -- filler order number
  placer_order_no varchar(20),                   -- from the EHR (ORC-2)
  patient_id      int NOT NULL REFERENCES adt.patient,
  encounter_id    int REFERENCES adt.encounter,
  ordering_provider_id int REFERENCES adt.practitioner,
  priority        char(1) NOT NULL DEFAULT 'R',  -- S stat | A asap | R routine
  order_dt        timestamp NOT NULL,
  clinical_info   varchar(200),
  status          varchar(2) NOT NULL            -- SC scheduled | IP in process | CM complete | CA cancelled
);

CREATE TABLE lis.order_item (
  order_item_id   serial PRIMARY KEY,
  order_id        int NOT NULL REFERENCES lis.lab_order,
  test_id         int NOT NULL REFERENCES lis.test_catalog,
  status          varchar(2) NOT NULL            -- SC | IP | CM | CA
);

CREATE TABLE lis.specimen (
  specimen_id     serial PRIMARY KEY,
  order_id        int NOT NULL REFERENCES lis.lab_order,
  barcode         varchar(20) NOT NULL UNIQUE,
  specimen_type_id int NOT NULL REFERENCES lis.specimen_type,
  body_site       varchar(40),
  collected_dt    timestamp,
  collected_by_id int REFERENCES adt.practitioner,
  received_dt     timestamp,
  condition       varchar(20),                   -- OK | HEMOLYZED | LIPEMIC | CLOTTED
  rejected        boolean NOT NULL DEFAULT false,
  reject_reason   varchar(100)
);

CREATE TABLE lis.result (
  result_id       serial PRIMARY KEY,
  order_item_id   int NOT NULL REFERENCES lis.order_item,
  specimen_id     int REFERENCES lis.specimen,
  test_id         int NOT NULL REFERENCES lis.test_catalog,   -- the resulted (component) test
  value_text      varchar(200) NOT NULL,         -- always populated, as sent by the analyzer
  value_num       numeric,                       -- parsed numeric value when possible
  units           varchar(20),
  ref_range       varchar(40),
  abnormal_flag   varchar(2),                    -- N L H LL HH A (HL7 table 0078)
  result_status   char(1) NOT NULL,              -- P prelim | F final | C corrected | X cancelled
  instrument_id   int REFERENCES lis.instrument,
  performed_dt    timestamp,
  verified_dt     timestamp,
  verified_by_id  int REFERENCES adt.practitioner,
  comment         text
);

CREATE TABLE lis.critical_call (
  critical_call_id serial PRIMARY KEY,
  result_id       int NOT NULL REFERENCES lis.result,
  called_dt       timestamp NOT NULL,
  called_by_id    int REFERENCES adt.practitioner,
  called_to       varchar(120) NOT NULL,         -- free text, read-back documented
  read_back       boolean NOT NULL DEFAULT true
);

CREATE TABLE lis.micro_isolate (
  isolate_id      serial PRIMARY KEY,
  result_id       int NOT NULL REFERENCES lis.result,
  isolate_no      smallint NOT NULL,
  organism_code   varchar(20),                   -- SNOMED CT when known
  organism_name   varchar(120) NOT NULL,
  quantity        varchar(40),
  gram_stain      varchar(60)
);

CREATE TABLE lis.antibiotic (
  antibiotic_id   serial PRIMARY KEY,
  code            varchar(10) NOT NULL UNIQUE,
  name            varchar(80) NOT NULL,
  loinc_mic_code  varchar(10)                    -- partially mapped
);

CREATE TABLE lis.susceptibility (
  susceptibility_id serial PRIMARY KEY,
  isolate_id      int NOT NULL REFERENCES lis.micro_isolate,
  antibiotic_id   int NOT NULL REFERENCES lis.antibiotic,
  method          varchar(10) NOT NULL,          -- MIC | KB (disk) | ETEST
  mic_value       varchar(10),
  interpretation  char(1) NOT NULL,              -- S | I | R
  reported        boolean NOT NULL DEFAULT true  -- cascade reporting / suppressed
);

-- =============================================================================
-- RIS
-- =============================================================================

CREATE TABLE ris.modality (
  modality_code   varchar(4) PRIMARY KEY,        -- DICOM modality: CR DX CT MR US MG
  description     varchar(60) NOT NULL
);

CREATE TABLE ris.procedure_catalog (
  procedure_id    serial PRIMARY KEY,
  procedure_code  varchar(20) NOT NULL UNIQUE,   -- local RIS code
  description     varchar(120) NOT NULL,
  modality_code   varchar(4) NOT NULL REFERENCES ris.modality,
  body_part       varchar(30),                   -- DICOM Body Part Examined style
  laterality_required boolean NOT NULL DEFAULT false,
  contrast        varchar(10),                   -- NONE | IV | ORAL
  cpt_code        varchar(10),
  loinc_code      varchar(10),                   -- LOINC/RSNA playbook, partially mapped
  duration_min    smallint,
  active          boolean NOT NULL DEFAULT true
);

CREATE TABLE ris.imaging_order (
  imaging_order_id serial PRIMARY KEY,
  accession_no    varchar(16) NOT NULL UNIQUE,   -- shared with PACS (DICOM 0008,0050)
  placer_order_no varchar(20),
  patient_id      int NOT NULL REFERENCES adt.patient,
  encounter_id    int REFERENCES adt.encounter,
  procedure_id    int NOT NULL REFERENCES ris.procedure_catalog,
  laterality      char(1),                       -- L | R | B
  priority        varchar(5) NOT NULL,           -- STAT | URG | ROUT
  ordering_provider_id int REFERENCES adt.practitioner,
  reason_for_exam varchar(250),
  reason_icd10    varchar(10),
  order_dt        timestamp NOT NULL,
  status          varchar(10) NOT NULL           -- ORDERED | SCHEDULED | IN_PROGRESS | COMPLETED | CANCELLED
);

CREATE TABLE ris.exam (
  exam_id         serial PRIMARY KEY,
  imaging_order_id int NOT NULL UNIQUE REFERENCES ris.imaging_order,
  scheduled_dt    timestamp,
  begin_dt        timestamp,
  end_dt          timestamp,
  technologist_id int REFERENCES adt.practitioner,
  room            varchar(20),
  ae_title        varchar(16),                   -- device that acquired the images
  contrast_agent  varchar(60),
  contrast_ml     numeric(6,1),
  dose_dlp_mgycm  numeric(8,1),                  -- CT dose length product
  tech_notes      text
);

CREATE TABLE ris.report (
  report_id       serial PRIMARY KEY,
  exam_id         int NOT NULL REFERENCES ris.exam,
  version         smallint NOT NULL DEFAULT 1,
  status          char(1) NOT NULL,              -- P preliminary | F final | A addendum | C corrected
  dictated_by_id  int REFERENCES adt.practitioner,
  signed_by_id    int REFERENCES adt.practitioner,
  dictated_dt     timestamp,
  signed_dt       timestamp,
  clinical_history text,
  technique       text,
  comparison      text,
  findings        text,
  impression      text,
  birads          varchar(2),                    -- mammography only
  critical_flag   boolean NOT NULL DEFAULT false,
  UNIQUE (exam_id, version)
);

-- =============================================================================
-- PACS
-- =============================================================================

CREATE TABLE pacs.ae (
  ae_title        varchar(16) PRIMARY KEY,
  modality_code   varchar(4),
  manufacturer    varchar(60),
  model           varchar(60),
  station_name    varchar(30),
  ip_address      inet,
  port            int
);

CREATE TABLE pacs.study (
  study_pk        bigserial PRIMARY KEY,
  study_instance_uid varchar(64) NOT NULL UNIQUE,
  accession_no    varchar(16),                   -- links to ris.imaging_order (no FK: PACS is separate)
  patient_mrn     varchar(15) NOT NULL,          -- (0010,0020) as sent by modality
  patient_name    varchar(120),                  -- DICOM PN: LAST^FIRST^MIDDLE
  patient_birth_date char(8),                    -- DA: YYYYMMDD
  patient_sex     char(1),
  study_date      char(8),
  study_time      varchar(14),                   -- TM: HHMMSS.FFFFFF
  study_description varchar(64),
  modalities_in_study varchar(20),               -- backslash separated
  referring_physician varchar(120),
  num_series      int,
  num_instances   int,
  storage_size_mb numeric(10,1),
  received_dt     timestamp
);

CREATE TABLE pacs.series (
  series_pk       bigserial PRIMARY KEY,
  study_pk        bigint NOT NULL REFERENCES pacs.study,
  series_instance_uid varchar(64) NOT NULL UNIQUE,
  series_number   int,
  modality_code   varchar(4) NOT NULL,
  series_description varchar(64),
  body_part_examined varchar(16),
  laterality      char(1),
  view_position   varchar(16),
  source_ae_title varchar(16) REFERENCES pacs.ae,
  num_instances   int NOT NULL
);

CREATE TABLE pacs.instance (
  instance_pk     bigserial PRIMARY KEY,
  series_pk       bigint NOT NULL REFERENCES pacs.series,
  sop_instance_uid varchar(64) NOT NULL UNIQUE,
  sop_class_uid   varchar(64) NOT NULL,
  instance_number int,
  rows            int,
  columns         int,
  file_path       varchar(200),
  transfer_syntax_uid varchar(64)
);

-- =============================================================================
-- Interface engine
-- =============================================================================

CREATE TABLE integration.hl7_message (
  message_id      bigserial PRIMARY KEY,
  direction       varchar(3) NOT NULL,           -- IN | OUT
  source_system   varchar(20) NOT NULL,
  dest_system     varchar(20) NOT NULL,
  message_type    varchar(10) NOT NULL,          -- ADT^A01, ORM^O01, ORU^R01 ...
  control_id      varchar(30) NOT NULL,
  received_dt     timestamp NOT NULL,
  ack_code        varchar(2),                    -- AA | AE | AR
  raw_message     text NOT NULL
);

-- =============================================================================
-- REFERENCE DATA
-- =============================================================================

INSERT INTO adt.facility (facility_code, name, npi, address_line, city, state, zip, phone) VALUES
 ('SEGH', 'St. Example General Hospital', '1902837465', '1200 Harbor View Blvd', 'Springfield', 'IL', '62704', '(217) 555-0100');

INSERT INTO adt.department (facility_id, dept_code, name, dept_type) VALUES
 (1, 'ED',     'Emergency Department',          'EMERGENCY'),   -- 1
 (1, 'ICU',    'Medical Intensive Care Unit',   'INPATIENT'),   -- 2
 (1, 'MED4',   '4 West Internal Medicine',      'INPATIENT'),   -- 3
 (1, 'FAMMED', 'Family Medicine Clinic',        'CLINICAL'),    -- 4
 (1, 'OBGYN',  'Women''s Health Clinic',        'CLINICAL'),    -- 5
 (1, 'ORTHO',  'Orthopedics & Sports Medicine', 'CLINICAL'),    -- 6
 (1, 'PEDS',   'Pediatrics',                    'CLINICAL'),    -- 7
 (1, 'RAD',    'Diagnostic Imaging',            'ANCILLARY'),   -- 8
 (1, 'LAB',    'Clinical Laboratory',           'ANCILLARY');   -- 9

INSERT INTO adt.location (department_id, point_of_care, room, bed, location_type) VALUES
 (1, 'ED',   '07',  NULL, 'BAY'),    -- 1
 (1, 'ED',   '12',  NULL, 'BAY'),    -- 2
 (1, 'ED',   'P3',  NULL, 'BAY'),    -- 3 pediatric bay
 (2, 'MICU', '204', 'A',  'BED'),    -- 4
 (3, '4W',   '415', 'B',  'BED'),    -- 5
 (3, '4W',   '418', 'A',  'BED'),    -- 6
 (4, 'FMC',  'EX3', NULL, 'EXAM'),   -- 7
 (5, 'WHC',  'EX1', NULL, 'EXAM'),   -- 8
 (6, 'ORTH', 'EX2', NULL, 'EXAM'),   -- 9
 (8, 'RAD',  'CT1', NULL, 'ROOM'),   -- 10
 (8, 'RAD',  'MR1', NULL, 'ROOM'),   -- 11
 (8, 'RAD',  'XR2', NULL, 'ROOM'),   -- 12
 (8, 'RAD',  'US1', NULL, 'ROOM'),   -- 13
 (8, 'RAD',  'MAM', NULL, 'ROOM');   -- 14

INSERT INTO adt.practitioner (staff_no, npi, family_name, given_name, credentials, role, specialty, department_id, phone, email) VALUES
 ('E10231', '1467583920', 'Patel',    'Anjali',  'MD',       'PHYSICIAN',    'Family Medicine',        4, '217-555-0141', 'apatel@segh.example.org'),     -- 1
 ('E10455', '1730291846', 'Novak',    'Peter',   'MD',       'PHYSICIAN',    'Emergency Medicine',     1, '217-555-0122', 'pnovak@segh.example.org'),     -- 2
 ('E10502', '1295837164', 'Alvarez',  'Carmen',  'MD',       'PHYSICIAN',    'Obstetrics & Gynecology',5, '217-555-0153', 'calvarez@segh.example.org'),   -- 3
 ('E10617', '1548302917', 'Bauer',    'Thomas',  'MD',       'PHYSICIAN',    'Hospital Medicine',      3, '217-555-0164', 'tbauer@segh.example.org'),     -- 4
 ('E10733', '1083746529', 'Kim',      'Daniel',  'MD',       'PHYSICIAN',    'Orthopedic Surgery',     6, '217-555-0175', 'dkim@segh.example.org'),       -- 5
 ('E10848', '1912384756', 'Haddad',   'Rami',    'MD',       'PHYSICIAN',    'Critical Care Medicine', 2, '217-555-0186', 'rhaddad@segh.example.org'),    -- 6
 ('E10911', '1376459201', 'Okonkwo',  'Ngozi',   'MD',       'PHYSICIAN',    'Diagnostic Radiology',   8, '217-555-0197', 'nokonkwo@segh.example.org'),   -- 7
 ('E10925', '1629048375', 'Fischer',  'Laura',   'MD',       'PHYSICIAN',    'Breast Imaging',         8, '217-555-0198', 'lfischer@segh.example.org'),   -- 8
 ('E20114', NULL,         'Morales',  'Diego',   'MLS(ASCP)','TECHNOLOGIST', 'Clinical Chemistry',     9, '217-555-0210', 'dmorales@segh.example.org'),   -- 9
 ('E10388', '1851726394', 'Wong',     'Helen',   'MD',       'PATHOLOGIST',  'Clinical Pathology',     9, '217-555-0211', 'hwong@segh.example.org'),      -- 10
 ('E30561', NULL,         'Santos',   'Ana',     'RN',       'NURSE',        NULL,                     1, NULL,           'asantos@segh.example.org'),    -- 11
 ('E20877', NULL,         'Brown',    'Kevin',   'RT(R)(CT)','TECHNOLOGIST', 'CT / Radiography',       8, NULL,           'kbrown@segh.example.org'),     -- 12
 ('E10790', '1508273649', 'Ivanova',  'Elena',   'MD',       'PHYSICIAN',    'Pediatrics',             7, '217-555-0177', 'eivanova@segh.example.org'),   -- 13
 ('E20903', NULL,         'Nguyen',   'Linh',    'RDMS',     'TECHNOLOGIST', 'Sonography',             8, NULL,           'lnguyen@segh.example.org'),    -- 14
 ('E20915', NULL,         'Clarke',   'Rachel',  'RT(R)(MR)','TECHNOLOGIST', 'MRI',                    8, NULL,           'rclarke@segh.example.org'),    -- 15
 ('E20166', NULL,         'Osei',     'Kwame',   'MLS(ASCP)','TECHNOLOGIST', 'Microbiology',           9, NULL,           'kosei@segh.example.org');      -- 16

INSERT INTO adt.payer (payer_code, name, payer_type) VALUES
 ('MCR',   'Medicare Part A/B',               'MEDICARE'),    -- 1
 ('MCD-IL','Illinois Medicaid',               'MEDICAID'),    -- 2
 ('BCBSIL','Blue Cross Blue Shield of Illinois','COMMERCIAL'),-- 3
 ('AETNA', 'Aetna PPO',                       'COMMERCIAL'),  -- 4
 ('SELF',  'Self Pay',                        'SELF');        -- 5

-- ---------------------------------------------------------------------------
-- Patients (note: inconsistent phone formats & language values are intentional)
-- ---------------------------------------------------------------------------
INSERT INTO adt.patient (mrn, last_name, first_name, middle_name, dob, sex, ssn, addr_line1, addr_line2, city, state, zip, home_phone, mobile_phone, email, primary_language, race, ethnicity, marital_status, pcp_id, created_at) VALUES
 ('MRN00012345','GONZALEZ','MARIA','ELENA',  '1958-03-14','F','999-41-2231','482 Maple St',          NULL,      'Springfield','IL','62702',     '(217) 555-3412','217.555.9981','maria.gonzalez58@example.com','Spanish','White','Hispanic or Latino','M',1,'2011-06-02 10:14'),
 ('MRN00023456','SMITH',   'JOHN',  'ROBERT', '1971-08-22','M','999-52-8817','17 Lincoln Ave',        'Apt 3B',  'Springfield','IL','62703',     NULL,            '2175554420',  NULL,                          'English','White','Not Hispanic or Latino','D',NULL,'2019-02-11 22:47'),
 ('MRN00034567','KHAN',    'AISHA', NULL,     '1989-11-05','F','999-63-1094','905 Oak Ridge Dr',      NULL,      'Chatham',    'IL','62629',     NULL,            '(217)555-7765','aisha.k@example.com',         'ENG',    'Asian','Not Hispanic or Latino','M',NULL,'2026-05-20 09:02'),
 ('MRN00045678','CHEN',    'ROBERT','W',      '1945-01-30','M','999-74-5520','3301 Westwood Ln',      NULL,      'Springfield','IL','62704-3315','217-555-1209',  NULL,          NULL,                          'Chinese','Asian','Not Hispanic or Latino','W',1,'2008-09-15 13:30'),
 ('MRN00056789','JOHNSON', 'EMILY', 'ROSE',   '1995-06-17','F','999-85-3367','220 College St',        'Unit 12', 'Springfield','IL','62701',     NULL,            '217-555-0388','emily.r.johnson@example.com', 'English','Black or African American','Not Hispanic or Latino','S',NULL,'2022-09-03 16:41'),
 ('MRN00067890','OKAFOR',  'DAVID', 'CHUKWUDI','1963-12-02','M','999-96-4402','76 Sangamon Ave',       NULL,      'Springfield','IL','62702',     '217 555 6610',  NULL,          NULL,                          'English','Black or African American','Not Hispanic or Latino','M',4,'2015-01-21 08:05'),
 ('MRN00078901','MARTINEZ','LINDA', NULL,     '1952-04-09','F','999-17-6650','1550 Bunn St',          NULL,      'Springfield','IL','62703',     '(217) 555-2290',NULL,          'lmartinez52@example.com',     'English','White','Hispanic or Latino','W',1,'2010-03-30 11:11'),
 ('MRN00089012','WILSON',  'JAMES', 'T',      '1980-10-28','M',NULL,         '8 Cardinal Ct',         NULL,      'Rochester',  'IL','62563',     NULL,            '217-555-8834','jtwilson@example.com',        'English','White','Not Hispanic or Latino','M',1,'2024-07-07 15:20'),
 ('MRN00090123','ROSSI',   'SOFIA', NULL,     '2018-02-12','F',NULL,         '640 Iles Ave',          NULL,      'Springfield','IL','62704',     '217-555-4471',  NULL,          NULL,                          'English','White','Not Hispanic or Latino','S',13,'2018-02-12 07:55'),
 ('MRN00101234','HASSAN',  'AHMED', NULL,     '1977-07-01','M','999-28-7713','2215 S MacArthur Blvd', NULL,      'Springfield','IL','62704',     NULL,            '(217) 555-5050','ahassan77@example.com',      'Arabic', 'White','Not Hispanic or Latino','M',1,'2020-11-12 10:00'),
 ('MRN00098712','GONZALES','MARIA', NULL,     '1958-03-14','F',NULL,         '482 Maple Street',      NULL,      'Springfield','IL','62702',     NULL,            '217.555.9981',NULL,                          'SPA',    NULL,   NULL,'U',NULL,'2023-01-09 03:12'),
 ('MRN00112345','LEE',     'GRACE', 'MIN-JI', '1990-09-23','F','999-39-0028','99 Clearlake Ave',      NULL,      'Springfield','IL','62702',     NULL,            '217-555-1737','grace.lee@example.com',       'Korean', 'Asian','Not Hispanic or Latino','S',NULL,'2026-10-30 14:25');

-- duplicate registration from a 2023 ED visit, merged by HIM into patient 1
UPDATE adt.patient SET active = false, merged_into_patient_id = 1, updated_at = '2023-02-14 09:30' WHERE patient_id = 11;

INSERT INTO adt.patient_identifier (patient_id, id_type, id_value, assigning_authority) VALUES
 (1,'MR','MRN00012345','SEGH'), (2,'MR','MRN00023456','SEGH'), (3,'MR','MRN00034567','SEGH'),
 (4,'MR','MRN00045678','SEGH'), (5,'MR','MRN00056789','SEGH'), (6,'MR','MRN00067890','SEGH'),
 (7,'MR','MRN00078901','SEGH'), (8,'MR','MRN00089012','SEGH'), (9,'MR','MRN00090123','SEGH'),
 (10,'MR','MRN00101234','SEGH'), (11,'MR','MRN00098712','SEGH'), (12,'MR','MRN00112345','SEGH'),
 (1,'SS','999-41-2231','SSA'), (2,'SS','999-52-8817','SSA'), (4,'SS','999-74-5520','SSA'),
 (2,'DL','S530-4417-1822','IL-SOS'),
 (1,'MB','1EG4TE5MK73','CMS'), (4,'MB','7XR2KD9PL04','CMS'), (7,'MB','3HN8WQ1JC56','CMS'),
 (1,'PI','pt-0f3a9c1e','MYCHART'), (5,'PI','pt-7be21d44','MYCHART'), (10,'PI','pt-c9d00a17','MYCHART');

INSERT INTO adt.patient_contact (patient_id, relationship, contact_role, full_name, phone) VALUES
 (1, 'SPOUSE', 'EMC', 'Luis Gonzalez',   '217.555.9982'),
 (3, 'SPOUSE', 'EMC', 'Omar Khan',       '(217)555-7766'),
 (4, 'CHILD',  'NOK', 'Jennifer Chen-Morris', '312-555-0912'),
 (6, 'SPOUSE', 'EMC', 'Ngozi Okafor',    '217 555 6611'),
 (9, 'MOTHER', 'GRD', 'Chiara Rossi',    '217-555-4471'),
 (9, 'FATHER', 'GRD', 'Marco Rossi',     '217-555-4472');

INSERT INTO adt.patient_coverage (patient_id, payer_id, member_id, group_no, subscriber_rel, priority, effective_from, effective_to) VALUES
 (1, 1, '1EG4TE5MK73', NULL,       'SELF',   1, '2023-04-01', NULL),
 (1, 3, 'XOF884512001','SUPP-220', 'SELF',   2, '2023-04-01', NULL),
 (2, 4, 'W188273645',  'G-70021',  'SELF',   1, '2025-01-01', NULL),
 (3, 3, 'XOF551209876','G-11873',  'SPOUSE', 1, '2026-01-01', NULL),
 (4, 1, '7XR2KD9PL04', NULL,       'SELF',   1, '2010-02-01', NULL),
 (5, 2, '880214773',   NULL,       'SELF',   1, '2026-03-01', '2027-02-28'),
 (6, 3, 'XOF330018472','G-50440',  'SELF',   1, '2021-07-01', NULL),
 (7, 1, '3HN8WQ1JC56', NULL,       'SELF',   1, '2017-05-01', NULL),
 (8, 4, 'W992817364',  'G-70021',  'SELF',   1, '2024-07-01', NULL),
 (9, 3, 'XOF771234560','G-33019',  'CHILD',  1, '2018-02-12', NULL),
 (10,4, 'W410293857',  'G-81104',  'SELF',   1, '2020-11-01', NULL),
 (12,5, NULL,          NULL,       'SELF',   1, '2026-10-30', NULL);

INSERT INTO adt.allergy (patient_id, allergen_text, allergen_type, reaction, severity, noted_on, status) VALUES
 (1, 'Penicillin',            'DA', 'Hives',               'MO', '1999-05-10', 'ACTIVE'),
 (1, 'SULFA DRUGS',           'DA', 'rash',                'MI', NULL,         'ACTIVE'),
 (4, 'Iodinated contrast',    'DA', 'Itching, flushing',   'MI', '2016-08-22', 'ACTIVE'),
 (6, 'NKDA',                  NULL, NULL,                  NULL, '2015-01-21', 'ACTIVE'),
 (9, 'Peanuts',               'FA', 'Anaphylaxis',         'SV', '2020-04-03', 'ACTIVE'),
 (10,'Codeine',               'DA', 'Nausea/vomiting',     'MI', '2020-11-12', 'ACTIVE'),
 (7, 'Latex',                 'EA', 'Contact dermatitis',  'MI', '2012-01-15', 'INACTIVE');

-- ---------------------------------------------------------------------------
-- Encounters
-- ---------------------------------------------------------------------------
INSERT INTO adt.encounter (visit_number, patient_id, patient_class, admit_type, department_id, location_id, attending_id, referring_id, admit_dt, discharge_dt, chief_complaint, discharge_disposition, status, payer_id) VALUES
 ('V2610010001', 1, 'O', 'ROUTINE',  4, 7,  1, NULL, '2026-10-01 09:15','2026-10-01 09:52','Diabetes follow-up, med refill',               '01','DISCHARGED',1), -- 1
 ('V2610030002', 2, 'E', 'EMERGENCY',1, 2,  2, NULL, '2026-10-03 22:41','2026-10-04 06:12','Chest pain x 2 hrs, SOB',                      '01','DISCHARGED',4), -- 2
 ('V2610050003', 3, 'O', 'ROUTINE',  5, 8,  3, NULL, '2026-10-05 10:02','2026-10-05 10:48','Prenatal visit, 20 weeks',                     '01','DISCHARGED',3), -- 3
 ('V2610070004', 4, 'I', 'EMERGENCY',3, 5,  4, 2,    '2026-10-07 14:22','2026-10-10 11:05','Fall at home, struck head, on apixaban',       '03','DISCHARGED',1), -- 4
 ('V2610080005', 5, 'O', 'URGENT',   6, 9,  5, 1,    '2026-10-08 13:30','2026-10-08 14:15','R knee injury playing soccer, swelling',       '01','DISCHARGED',2), -- 5
 ('V2610120006', 6, 'I', 'EMERGENCY',2, 4,  6, 2,    '2026-10-12 03:17','2026-10-19 15:02','Fever, rigors, hypotension, dysuria',          '01','DISCHARGED',3), -- 6
 ('V2610140007', 7, 'O', 'ROUTINE',  4, 7,  1, NULL, '2026-10-14 08:30','2026-10-14 09:40','Annual exam; screening mammogram; fatigue',    '01','DISCHARGED',1), -- 7
 ('V2610160008', 8, 'O', 'URGENT',   4, 7,  1, NULL, '2026-10-16 11:00','2026-10-16 11:35','RUQ pain after meals x 3 wks',                 '01','DISCHARGED',4), -- 8
 ('V2610200009', 9, 'E', 'EMERGENCY',1, 3,  2, 13,   '2026-10-20 19:05','2026-10-20 20:30','Sore throat, fever 39.2C',                     '01','DISCHARGED',3), -- 9
 ('V2610220010',10, 'O', 'ROUTINE',  4, 7,  1, NULL, '2026-10-22 08:00','2026-10-22 08:40','Annual physical',                              '01','DISCHARGED',4), -- 10
 ('V2611030011', 1, 'O', 'URGENT',   4, 7,  1, NULL, '2026-11-03 15:10','2026-11-03 15:45','Cough x 10 days, low grade fever',              '01','DISCHARGED',1), -- 11
 ('V2611100012', 6, 'P', 'ELECTIVE', 4, NULL,1, 6,   '2026-11-10 09:00', NULL,             'Post-hospitalization follow-up',               NULL,'PREADMIT', 3); -- 12

INSERT INTO adt.encounter_diagnosis (encounter_id, seq, icd10_code, description, dx_type) VALUES
 (1, 1, 'E11.65',  'Type 2 diabetes mellitus with hyperglycemia', 'F'),
 (1, 2, 'E78.5',   'Hyperlipidemia, unspecified', 'F'),
 (1, 3, 'I10',     'Essential (primary) hypertension', 'F'),
 (2, 1, 'R07.9',   'Chest pain, unspecified', 'A'),
 (2, 2, 'R07.89',  'Other chest pain', 'F'),
 (3, 1, 'Z3482',   'Encounter for supervision of normal pregnancy, second trimester', 'F'),   -- no decimal (legacy feed)
 (3, 2, 'O99.012', 'Anemia complicating pregnancy, second trimester', 'F'),
 (4, 1, 'W19.XXXA','Unspecified fall, initial encounter', 'A'),
 (4, 2, 'S09.90XA','Unspecified injury of head, initial encounter', 'F'),
 (4, 3, 'E87.1',   'Hypo-osmolality and hyponatremia', 'F'),
 (4, 4, 'N17.9',   'Acute kidney failure, unspecified', 'F'),
 (5, 1, 'S83.511A','Sprain of anterior cruciate ligament of right knee, initial encounter', 'F'),
 (6, 1, 'R65.21',  'Severe sepsis with septic shock', 'A'),
 (6, 2, 'A41.51',  'Sepsis due to Escherichia coli [E. coli]', 'F'),
 (6, 3, 'N10',     'Acute pyelonephritis', 'F'),
 (6, 4, 'N17.9',   'Acute kidney failure, unspecified', 'F'),
 (7, 1, 'Z00.00',  'Encounter for general adult medical examination without abnormal findings', 'F'),
 (7, 2, 'Z12.31',  'Encounter for screening mammogram for malignant neoplasm of breast', 'F'),
 (7, 3, 'E03.9',   'Hypothyroidism, unspecified', 'W'),
 (8, 1, 'R10.11',  'Right upper quadrant pain', 'A'),
 (8, 2, 'K80.20',  'Calculus of gallbladder without cholecystitis without obstruction', 'F'),
 (9, 1, 'J02.0',   'Streptococcal pharyngitis', 'F'),
 (10,1, 'Z00.00',  'Encounter for general adult medical examination without abnormal findings', 'F'),
 (10,2, 'R73.03',  'Prediabetes', 'F'),
 (10,3, 'E78.2',   'Mixed hyperlipidemia', 'F'),
 (11,1, 'R05.9',   'Cough, unspecified', 'W');

INSERT INTO adt.encounter_location_history (encounter_id, location_id, event_type, start_dt, end_dt) VALUES
 (2, 2, 'A04', '2026-10-03 22:41', '2026-10-04 06:12'),
 (4, 1, 'A04', '2026-10-07 14:22', '2026-10-07 19:40'),
 (4, 6, 'A01', '2026-10-07 19:40', '2026-10-08 10:15'),
 (4, 5, 'A02', '2026-10-08 10:15', '2026-10-10 11:05'),
 (6, 1, 'A04', '2026-10-12 03:17', '2026-10-12 06:30'),
 (6, 4, 'A01', '2026-10-12 06:30', '2026-10-15 13:00'),
 (6, 6, 'A02', '2026-10-15 13:00', '2026-10-19 15:02'),
 (9, 3, 'A04', '2026-10-20 19:05', '2026-10-20 20:30');

-- =============================================================================
-- LIS reference data
-- =============================================================================

INSERT INTO lis.section (section_code, name) VALUES
 ('HEM','Hematology'), ('CHEM','Clinical Chemistry'), ('IMM','Immunoassay / Special Chemistry'),
 ('UA','Urinalysis'), ('MICRO','Microbiology');

INSERT INTO lis.instrument (instrument_code, manufacturer, model, serial_no, section_id) VALUES
 ('XN1',   'Sysmex',       'XN-1000',       'XN-24871', 1),   -- 1
 ('C503A', 'Roche',        'cobas c 503',   'C5-11093', 2),   -- 2
 ('E801A', 'Roche',        'cobas e 801',   'E8-30217', 3),   -- 3
 ('CLT1',  'Siemens',      'CLINITEK Novus','CN-00421', 4),   -- 4
 ('BCTFX', 'BD',           'BACTEC FX',     'BFX-7781', 5),   -- 5
 ('VTK2',  'bioMerieux',   'VITEK 2 XL',    'VK2-5520', 5),   -- 6
 ('D100',  'Bio-Rad',      'D-100',         'D1-90012', 3);   -- 7 HbA1c HPLC

INSERT INTO lis.specimen_type (code, description, container, snomed_code) VALUES
 ('SST',  'Serum',                      'Gold top SST 5 mL',          '119364003'),  -- 1
 ('EDTA', 'Whole blood EDTA',           'Lavender top K2EDTA 4 mL',   '445295009'),  -- 2
 ('NAF',  'Plasma, sodium fluoride',    'Gray top NaF/KOx 4 mL',      NULL),         -- 3
 ('UR',   'Urine, random clean catch',  'Sterile urine cup',          '122575003'),  -- 4
 ('BCB',  'Blood, culture bottle',      'BACTEC Plus Aerobic/F',      '119297000'),  -- 5
 ('THR',  'Throat swab',                'Swab, rayon tipped',         '258529004'),  -- 6
 ('LIH',  'Plasma, lithium heparin',    'Light green PST 4.5 mL',     NULL);         -- 7

-- single tests / components
INSERT INTO lis.test_catalog (test_code, test_name, short_name, is_panel, orderable, section_id, specimen_type_id, loinc_code, result_type, units, ref_low, ref_high, ref_text, critical_low, critical_high, default_instrument_id, cpt_code) VALUES
 -- hematology
 ('WBC',  'White blood cell count',   'WBC',  false,false,1,2,'6690-2', 'NM','x10E3/uL',4.0, 11.0, '4.0-11.0',  2.0, 30.0,1,NULL),
 ('RBC',  'Red blood cell count',     'RBC',  false,false,1,2,'789-8',  'NM','x10E6/uL',4.20,5.90, '4.20-5.90', NULL,NULL,1,NULL),
 ('HGB',  'Hemoglobin',               'Hgb',  false,false,1,2,'718-7',  'NM','g/dL',    12.0,17.5, '12.0-17.5', 7.0, 20.0,1,NULL),
 ('HCT',  'Hematocrit',               'Hct',  false,false,1,2,'4544-3', 'NM','%',       36.0,52.0, '36.0-52.0', 20.0,60.0,1,NULL),
 ('MCV',  'Mean corpuscular volume',  'MCV',  false,false,1,2,'787-2',  'NM','fL',      80,  100,  '80-100',    NULL,NULL,1,NULL),
 ('PLT',  'Platelet count',           'Plt',  false,false,1,2,'777-3',  'NM','x10E3/uL',150, 400,  '150-400',   20,  1000,1,NULL),
 -- chemistry
 ('NA',   'Sodium',                   'Na',   false,true, 2,1,'2951-2', 'NM','mmol/L',  135, 145,  '135-145',   120, 160, 2,'84295'),
 ('K',    'Potassium',                'K',    false,true, 2,1,'2823-3', 'NM','mmol/L',  3.5, 5.1,  '3.5-5.1',   2.8, 6.2, 2,'84132'),
 ('CL',   'Chloride',                 'Cl',   false,false,2,1,'2075-0', 'NM','mmol/L',  98,  107,  '98-107',    NULL,NULL,2,NULL),
 ('CO2',  'Carbon dioxide, total',    'CO2',  false,false,2,1,'2028-9', 'NM','mmol/L',  22,  29,   '22-29',     10,  40,  2,NULL),
 ('BUN',  'Urea nitrogen',            'BUN',  false,false,2,1,'3094-0', 'NM','mg/dL',   7,   20,   '7-20',      NULL,NULL,2,NULL),
 ('CREA', 'Creatinine',               'Creat',false,true, 2,1,'2160-0', 'NM','mg/dL',   0.60,1.30, '0.60-1.30', NULL,NULL,2,'82565'),
 ('GLU',  'Glucose',                  'Glu',  false,true, 2,1,'2345-7', 'NM','mg/dL',   70,  99,   '70-99',     40,  500, 2,'82947'),
 ('ALT',  'Alanine aminotransferase', 'ALT',  false,false,2,1,'1742-6', 'NM','U/L',     7,   56,   '7-56',      NULL,NULL,2,NULL),
 ('AST',  'Aspartate aminotransferase','AST', false,false,2,1,'1920-8', 'NM','U/L',     10,  40,   '10-40',     NULL,NULL,2,NULL),
 ('ALP',  'Alkaline phosphatase',     'ALP',  false,false,2,1,'6768-6', 'NM','U/L',     44,  147,  '44-147',    NULL,NULL,2,NULL),
 ('TBIL', 'Bilirubin, total',         'TBili',false,false,2,1,'1975-2', 'NM','mg/dL',   0.1, 1.2,  '0.1-1.2',   NULL,NULL,2,NULL),
 ('ALB',  'Albumin',                  'Alb',  false,false,2,1,'1751-7', 'NM','g/dL',    3.5, 5.0,  '3.5-5.0',   NULL,NULL,2,NULL),
 ('CHOL', 'Cholesterol, total',       'Chol', false,false,2,1,'2093-3', 'NM','mg/dL',   NULL,200,  '<200',      NULL,NULL,2,NULL),
 ('TRIG', 'Triglycerides',            'Trig', false,false,2,1,'2571-8', 'NM','mg/dL',   NULL,150,  '<150',      NULL,NULL,2,NULL),
 ('HDL',  'HDL cholesterol',          'HDL',  false,false,2,1,'2085-9', 'NM','mg/dL',   40,  NULL, '>40',       NULL,NULL,2,NULL),
 ('LDLC', 'LDL cholesterol, calculated','LDL',false,false,2,1,'13457-7','NM','mg/dL',   NULL,100,  '<100',      NULL,NULL,2,NULL),
 ('LACT', 'Lactic acid',              'Lact', false,true, 2,3,'2524-7', 'NM','mmol/L',  0.5, 2.2,  '0.5-2.2',   NULL,4.0, 2,'83605'),
 -- immunoassay
 ('HBA1C','Hemoglobin A1c',           'A1c',  false,true, 3,2,'4548-4', 'NM','%',       4.0, 5.6,  '4.0-5.6',   NULL,NULL,7,'83036'),
 ('TSH',  'Thyroid stimulating hormone','TSH',false,true, 3,1,'3016-3', 'NM','uIU/mL',  0.40,4.00, '0.40-4.00', NULL,NULL,3,'84443'),
 ('TROPHS','Troponin I, high sensitivity','hsTnI',false,true,3,1,'89579-7','NM','ng/L', NULL,34,   '<=34',      NULL,NULL,3,'84484'),
 -- urinalysis
 ('UCOL', 'Urine color',              'Color',false,false,4,4,'5778-6', 'ST',NULL,      NULL,NULL, 'Yellow',    NULL,NULL,4,NULL),
 ('UPH',  'Urine pH',                 'pH',   false,false,4,4,'5803-2', 'NM','[pH]',    5.0, 8.0,  '5.0-8.0',   NULL,NULL,4,NULL),
 ('USG',  'Urine specific gravity',   'SG',   false,false,4,4,'5811-5', 'NM',NULL,      1.005,1.030,'1.005-1.030',NULL,NULL,4,NULL),
 ('UPRO', 'Urine protein',            'Prot', false,false,4,4,'5804-0', 'CE',NULL,      NULL,NULL, 'Negative',  NULL,NULL,4,NULL),
 ('UGLU', 'Urine glucose',            'Glu',  false,false,4,4,'5792-7', 'CE',NULL,      NULL,NULL, 'Negative',  NULL,NULL,4,NULL),
 ('ULEU', 'Urine leukocyte esterase', 'LE',   false,false,4,4,'5799-2', 'CE',NULL,      NULL,NULL, 'Negative',  NULL,NULL,4,NULL),
 ('UNIT', 'Urine nitrite',            'Nit',  false,false,4,4,'5802-4', 'CE',NULL,      NULL,NULL, 'Negative',  NULL,NULL,4,NULL),
 -- microbiology
 ('BCX',  'Blood culture',            'BCx',  false,true, 5,5,'600-7',  'CULT',NULL,    NULL,NULL, 'No growth', NULL,NULL,5,'87040'),
 ('STREPA','Rapid Strep A antigen',   'StrepA',false,true,5,6,'78012-2','CE',NULL,      NULL,NULL, 'Negative',  NULL,NULL,NULL,'87880'),
 -- send-out, not mapped to LOINC (typical gap)
 ('SO-VITD','Vitamin D 25-OH (send out)','VitD',false,true,3,1,NULL,    'NM','ng/mL',   30,  100,  '30-100',    NULL,NULL,NULL,'82306');

-- panels
INSERT INTO lis.test_catalog (test_code, test_name, short_name, is_panel, orderable, section_id, specimen_type_id, loinc_code, result_type, cpt_code) VALUES
 ('CBC',   'Complete blood count',         'CBC',   true, true, 1, 2, '58410-2', NULL, '85027'),
 ('BMP',   'Basic metabolic panel',        'BMP',   true, true, 2, 1, '51990-0', NULL, '80048'),
 ('LIPID', 'Lipid panel',                  'Lipid', true, true, 2, 1, '57698-3', NULL, '80061'),
 ('HEPF',  'Hepatic function panel',       'HFP',   true, true, 2, 1, '24325-3', NULL, '80076'),
 ('UA',    'Urinalysis, dipstick',         'UA',    true, true, 4, 4, '24356-8', NULL, '81003');

INSERT INTO lis.panel_component (panel_test_id, component_test_id, seq)
SELECT p.test_id, c.test_id, v.seq
FROM (VALUES
  ('CBC','WBC',1),('CBC','RBC',2),('CBC','HGB',3),('CBC','HCT',4),('CBC','MCV',5),('CBC','PLT',6),
  ('BMP','NA',1),('BMP','K',2),('BMP','CL',3),('BMP','CO2',4),('BMP','BUN',5),('BMP','CREA',6),('BMP','GLU',7),
  ('LIPID','CHOL',1),('LIPID','TRIG',2),('LIPID','HDL',3),('LIPID','LDLC',4),
  ('HEPF','ALT',1),('HEPF','AST',2),('HEPF','ALP',3),('HEPF','TBIL',4),('HEPF','ALB',5),
  ('UA','UCOL',1),('UA','UPH',2),('UA','USG',3),('UA','UPRO',4),('UA','UGLU',5),('UA','ULEU',6),('UA','UNIT',7)
) v(panel, comp, seq)
JOIN lis.test_catalog p ON p.test_code = v.panel
JOIN lis.test_catalog c ON c.test_code = v.comp;

INSERT INTO lis.antibiotic (code, name, loinc_mic_code) VALUES
 ('AMP',  'Ampicillin',                      '28-1'),
 ('CRO',  'Ceftriaxone',                     '141-2'),
 ('CIP',  'Ciprofloxacin',                   '185-9'),
 ('GEN',  'Gentamicin',                      '267-5'),
 ('SXT',  'Trimethoprim-sulfamethoxazole',   '516-5'),
 ('TZP',  'Piperacillin-tazobactam',         NULL),
 ('MEM',  'Meropenem',                       NULL),
 ('NIT',  'Nitrofurantoin',                  NULL);

-- =============================================================================
-- LIS transactional data
-- =============================================================================

INSERT INTO lis.lab_order (accession_no, placer_order_no, patient_id, encounter_id, ordering_provider_id, priority, order_dt, clinical_info, status) VALUES
 ('L26100100014','EHR-7781201', 1, 1, 1, 'R','2026-10-01 09:25','T2DM f/u, fasting',            'CM'),  -- 1
 ('L26100300087','EHR-7783544', 2, 2, 2, 'S','2026-10-03 22:48','Chest pain r/o ACS',           'CM'),  -- 2
 ('L26100400009','EHR-7783561', 2, 2, 2, 'S','2026-10-04 01:50','Repeat hsTnI 3h',              'CM'),  -- 3
 ('L26100500031','EHR-7784102', 3, 3, 3, 'R','2026-10-05 10:30','Prenatal labs 20 wk',          'CM'),  -- 4
 ('L26100700112','EHR-7785009', 4, 4, 2, 'S','2026-10-07 14:40','Fall, on anticoagulation',     'CM'),  -- 5
 ('L26101200006','EHR-7788120', 6, 6, 2, 'S','2026-10-12 03:30','Sepsis bundle',                'CM'),  -- 6
 ('L26101400021','EHR-7789333', 6, 6, 6, 'R','2026-10-14 05:00','AM labs',                      'CM'),  -- 7
 ('L26101400048','EHR-7789410', 7, 7, 1, 'R','2026-10-14 08:55','Fatigue',                      'CM'),  -- 8
 ('L26101600052','EHR-7790221', 8, 8, 1, 'R','2026-10-16 11:20','RUQ pain',                     'CM'),  -- 9
 ('L26102000133','EHR-7792018', 9, 9, 2, 'S','2026-10-20 19:15','Pharyngitis',                  'CM'),  -- 10
 ('L26102200017','EHR-7792877',10,10, 1, 'R','2026-10-22 08:20','Annual, fasting',              'IP'),  -- 11
 ('L26111000001','EHR-7801150', 6,12, 1, 'R','2026-11-05 10:00','Post-discharge CBC',           'SC');  -- 12

INSERT INTO lis.order_item (order_id, test_id, status)
SELECT o.order_id, t.test_id, v.status
FROM (VALUES
  ('L26100100014','HBA1C','CM'),('L26100100014','LIPID','CM'),('L26100100014','BMP','CM'),
  ('L26100300087','TROPHS','CM'),('L26100300087','CBC','CM'),('L26100300087','BMP','CM'),
  ('L26100400009','TROPHS','CM'),
  ('L26100500031','CBC','CM'),('L26100500031','UA','CM'),
  ('L26100700112','CBC','CM'),('L26100700112','BMP','CM'),
  ('L26101200006','CBC','CM'),('L26101200006','BMP','CM'),('L26101200006','LACT','CM'),('L26101200006','BCX','CM'),
  ('L26101400021','CBC','CM'),('L26101400021','LACT','CM'),
  ('L26101400048','TSH','CM'),
  ('L26101600052','HEPF','CM'),('L26101600052','CBC','CM'),
  ('L26102000133','STREPA','CM'),
  ('L26102200017','LIPID','CM'),('L26102200017','HBA1C','CM'),('L26102200017','TSH','IP'),
  ('L26111000001','CBC','SC')
) v(acc, code, status)
JOIN lis.lab_order o ON o.accession_no = v.acc
JOIN lis.test_catalog t ON t.test_code = v.code;

INSERT INTO lis.specimen (order_id, barcode, specimen_type_id, body_site, collected_dt, collected_by_id, received_dt, condition)
SELECT o.order_id, v.barcode, st.specimen_type_id, v.site, v.coll::timestamp, v.coll_by, v.recv::timestamp, v.cond
FROM (VALUES
  ('L26100100014','L26100100014-01','SST', NULL,           '2026-10-01 09:32','2026-10-01 10:05',NULL,'OK'),
  ('L26100100014','L26100100014-02','EDTA',NULL,           '2026-10-01 09:32','2026-10-01 10:05',NULL,'OK'),
  ('L26100300087','L26100300087-01','SST', NULL,           '2026-10-03 22:55','2026-10-03 23:04',11,  'OK'),
  ('L26100300087','L26100300087-02','EDTA',NULL,           '2026-10-03 22:55','2026-10-03 23:04',11,  'OK'),
  ('L26100400009','L26100400009-01','SST', NULL,           '2026-10-04 01:58','2026-10-04 02:06',11,  'OK'),
  ('L26100500031','L26100500031-01','EDTA',NULL,           '2026-10-05 10:35','2026-10-05 11:20',NULL,'OK'),
  ('L26100500031','L26100500031-02','UR',  NULL,           '2026-10-05 10:40','2026-10-05 11:20',NULL,'OK'),
  ('L26100700112','L26100700112-01','SST', NULL,           '2026-10-07 14:51','2026-10-07 15:02',11,  'OK'),
  ('L26100700112','L26100700112-02','EDTA',NULL,           '2026-10-07 14:51','2026-10-07 15:02',11,  'OK'),
  ('L26101200006','L26101200006-01','SST', NULL,           '2026-10-12 03:41','2026-10-12 03:52',11,  'HEMOLYZED'),
  ('L26101200006','L26101200006-02','EDTA',NULL,           '2026-10-12 03:41','2026-10-12 03:52',11,  'OK'),
  ('L26101200006','L26101200006-03','NAF', NULL,           '2026-10-12 03:41','2026-10-12 03:52',11,  'OK'),
  ('L26101200006','L26101200006-04','BCB', 'Left antecubital', '2026-10-12 03:44','2026-10-12 04:10',11,  'OK'),
  ('L26101200006','L26101200006-05','BCB', 'Right hand',   '2026-10-12 03:58','2026-10-12 04:10',11,  'OK'),
  ('L26101200006','L26101200006-06','SST', NULL,           '2026-10-12 04:35','2026-10-12 04:41',11,  'OK'),   -- recollect
  ('L26101400021','L26101400021-01','EDTA',NULL,           '2026-10-14 04:55','2026-10-14 05:20',NULL,'OK'),
  ('L26101400021','L26101400021-02','NAF', NULL,           '2026-10-14 04:55','2026-10-14 05:20',NULL,'OK'),
  ('L26101400048','L26101400048-01','SST', NULL,           '2026-10-14 09:05','2026-10-14 10:30',NULL,'OK'),
  ('L26101600052','L26101600052-01','SST', NULL,           '2026-10-16 11:28','2026-10-16 12:15',NULL,'OK'),
  ('L26101600052','L26101600052-02','EDTA',NULL,           '2026-10-16 11:28','2026-10-16 12:15',NULL,'OK'),
  ('L26102000133','L26102000133-01','THR', 'Posterior pharynx','2026-10-20 19:20','2026-10-20 19:24',11,'OK'),
  ('L26102200017','L26102200017-01','SST', NULL,           '2026-10-22 08:25','2026-10-22 09:40',NULL,'LIPEMIC'),
  ('L26102200017','L26102200017-02','EDTA',NULL,           '2026-10-22 08:25','2026-10-22 09:40',NULL,'OK')
) v(acc, barcode, stype, site, coll, recv, coll_by, cond)
JOIN lis.lab_order o ON o.accession_no = v.acc
JOIN lis.specimen_type st ON st.code = v.stype;

UPDATE lis.specimen SET rejected = true, reject_reason = 'Grossly hemolyzed - K+ not reportable, recollect requested'
WHERE barcode = 'L26101200006-01';

-- Results. specimen is resolved by explicit barcode; order_item is resolved through the panel.
INSERT INTO lis.result (order_item_id, specimen_id, test_id, value_text, value_num, units, ref_range, abnormal_flag, result_status, instrument_id, performed_dt, verified_dt, verified_by_id, comment)
SELECT
  (SELECT oi.order_item_id FROM lis.order_item oi
    WHERE oi.order_id = o.order_id
      AND (oi.test_id = t.test_id
           OR EXISTS (SELECT 1 FROM lis.panel_component pc WHERE pc.panel_test_id = oi.test_id AND pc.component_test_id = t.test_id))
    ORDER BY oi.order_item_id LIMIT 1),
  s.specimen_id, t.test_id,
  v.val, CASE WHEN v.val ~ '^-?[0-9]+(\.[0-9]+)?$' THEN v.val::numeric END,
  t.units, t.ref_text, v.flag, v.status, t.default_instrument_id,
  v.perf::timestamp, CASE WHEN v.status <> 'P' THEN v.perf::timestamp + interval '7 min' END,
  v.verifier, v.cmt
FROM (VALUES
  -- enc 1: diabetic follow-up
  ('L26100100014-02','HBA1C','8.2',  'H','F','2026-10-01 11:40',9,NULL),
  ('L26100100014-01','CHOL', '212',  'H','F','2026-10-01 10:48',9,NULL),
  ('L26100100014-01','TRIG', '188',  'H','F','2026-10-01 10:48',9,NULL),
  ('L26100100014-01','HDL',  '42',   'N','F','2026-10-01 10:48',9,NULL),
  ('L26100100014-01','LDLC', '132',  'H','F','2026-10-01 10:48',9,'Calculated (Friedewald).'),
  ('L26100100014-01','NA',   '138',  'N','F','2026-10-01 10:48',9,NULL),
  ('L26100100014-01','K',    '4.6',  'N','F','2026-10-01 10:48',9,NULL),
  ('L26100100014-01','CL',   '101',  'N','F','2026-10-01 10:48',9,NULL),
  ('L26100100014-01','CO2',  '25',   'N','F','2026-10-01 10:48',9,NULL),
  ('L26100100014-01','BUN',  '22',   'H','F','2026-10-01 10:48',9,NULL),
  ('L26100100014-01','CREA', '1.10', 'N','F','2026-10-01 10:48',9,'eGFR (CKD-EPI 2021): 56 mL/min/1.73m2'),
  ('L26100100014-01','GLU',  '168',  'H','F','2026-10-01 10:48',9,NULL),
  -- enc 2: chest pain
  ('L26100300087-01','TROPHS','12',  'N','F','2026-10-03 23:31',9,NULL),
  ('L26100300087-02','WBC',  '9.8',  'N','F','2026-10-03 23:12',9,NULL),
  ('L26100300087-02','RBC',  '4.90', 'N','F','2026-10-03 23:12',9,NULL),
  ('L26100300087-02','HGB',  '14.8', 'N','F','2026-10-03 23:12',9,NULL),
  ('L26100300087-02','HCT',  '44.1', 'N','F','2026-10-03 23:12',9,NULL),
  ('L26100300087-02','MCV',  '90',   'N','F','2026-10-03 23:12',9,NULL),
  ('L26100300087-02','PLT',  '245',  'N','F','2026-10-03 23:12',9,NULL),
  ('L26100300087-01','NA',   '140',  'N','F','2026-10-03 23:25',9,NULL),
  ('L26100300087-01','K',    '4.1',  'N','F','2026-10-03 23:25',9,NULL),
  ('L26100300087-01','CL',   '103',  'N','F','2026-10-03 23:25',9,NULL),
  ('L26100300087-01','CO2',  '24',   'N','F','2026-10-03 23:25',9,NULL),
  ('L26100300087-01','BUN',  '15',   'N','F','2026-10-03 23:25',9,NULL),
  ('L26100300087-01','CREA', '0.90', 'N','F','2026-10-03 23:25',9,NULL),
  ('L26100300087-01','GLU',  '112',  'H','F','2026-10-03 23:25',9,'Non-fasting specimen.'),
  ('L26100400009-01','TROPHS','14',  'N','F','2026-10-04 02:38',9,'Delta from previous: +2 ng/L'),
  -- enc 3: prenatal
  ('L26100500031-01','WBC',  '10.2', 'N','F','2026-10-05 11:45',9,NULL),
  ('L26100500031-01','RBC',  '3.90', 'L','F','2026-10-05 11:45',9,NULL),
  ('L26100500031-01','HGB',  '10.9', 'L','F','2026-10-05 11:45',9,NULL),
  ('L26100500031-01','HCT',  '33.0', 'L','F','2026-10-05 11:45',9,NULL),
  ('L26100500031-01','MCV',  '84',   'N','F','2026-10-05 11:45',9,NULL),
  ('L26100500031-01','PLT',  '210',  'N','F','2026-10-05 11:45',9,NULL),
  ('L26100500031-02','UCOL', 'Yellow','N','F','2026-10-05 11:52',9,NULL),
  ('L26100500031-02','UPH',  '6.5',  'N','F','2026-10-05 11:52',9,NULL),
  ('L26100500031-02','USG',  '1.015','N','F','2026-10-05 11:52',9,NULL),
  ('L26100500031-02','UPRO', 'Negative','N','F','2026-10-05 11:52',9,NULL),
  ('L26100500031-02','UGLU', 'Negative','N','F','2026-10-05 11:52',9,NULL),
  ('L26100500031-02','ULEU', 'Trace','A','F','2026-10-05 11:52',9,NULL),
  ('L26100500031-02','UNIT', 'Negative','N','F','2026-10-05 11:52',9,NULL),
  -- enc 4: elderly fall
  ('L26100700112-02','WBC',  '11.8', 'H','F','2026-10-07 15:20',9,NULL),
  ('L26100700112-02','RBC',  '4.10', 'L','F','2026-10-07 15:20',9,NULL),
  ('L26100700112-02','HGB',  '12.4', 'N','F','2026-10-07 15:20',9,NULL),
  ('L26100700112-02','HCT',  '37.5', 'N','F','2026-10-07 15:20',9,NULL),
  ('L26100700112-02','MCV',  '95',   'N','F','2026-10-07 15:20',9,NULL),
  ('L26100700112-02','PLT',  '162',  'N','F','2026-10-07 15:20',9,NULL),
  ('L26100700112-01','NA',   '132',  'L','F','2026-10-07 15:34',9,NULL),
  ('L26100700112-01','K',    '3.3',  'L','F','2026-10-07 15:34',9,NULL),
  ('L26100700112-01','CL',   '97',   'L','F','2026-10-07 15:34',9,NULL),
  ('L26100700112-01','CO2',  '23',   'N','F','2026-10-07 15:34',9,NULL),
  ('L26100700112-01','BUN',  '28',   'H','F','2026-10-07 15:34',9,NULL),
  ('L26100700112-01','CREA', '1.40', 'H','F','2026-10-07 15:34',9,NULL),
  ('L26100700112-01','GLU',  '131',  'H','F','2026-10-07 15:34',9,NULL),
  -- enc 6: sepsis (K reported on recollected tube -06, corrected)
  ('L26101200006-02','WBC',  '18.6', 'H','F','2026-10-12 04:02',9,'Left shift noted on smear review.'),
  ('L26101200006-02','RBC',  '4.30', 'N','F','2026-10-12 04:02',9,NULL),
  ('L26101200006-02','HGB',  '12.8', 'N','F','2026-10-12 04:02',9,NULL),
  ('L26101200006-02','HCT',  '38.9', 'N','F','2026-10-12 04:02',9,NULL),
  ('L26101200006-02','MCV',  '88',   'N','F','2026-10-12 04:02',9,NULL),
  ('L26101200006-02','PLT',  '98',   'L','F','2026-10-12 04:02',9,NULL),
  ('L26101200006-06','NA',   '134',  'L','F','2026-10-12 05:05',9,NULL),
  ('L26101200006-06','K',    '5.4',  'H','C','2026-10-12 05:05',9,'CORRECTED RESULT. Previously reported 6.4 mmol/L on hemolyzed specimen L26101200006-01; recollected.'),
  ('L26101200006-06','CL',   '100',  'N','F','2026-10-12 05:05',9,NULL),
  ('L26101200006-06','CO2',  '17',   'L','F','2026-10-12 05:05',9,NULL),
  ('L26101200006-06','BUN',  '38',   'H','F','2026-10-12 05:05',9,NULL),
  ('L26101200006-06','CREA', '2.30', 'H','F','2026-10-12 05:05',9,'eGFR (CKD-EPI 2021): 32 mL/min/1.73m2'),
  ('L26101200006-06','GLU',  '189',  'H','F','2026-10-12 05:05',9,NULL),
  ('L26101200006-03','LACT', '4.8',  'HH','F','2026-10-12 04:08',9,'CRITICAL VALUE called to RN, read back verified.'),
  ('L26101200006-04','BCX',  'Escherichia coli','A','F','2026-10-15 09:30',16,'Positive in aerobic bottle at 14 h. Gram stain: Gram negative rods. Both sets positive.'),
  ('L26101400021-01','WBC',  '12.1', 'H','F','2026-10-14 05:45',9,NULL),
  ('L26101400021-01','RBC',  '4.00', 'L','F','2026-10-14 05:45',9,NULL),
  ('L26101400021-01','HGB',  '11.9', 'L','F','2026-10-14 05:45',9,NULL),
  ('L26101400021-01','HCT',  '36.2', 'N','F','2026-10-14 05:45',9,NULL),
  ('L26101400021-01','MCV',  '89',   'N','F','2026-10-14 05:45',9,NULL),
  ('L26101400021-01','PLT',  '134',  'L','F','2026-10-14 05:45',9,NULL),
  ('L26101400021-02','LACT', '1.6',  'N','F','2026-10-14 05:40',9,NULL),
  -- enc 7
  ('L26101400048-01','TSH',  '6.82', 'H','F','2026-10-14 12:10',9,NULL),
  -- enc 8
  ('L26101600052-01','ALT',  '88',   'H','F','2026-10-16 12:50',9,NULL),
  ('L26101600052-01','AST',  '72',   'H','F','2026-10-16 12:50',9,NULL),
  ('L26101600052-01','ALP',  '210',  'H','F','2026-10-16 12:50',9,NULL),
  ('L26101600052-01','TBIL', '2.1',  'H','F','2026-10-16 12:50',9,NULL),
  ('L26101600052-01','ALB',  '4.1',  'N','F','2026-10-16 12:50',9,NULL),
  ('L26101600052-02','WBC',  '8.4',  'N','F','2026-10-16 12:30',9,NULL),
  ('L26101600052-02','RBC',  '4.80', 'N','F','2026-10-16 12:30',9,NULL),
  ('L26101600052-02','HGB',  '14.9', 'N','F','2026-10-16 12:30',9,NULL),
  ('L26101600052-02','HCT',  '44.0', 'N','F','2026-10-16 12:30',9,NULL),
  ('L26101600052-02','MCV',  '91',   'N','F','2026-10-16 12:30',9,NULL),
  ('L26101600052-02','PLT',  '260',  'N','F','2026-10-16 12:30',9,NULL),
  -- enc 9
  ('L26102000133-01','STREPA','Positive','A','F','2026-10-20 19:38',16,NULL),
  -- enc 10 (TSH still pending -> no row)
  ('L26102200017-01','CHOL', '245',  'H','F','2026-10-22 10:30',9,'Specimen lipemic.'),
  ('L26102200017-01','TRIG', '310',  'H','F','2026-10-22 10:30',9,'Specimen lipemic.'),
  ('L26102200017-01','HDL',  '35',   'L','F','2026-10-22 10:30',9,NULL),
  ('L26102200017-01','LDLC', '148',  'H','F','2026-10-22 10:30',9,'Calculated (Friedewald).'),
  ('L26102200017-02','HBA1C','6.1',  'H','P','2026-10-22 11:15',NULL,'Preliminary - awaiting pathologist review.')
) v(barcode, code, val, flag, status, perf, verifier, cmt)
JOIN lis.specimen s ON s.barcode = v.barcode
JOIN lis.lab_order o ON o.order_id = s.order_id
JOIN lis.test_catalog t ON t.test_code = v.code;

INSERT INTO lis.critical_call (result_id, called_dt, called_by_id, called_to, read_back)
SELECT r.result_id, '2026-10-12 04:11', 9, 'Ana Santos RN, ED bay 7', true
FROM lis.result r JOIN lis.specimen s USING (specimen_id) JOIN lis.test_catalog t ON t.test_id = r.test_id
WHERE s.barcode = 'L26101200006-03' AND t.test_code = 'LACT';

INSERT INTO lis.micro_isolate (result_id, isolate_no, organism_code, organism_name, quantity, gram_stain)
SELECT r.result_id, 1, '112283007', 'Escherichia coli', 'Growth in 2/2 sets', 'Gram negative rods'
FROM lis.result r JOIN lis.test_catalog t ON t.test_id = r.test_id
WHERE t.test_code = 'BCX';

INSERT INTO lis.susceptibility (isolate_id, antibiotic_id, method, mic_value, interpretation, reported)
SELECT 1, a.antibiotic_id, 'MIC', v.mic, v.interp, v.rep
FROM (VALUES
  ('AMP','>=32','R',true), ('CRO','<=1','S',true), ('CIP','>=4','R',true), ('GEN','<=1','S',true),
  ('SXT','>=320','R',true), ('TZP','<=4','S',true), ('MEM','<=0.25','S',false), ('NIT','<=16','S',false)
) v(code, mic, interp, rep)
JOIN lis.antibiotic a ON a.code = v.code;

-- =============================================================================
-- RIS
-- =============================================================================

INSERT INTO ris.modality (modality_code, description) VALUES
 ('CR','Computed Radiography'), ('DX','Digital Radiography'), ('CT','Computed Tomography'),
 ('MR','Magnetic Resonance'), ('US','Ultrasound'), ('MG','Mammography');

INSERT INTO ris.procedure_catalog (procedure_code, description, modality_code, body_part, laterality_required, contrast, cpt_code, loinc_code, duration_min) VALUES
 ('XRCH2V',  'XR CHEST PA AND LATERAL',                  'DX','CHEST',   false,'NONE','71046','36643-5',10), -- 1
 ('XRCHPORT','XR CHEST 1 VIEW PORTABLE',                 'DX','CHEST',   false,'NONE','71045',NULL,     10), -- 2
 ('CTHDWO',  'CT HEAD/BRAIN WITHOUT CONTRAST',           'CT','HEAD',    false,'NONE','70450','30799-1',15), -- 3
 ('CTACHPE', 'CTA CHEST PULMONARY EMBOLISM PROTOCOL',    'CT','CHEST',   false,'IV',  '71275',NULL,     20), -- 4
 ('CTAPW',   'CT ABDOMEN PELVIS WITH CONTRAST',          'CT','ABDOMEN', false,'IV',  '74177',NULL,     20), -- 5
 ('MRKNWO',  'MRI KNEE WITHOUT CONTRAST',                'MR','KNEE',    true, 'NONE','73721',NULL,     40), -- 6
 ('USABDLTD','US ABDOMEN LIMITED (RUQ)',                 'US','ABDOMEN', false,'NONE','76705',NULL,     30), -- 7
 ('USOB2T',  'US OB >=14 WKS SINGLE GESTATION ANATOMY',  'US','PELVIS',  false,'NONE','76805',NULL,     45), -- 8
 ('MGSCRBI', 'MAMMO SCREENING BILATERAL W TOMO',         'MG','BREAST',  false,'NONE','77067','24606-6',20); -- 9

INSERT INTO ris.imaging_order (accession_no, placer_order_no, patient_id, encounter_id, procedure_id, laterality, priority, ordering_provider_id, reason_for_exam, reason_icd10, order_dt, status) VALUES
 ('R2610030000451','EHR-7783550', 2, 2, 1, NULL,'STAT',2,'Chest pain, SOB',                                  'R07.9',  '2026-10-03 22:50','COMPLETED'),   -- 1
 ('R2610040000012','EHR-7783570', 2, 2, 4, NULL,'STAT',2,'Pleuritic chest pain, tachycardia, r/o PE. Wells 4.5','R07.9', '2026-10-04 00:15','COMPLETED'),   -- 2
 ('R2610050000207','EHR-7784110', 3, 3, 8, NULL,'ROUT',3,'Anatomy scan 20w0d',                               'Z34.82', '2026-10-05 10:35','COMPLETED'),   -- 3
 ('R2610070000318','EHR-7785011', 4, 4, 3, NULL,'STAT',2,'Fall with head strike on apixaban',                'S09.90XA','2026-10-07 14:35','COMPLETED'),  -- 4
 ('R2610080000402','EHR-7785520', 5, 5, 6, 'R', 'URG', 5,'Twisting injury R knee, positive Lachman',         'S83.511A','2026-10-08 14:00','COMPLETED'),  -- 5
 ('R2610120000033','EHR-7788125', 6, 6, 2, NULL,'STAT',2,'Sepsis, source?',                                  'R65.21', '2026-10-12 03:35','COMPLETED'),   -- 6
 ('R2610140000154','EHR-7789401', 7, 7, 9, 'B', 'ROUT',1,'Annual screening',                                 'Z12.31', '2026-10-14 08:50','COMPLETED'),   -- 7
 ('R2610160000266','EHR-7790225', 8, 8, 7, NULL,'URG', 1,'RUQ pain, elevated LFTs',                          'R10.11', '2026-10-16 11:22','COMPLETED'),   -- 8
 ('R2611030000589','EHR-7800342', 1,11, 1, NULL,'ROUT',1,'Cough 10 days, r/o pneumonia',                     'R05.9',  '2026-11-03 15:30','COMPLETED'),   -- 9
 ('R2610120000035','EHR-7788127', 6, 6, 5, NULL,'STAT',6,'Sepsis, r/o abscess',                              'R65.21', '2026-10-12 05:20','CANCELLED');   -- 10 (AKI -> contrast held)

INSERT INTO ris.exam (imaging_order_id, scheduled_dt, begin_dt, end_dt, technologist_id, room, ae_title, contrast_agent, contrast_ml, dose_dlp_mgycm, tech_notes) VALUES
 (1, '2026-10-03 22:55','2026-10-03 23:08','2026-10-03 23:14',12,'XR2','SEGH_DX01', NULL, NULL, NULL, NULL),
 (2, '2026-10-04 00:30','2026-10-04 00:41','2026-10-04 00:52',12,'CT1','SEGH_CT01','Omnipaque 350',80.0,412.6,'20G R AC, 4 mL/s. Bolus tracking PA 100 HU.'),
 (3, '2026-10-05 11:00','2026-10-05 11:05','2026-10-05 11:48',14,'US1','SEGH_US01', NULL, NULL, NULL, 'Limited views of fetal heart due to fetal position; pt to return 2 wks.'),
 (4, '2026-10-07 14:45','2026-10-07 14:58','2026-10-07 15:03',12,'CT1','SEGH_CT01', NULL, NULL, 1021.3, NULL),
 (5, '2026-10-08 15:00','2026-10-08 15:12','2026-10-08 15:49',15,'MR1','SEGH_MR01', NULL, NULL, NULL, 'Pt tolerated well.'),
 (6, '2026-10-12 03:40','2026-10-12 03:52','2026-10-12 03:55',12,'MICU 204','SEGH_DX02', NULL, NULL, NULL, 'Portable AP semi-erect.'),
 (7, '2026-10-14 09:00','2026-10-14 09:06','2026-10-14 09:21',NULL,'MAM','SEGH_MG01', NULL, NULL, NULL, NULL),
 (8, '2026-10-16 13:00','2026-10-16 13:10','2026-10-16 13:35',14,'US1','SEGH_US01', NULL, NULL, NULL, 'NPO since 07:00.'),
 (9, '2026-11-03 15:40','2026-11-03 15:52','2026-11-03 15:58',12,'XR2','SEGH_DX01', NULL, NULL, NULL, NULL);

INSERT INTO ris.report (exam_id, version, status, dictated_by_id, signed_by_id, dictated_dt, signed_dt, clinical_history, technique, comparison, findings, impression, birads, critical_flag) VALUES
 (1,1,'F',7,7,'2026-10-03 23:40','2026-10-03 23:44',
  'Chest pain, shortness of breath.',
  'PA and lateral views of the chest.',
  'None.',
  'The lungs are clear. No pleural effusion or pneumothorax. Cardiomediastinal silhouette is within normal limits. No acute osseous abnormality.',
  'No acute cardiopulmonary process.', NULL, false),
 (2,1,'F',7,7,'2026-10-04 01:20','2026-10-04 01:26',
  'Pleuritic chest pain, tachycardia. Evaluate for pulmonary embolism.',
  'CT angiography of the chest was performed after IV administration of 80 mL Omnipaque 350. Multiplanar and MIP reformats.',
  'Radiograph same day.',
  'Adequate opacification of the pulmonary arteries to the subsegmental level. No filling defect to suggest pulmonary embolism. Heart size normal, no pericardial effusion. No consolidation. Mild dependent atelectasis bilaterally. No lymphadenopathy.',
  '1. No pulmonary embolism.
2. Mild bibasilar dependent atelectasis.', NULL, false),
 (3,1,'F',3,3,'2026-10-05 12:10','2026-10-05 16:02',
  'G2P1, 20w0d by LMP. Anatomy survey.',
  'Transabdominal ultrasound.',
  'Dating ultrasound 2026-07-02.',
  'Single live intrauterine gestation, cephalic. FHR 148 bpm. BPD 47 mm, HC 175 mm, AC 152 mm, FL 33 mm. EFW 331 g (52nd percentile). Placenta posterior, no previa. AFI normal. Fetal anatomy appears normal where visualized; cardiac outflow tracts incompletely visualized.',
  'Single live IUP at 20w1d by biometry, concordant with dates. Incomplete cardiac views; recommend follow-up in 2 weeks.', NULL, false),
 (4,1,'F',7,7,'2026-10-07 15:22','2026-10-07 15:25',
  'Fall at home with head strike. On apixaban.',
  'Axial non-contrast CT of the head with coronal and sagittal reformats.',
  'CT head 2016-08-22.',
  'No acute intracranial hemorrhage, mass effect, or midline shift. Gray-white differentiation preserved. Moderate periventricular white matter hypoattenuation, consistent with chronic small vessel ischemic disease, slightly progressed. Age-appropriate volume loss. Small right frontal scalp hematoma. No calvarial fracture.',
  '1. No acute intracranial abnormality.
2. Right frontal scalp hematoma without underlying fracture.
3. Chronic small vessel ischemic changes.', NULL, false),
 (5,1,'F',7,7,'2026-10-08 17:30','2026-10-08 17:41',
  'Twisting injury right knee, positive Lachman.',
  'Multiplanar multisequence MRI of the right knee without contrast.',
  'None.',
  'ACL: complete tear of the midsubstance with fiber discontinuity. PCL intact. MCL: grade 1 sprain. LCL complex intact. Menisci: small vertical tear of the posterior horn lateral meniscus. Bone marrow edema in the lateral femoral condyle and posterolateral tibial plateau (pivot-shift pattern). Moderate joint effusion.',
  '1. Complete ACL tear with pivot-shift bone contusion pattern.
2. Small vertical tear of the posterior horn of the lateral meniscus.
3. Grade 1 MCL sprain.', NULL, false),
 (6,1,'F',7,7,'2026-10-12 04:30','2026-10-12 04:36',
  'Sepsis, evaluate for source.',
  'Single portable AP view of the chest.',
  'Radiograph 2024-03-11.',
  'Lungs are clear without focal consolidation. No pleural effusion. Heart size normal.',
  'No radiographic evidence of pneumonia.', NULL, false),
 (7,1,'F',8,8,'2026-10-15 08:15','2026-10-15 08:20',
  'Annual screening. No complaints.',
  'Bilateral CC and MLO digital mammography with tomosynthesis. CAD reviewed.',
  'Mammograms 2025-10-09, 2024-10-02.',
  'The breasts are scattered areas of fibroglandular density (ACR B). No suspicious mass, calcifications, or architectural distortion. Stable benign-appearing calcifications left upper outer quadrant.',
  'Negative. BI-RADS 1. Recommend routine screening mammogram in 1 year.', '1', false),
 (8,1,'F',7,7,'2026-10-16 14:05','2026-10-16 14:11',
  'RUQ pain, elevated LFTs.',
  'Grayscale and color Doppler ultrasound of the right upper quadrant.',
  'None.',
  'Gallbladder: multiple mobile shadowing stones, the largest 1.4 cm. No wall thickening (2 mm). No pericholecystic fluid. Sonographic Murphy sign negative. CBD 5 mm. Liver normal size, mildly increased echogenicity. Right kidney unremarkable. Pancreas obscured by bowel gas.',
  '1. Cholelithiasis without sonographic evidence of acute cholecystitis.
2. Mild hepatic steatosis.', NULL, false),
 (9,1,'P',7,NULL,'2026-11-03 16:20',NULL,
  'Cough 10 days, low-grade fever.',
  'PA and lateral views of the chest.',
  'Radiograph 2023-01-09.',
  'Patchy opacity in the right lower lobe. No pleural effusion. Heart size normal.',
  'Right lower lobe opacity, compatible with pneumonia in the appropriate clinical setting. Follow-up radiograph in 6-8 weeks to document resolution.', NULL, false);

-- addendum on the CTA (reflects real-world report versioning)
INSERT INTO ris.report (exam_id, version, status, dictated_by_id, signed_by_id, dictated_dt, signed_dt, clinical_history, technique, comparison, findings, impression, critical_flag)
SELECT exam_id, 2, 'A', 7, 7, '2026-10-04 08:05', '2026-10-04 08:06', clinical_history, technique, comparison, findings,
       impression || E'\n\nADDENDUM: 4 mm right upper lobe pulmonary nodule (series 3, image 42). Per Fleischner guidelines, low-risk patient: no routine follow-up required.', false
FROM ris.report WHERE exam_id = 2 AND version = 1;

-- =============================================================================
-- PACS
-- =============================================================================

INSERT INTO pacs.ae (ae_title, modality_code, manufacturer, model, station_name, ip_address, port) VALUES
 ('SEGH_DX01','DX','Carestream',        'DRX-Evolution Plus','XRAY2',     '10.20.8.21',104),
 ('SEGH_DX02','DX','GE Healthcare',     'AMX Navigate',      'PORTABLE1', '10.20.8.22',104),
 ('SEGH_CT01','CT','Siemens Healthineers','SOMATOM go.Top',  'CT1',       '10.20.8.31',104),
 ('SEGH_MR01','MR','GE Healthcare',     'SIGNA Artist 1.5T', 'MR1',       '10.20.8.41',4006),
 ('SEGH_US01','US','Philips',           'EPIQ Elite',        'US1',       '10.20.8.51',104),
 ('SEGH_MG01','MG','Hologic',           'Selenia Dimensions','MAMMO1',    '10.20.8.61',104),
 ('SEGH_PACS', NULL,'Sectra',           'IDS7 Archive',      'PACS',      '10.20.1.10',11112);

-- one study per completed exam; UID root 1.2.826.0.1.3680043.10.999 is fictional
INSERT INTO pacs.study (study_instance_uid, accession_no, patient_mrn, patient_name, patient_birth_date, patient_sex, study_date, study_time, study_description, modalities_in_study, referring_physician, received_dt)
SELECT
  '1.2.826.0.1.3680043.10.999.1.' || io.imaging_order_id || '.' || to_char(e.begin_dt,'YYYYMMDDHH24MISS'),
  io.accession_no, p.mrn,
  p.last_name || '^' || p.first_name || coalesce('^' || p.middle_name, ''),
  to_char(p.dob,'YYYYMMDD'), p.sex,
  to_char(e.begin_dt,'YYYYMMDD'), to_char(e.begin_dt,'HH24MISS'),
  pc.description, pc.modality_code,
  upper(rp.family_name) || '^' || upper(rp.given_name),
  e.end_dt + interval '2 min'
FROM ris.exam e
JOIN ris.imaging_order io USING (imaging_order_id)
JOIN ris.procedure_catalog pc USING (procedure_id)
JOIN adt.patient p ON p.patient_id = io.patient_id
LEFT JOIN adt.practitioner rp ON rp.practitioner_id = io.ordering_provider_id
ORDER BY e.exam_id;

INSERT INTO pacs.series (study_pk, series_instance_uid, series_number, modality_code, series_description, body_part_examined, laterality, view_position, source_ae_title, num_instances)
SELECT s.study_pk, s.study_instance_uid || '.' || v.num, v.num, v.modality, v.descr, v.body, v.lat, v.view, v.ae, v.n
FROM (VALUES
  ('R2610030000451',1,'DX','PA',                    'CHEST',  NULL,'PA', 'SEGH_DX01',1),
  ('R2610030000451',2,'DX','LATERAL',               'CHEST',  NULL,'LL', 'SEGH_DX01',1),
  ('R2610040000012',1,'CT','Topogram 0.6 T20f',     'CHEST',  NULL,NULL, 'SEGH_CT01',1),
  ('R2610040000012',2,'CT','Bolus tracking',        'CHEST',  NULL,NULL, 'SEGH_CT01',12),
  ('R2610040000012',3,'CT','CTA PE 1.0 Bv36',       'CHEST',  NULL,NULL, 'SEGH_CT01',412),
  ('R2610040000012',4,'CT','Lung 2.0 Br60',         'CHEST',  NULL,NULL, 'SEGH_CT01',206),
  ('R2610040000012',5,'CT','MIP COR 10mm',          'CHEST',  NULL,NULL, 'SEGH_CT01',48),
  ('R2610050000207',1,'US','OB Anatomy',            'PELVIS', NULL,NULL, 'SEGH_US01',64),
  ('R2610070000318',1,'CT','Topogram 0.6 T20s',     'HEAD',   NULL,NULL, 'SEGH_CT01',1),
  ('R2610070000318',2,'CT','Head 5.0 Hr38 Brain',   'HEAD',   NULL,NULL, 'SEGH_CT01',32),
  ('R2610070000318',3,'CT','Head 1.0 Hr68 Bone',    'HEAD',   NULL,NULL, 'SEGH_CT01',160),
  ('R2610070000318',4,'CT','COR Brain 3mm',         'HEAD',   NULL,NULL, 'SEGH_CT01',54),
  ('R2610080000402',1,'MR','3-Plane Loc',           'KNEE',   'R', NULL, 'SEGH_MR01',9),
  ('R2610080000402',2,'MR','Sag PD FS',             'KNEE',   'R', NULL, 'SEGH_MR01',28),
  ('R2610080000402',3,'MR','Sag PD',                'KNEE',   'R', NULL, 'SEGH_MR01',28),
  ('R2610080000402',4,'MR','Cor PD FS',             'KNEE',   'R', NULL, 'SEGH_MR01',26),
  ('R2610080000402',5,'MR','Cor T1',                'KNEE',   'R', NULL, 'SEGH_MR01',26),
  ('R2610080000402',6,'MR','Ax PD FS',              'KNEE',   'R', NULL, 'SEGH_MR01',30),
  ('R2610120000033',1,'DX','AP PORTABLE',           'CHEST',  NULL,'AP', 'SEGH_DX02',1),
  ('R2610140000154',1,'MG','R CC',                  'BREAST', 'R', 'CC', 'SEGH_MG01',1),
  ('R2610140000154',2,'MG','L CC',                  'BREAST', 'L', 'CC', 'SEGH_MG01',1),
  ('R2610140000154',3,'MG','R MLO',                 'BREAST', 'R', 'MLO','SEGH_MG01',1),
  ('R2610140000154',4,'MG','L MLO',                 'BREAST', 'L', 'MLO','SEGH_MG01',1),
  ('R2610160000266',1,'US','Abdomen RUQ',           'ABDOMEN',NULL,NULL, 'SEGH_US01',38),
  ('R2611030000589',1,'DX','PA',                    'CHEST',  NULL,'PA', 'SEGH_DX01',1),
  ('R2611030000589',2,'DX','LATERAL',               'CHEST',  NULL,'LL', 'SEGH_DX01',1)
) v(acc, num, modality, descr, body, lat, view, ae, n)
JOIN pacs.study s ON s.accession_no = v.acc;

INSERT INTO pacs.instance (series_pk, sop_instance_uid, sop_class_uid, instance_number, rows, columns, file_path, transfer_syntax_uid)
SELECT se.series_pk,
       se.series_instance_uid || '.' || g.n,
       CASE se.modality_code
         WHEN 'DX' THEN '1.2.840.10008.5.1.4.1.1.1.1'     -- Digital X-Ray Image Storage - For Presentation
         WHEN 'CT' THEN '1.2.840.10008.5.1.4.1.1.2'       -- CT Image Storage
         WHEN 'MR' THEN '1.2.840.10008.5.1.4.1.1.4'       -- MR Image Storage
         WHEN 'US' THEN '1.2.840.10008.5.1.4.1.1.6.1'     -- Ultrasound Image Storage
         WHEN 'MG' THEN '1.2.840.10008.5.1.4.1.1.1.2'     -- Digital Mammography X-Ray Image Storage - For Presentation
       END,
       g.n,
       CASE se.modality_code WHEN 'CT' THEN 512 WHEN 'MR' THEN 384 WHEN 'US' THEN 768 WHEN 'MG' THEN 3328 ELSE 3072 END,
       CASE se.modality_code WHEN 'CT' THEN 512 WHEN 'MR' THEN 384 WHEN 'US' THEN 1024 WHEN 'MG' THEN 2560 ELSE 2500 END,
       '/archive/' || st.study_date || '/' || st.accession_no || '/' || se.series_number || '/' || lpad(g.n::text, 5, '0') || '.dcm',
       CASE WHEN se.modality_code IN ('US') THEN '1.2.840.10008.1.2.4.50' ELSE '1.2.840.10008.1.2.4.90' END
FROM pacs.series se
JOIN pacs.study st USING (study_pk)
CROSS JOIN LATERAL generate_series(1, se.num_instances) g(n);

UPDATE pacs.study st SET
  num_series    = x.ns,
  num_instances = x.ni,
  storage_size_mb = round(x.mb, 1)
FROM (
  SELECT se.study_pk, count(DISTINCT se.series_pk) ns, sum(se.num_instances) ni,
         sum(se.num_instances * CASE se.modality_code WHEN 'CT' THEN 0.26 WHEN 'MR' THEN 0.15 WHEN 'US' THEN 0.4 WHEN 'MG' THEN 18 ELSE 9.5 END) mb
  FROM pacs.series se GROUP BY se.study_pk
) x
WHERE x.study_pk = st.study_pk;

-- =============================================================================
-- Interface engine log (sample raw HL7 v2 traffic)
-- =============================================================================

INSERT INTO integration.hl7_message (direction, source_system, dest_system, message_type, control_id, received_dt, ack_code, raw_message) VALUES
 ('IN','EPIC','LIS','ORM^O01','MSG2610120330001','2026-10-12 03:30:12','AA',
  E'MSH|^~\\&|EPIC|SEGH|LIS|SEGH|20261012033012||ORM^O01|MSG2610120330001|P|2.5.1\r'
  'PID|1||MRN00067890^^^SEGH^MR||OKAFOR^DAVID^CHUKWUDI||19631202|M|||76 SANGAMON AVE^^SPRINGFIELD^IL^62702||^PRN^PH^^^217^5556610\r'
  'PV1|1|E|ED^07^^SEGH||||00002^NOVAK^PETER^^^^MD|||||||||||V2610120006\r'
  'ORC|NW|EHR-7788120|||||^^^20261012033000^^S\r'
  'OBR|1|EHR-7788120||LACT^Lactic acid^L|S|20261012033000\r'
  'OBR|2|EHR-7788120||BCX^Blood culture^L|S|20261012033000'),
 ('OUT','LIS','EPIC','ORU^R01','LIS2610120408771','2026-10-12 04:08:44','AA',
  E'MSH|^~\\&|LIS|SEGH|EPIC|SEGH|20261012040844||ORU^R01|LIS2610120408771|P|2.5.1\r'
  'PID|1||MRN00067890^^^SEGH^MR||OKAFOR^DAVID^CHUKWUDI||19631202|M\r'
  'ORC|RE|EHR-7788120|L26101200006\r'
  'OBR|1|EHR-7788120|L26101200006|LACT^Lactic acid^L|||20261012034100|||||||20261012035200||00002^NOVAK^PETER||||||20261012040800|||F\r'
  'OBX|1|NM|2524-7^Lactate [Moles/volume] in Serum or Plasma^LN^LACT^Lactic acid^L||4.8|mmol/L|0.5-2.2|HH|||F|||20261012040800'),
 ('OUT','LIS','EPIC','ORU^R01','LIS2610120412002','2026-10-12 04:12:02','AA',
  E'MSH|^~\\&|LIS|SEGH|EPIC|SEGH|20261012041202||ORU^R01|LIS2610120412002|P|2.5.1\r'
  'PID|1||MRN00067890^^^SEGH^MR||OKAFOR^DAVID^CHUKWUDI||19631202|M\r'
  'OBR|1|EHR-7788120|L26101200006|BMP^Basic metabolic panel^L|||20261012034100||||||||||||||||F\r'
  'OBX|1|NM|2823-3^Potassium^LN^K^Potassium^L||6.4|mmol/L|3.5-5.1|HH|||F'),
 ('OUT','LIS','EPIC','ORU^R01','LIS2610120512310','2026-10-12 05:12:31','AA',
  E'MSH|^~\\&|LIS|SEGH|EPIC|SEGH|20261012051231||ORU^R01|LIS2610120512310|P|2.5.1\r'
  'PID|1||MRN00067890^^^SEGH^MR||OKAFOR^DAVID^CHUKWUDI||19631202|M\r'
  'OBR|1|EHR-7788120|L26101200006|BMP^Basic metabolic panel^L|||20261012043500||||||||||||||||C\r'
  'OBX|1|NM|2823-3^Potassium^LN^K^Potassium^L||5.4|mmol/L|3.5-5.1|H|||C\r'
  'NTE|1||CORRECTED RESULT. Previously reported 6.4 mmol/L on hemolyzed specimen.'),
 ('IN','EPIC','RIS','ORM^O01','MSG2610080140022','2026-10-08 14:00:31','AA',
  E'MSH|^~\\&|EPIC|SEGH|RIS|SEGH|20261008140031||ORM^O01|MSG2610080140022|P|2.3\r'
  'PID|1||MRN00056789^^^SEGH^MR||JOHNSON^EMILY^ROSE||19950617|F\r'
  'PV1|1|O|ORTH^EX2^^SEGH||||00005^KIM^DANIEL^^^^MD|||||||||||V2610080005\r'
  'ORC|NW|EHR-7785520\r'
  'OBR|1|EHR-7785520||MRKNWO^MRI KNEE WITHOUT CONTRAST^L|U|20261008140000|||||||||||||||||MR||||||||||^Twisting injury R knee, positive Lachman'),
 ('OUT','RIS','EPIC','ORU^R01','RIS2610081741005','2026-10-08 17:41:22','AA',
  E'MSH|^~\\&|RIS|SEGH|EPIC|SEGH|20261008174122||ORU^R01|RIS2610081741005|P|2.3\r'
  'PID|1||MRN00056789^^^SEGH^MR||JOHNSON^EMILY^ROSE||19950617|F\r'
  'OBR|1|EHR-7785520|R2610080000402|MRKNWO^MRI KNEE WITHOUT CONTRAST^L|||20261008151200|||||||||||||||20261008174100||MR|F\r'
  'OBX|1|TX|IMP^Impression^L||1. Complete ACL tear with pivot-shift bone contusion pattern.~2. Small vertical tear of the posterior horn of the lateral meniscus.~3. Grade 1 MCL sprain.||||||F'),
 ('IN','EPIC','LIS','ADT^A08','MSG2610220801113','2026-10-22 08:01:13','AE',
  E'MSH|^~\\&|EPIC|SEGH|LIS|SEGH|20261022080113||ADT^A08|MSG2610220801113|P|2.5.1\r'
  'EVN|A08|20261022080100\r'
  'PID|1||MRN00101234^^^SEGH^MR||HASSAN^AHMED||1977070|M');   -- malformed DOB -> rejected (AE)

-- =============================================================================
-- Documentation
-- =============================================================================
COMMENT ON SCHEMA adt         IS 'HIS/ADT system: master patient index, encounters, staff, locations, coverage';
COMMENT ON SCHEMA lis         IS 'Laboratory Information System';
COMMENT ON SCHEMA ris         IS 'Radiology Information System';
COMMENT ON SCHEMA pacs        IS 'PACS DICOM index (separate vendor; linked to RIS only by accession number and MRN)';
COMMENT ON SCHEMA integration IS 'Interface engine message log (HL7 v2)';
COMMENT ON COLUMN adt.patient.merged_into_patient_id IS 'Set when this record is a duplicate merged by HIM; the surviving record id';
COMMENT ON COLUMN adt.encounter_diagnosis.icd10_code IS 'ICD-10-CM; some legacy feeds store codes without the dot';
COMMENT ON COLUMN lis.result.value_text IS 'Raw value as reported; value_num is populated only when value_text is numeric';
COMMENT ON COLUMN lis.test_catalog.loinc_code IS 'LOINC mapping maintained by lab IT; NULL = not mapped';

ANALYZE;
