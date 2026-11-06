-- =============================================================================
-- provider — terminology / dictionaries / code tables, per source system
--
-- Each system keeps its own vocabulary, the way vendors usually ship them:
--   adt          generic CODE_SET / CODE_VALUE master + outbound aliases (Cerner-style),
--                plus an allergen picklist
--   lis          generic DICTIONARY + DICTIONARY_MAP, organism master, canned result choices
--   ris          CODE_TABLE (flat), BI-RADS, cancel reasons
--   pacs         DICOM UID registry, body part defined terms
--   integration  interface-engine translation tables (source value -> target value)
--
-- Codes are a mix of
--   * local / made-up codes (no meaning outside this hospital), and
--   * real standard codes (HL7 v2 tables, FHIR/HL7 code systems, CDC race & ethnicity,
--     NUBC/UB-04, SNOMED CT, LOINC, RxNorm, DICOM UIDs). The SNOMED CT, LOINC and RxNorm
--     codes were checked against a terminology server (SNOMED CT International 2026-10-01,
--     LOINC 2.82, RxNorm 2026-05-04).
-- Some real mappings are left NULL on purpose (unmapped yet), as in real life.
-- More code lists live outside the db, as spreadsheets in ./vocab/*.csv
-- =============================================================================

SET client_min_messages = warning;
\o /dev/null

-- =============================================================================
-- ADT: CODE_SET / CODE_VALUE / CODE_VALUE_ALIAS
-- =============================================================================

CREATE TABLE adt.code_set (
  code_set_id     int PRIMARY KEY,               -- numeric ids, like vendor code sets
  name            varchar(30) NOT NULL UNIQUE,
  description     varchar(200),
  owner           varchar(30),                   -- team maintaining it
  hl7_table       varchar(10)                    -- related HL7 v2 table, if any
);

CREATE TABLE adt.code_value (
  code_value_id   serial PRIMARY KEY,
  code_set_id     int NOT NULL REFERENCES adt.code_set,
  code            varchar(20) NOT NULL,          -- value stored in transactional tables
  display         varchar(100) NOT NULL,
  description     varchar(250),
  sort_order      smallint,
  active          boolean NOT NULL DEFAULT true,
  effective_from  date DEFAULT '2008-01-01',
  effective_to    date,
  UNIQUE (code_set_id, code)
);

CREATE TABLE adt.code_value_alias (
  alias_id        serial PRIMARY KEY,
  code_value_id   int NOT NULL REFERENCES adt.code_value,
  direction       varchar(3) NOT NULL DEFAULT 'OUT',   -- IN (inbound alias) | OUT (outbound)
  contributor     varchar(20) NOT NULL,                -- who uses the alias: HL7V2, FHIR, CDCREC, NUBC, BCP47, X12, STATE_RPT
  alias_system    varchar(120),                        -- code system URI when known
  alias_code      varchar(40) NOT NULL,
  alias_display   varchar(120)
);

INSERT INTO adt.code_set (code_set_id, name, description, owner, hl7_table) VALUES
 (57,    'SEX',            'Administrative sex',                         'Registration', '0001'),
 (38,    'MARITAL_STATUS', 'Marital status',                             'Registration', '0002'),
 (282,   'RACE',           'Race (registration picklist)',               'Registration', '0005'),
 (27,    'ETHNICITY',      'Ethnic group',                               'Registration', '0189'),
 (36,    'LANGUAGE',       'Primary language',                           'Registration', '0296'),
 (71,    'PATIENT_CLASS',  'Encounter patient class',                    'ADT team',     '0004'),
 (3,     'ADMIT_TYPE',     'Admission type / priority',                  'ADT team',     '0007'),
 (19,    'DISCH_DISP',     'Discharge disposition (UB-04 FL17)',         'HIM',          '0112'),
 (261,   'ENC_STATUS',     'Encounter status',                           'ADT team',     NULL),
 (17,    'DX_TYPE',        'Diagnosis type',                             'HIM',          '0052'),
 (40,    'RELATIONSHIP',   'Contact relationship to patient',            'Registration', '0063'),
 (351,   'CONTACT_ROLE',   'Contact role',                               'Registration', '0131'),
 (4,     'ID_TYPE',        'Patient identifier type',                    'MPI team',     '0203'),
 (12025, 'ALLERGEN_TYPE',  'Allergen type',                              'Nursing',      '0127'),
 (12022, 'ALLERGY_SEV',    'Allergy severity',                           'Nursing',      '0128'),
 (12030, 'ALLERGY_STATUS', 'Allergy record status',                      'Nursing',      NULL),
 (222,   'LOCATION_TYPE',  'Location type',                              'Facilities',   '0305'),
 (88,    'PRACT_ROLE',     'Staff role',                                 'HR / Credentialing', NULL),
 (354,   'FIN_CLASS',      'Payer type / financial class',               'Patient Accounting', '0064'),
 (4001,  'ADT_EVENT',      'ADT event (trigger) type',                   'Interfaces',   '0003'),
 (14000, 'VIP_FLAG',       'Confidentiality / VIP indicator (local)',    'Privacy Office', NULL),
 (14001, 'ARRIVAL_MODE',   'ED mode of arrival (local)',                 'ED',           NULL);

-- helper to keep the inserts readable
CREATE FUNCTION pg_temp.cv(p_set text, p_code text, p_display text, p_sort int, p_desc text DEFAULT NULL, p_active boolean DEFAULT true)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO adt.code_value (code_set_id, code, display, description, sort_order, active)
  SELECT code_set_id, p_code, p_display, p_desc, p_sort, p_active FROM adt.code_set WHERE name = p_set;
$$;
CREATE FUNCTION pg_temp.al(p_set text, p_code text, p_contrib text, p_system text, p_alias text, p_alias_display text, p_dir text DEFAULT 'OUT')
RETURNS void LANGUAGE sql AS $$
  INSERT INTO adt.code_value_alias (code_value_id, direction, contributor, alias_system, alias_code, alias_display)
  SELECT v.code_value_id, p_dir, p_contrib, p_system, p_alias, p_alias_display
  FROM adt.code_value v JOIN adt.code_set s USING (code_set_id)
  WHERE s.name = p_set AND v.code = p_code;
$$;

-- SEX
SELECT pg_temp.cv('SEX','M','Male',1), pg_temp.cv('SEX','F','Female',2), pg_temp.cv('SEX','U','Unknown',3),
       pg_temp.cv('SEX','X','Non-binary / Other',4,'Added 2022 per state reporting requirement');
SELECT pg_temp.al('SEX','M','FHIR','http://hl7.org/fhir/administrative-gender','male','Male'),
       pg_temp.al('SEX','F','FHIR','http://hl7.org/fhir/administrative-gender','female','Female'),
       pg_temp.al('SEX','U','FHIR','http://hl7.org/fhir/administrative-gender','unknown','Unknown'),
       pg_temp.al('SEX','X','FHIR','http://hl7.org/fhir/administrative-gender','other','Other'),
       pg_temp.al('SEX','M','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0001','M','Male'),
       pg_temp.al('SEX','F','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0001','F','Female'),
       pg_temp.al('SEX','U','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0001','U','Unknown'),
       pg_temp.al('SEX','X','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0001','O','Other');

-- MARITAL_STATUS
SELECT pg_temp.cv('MARITAL_STATUS','S','Single',1), pg_temp.cv('MARITAL_STATUS','M','Married',2),
       pg_temp.cv('MARITAL_STATUS','D','Divorced',3), pg_temp.cv('MARITAL_STATUS','W','Widowed',4),
       pg_temp.cv('MARITAL_STATUS','P','Domestic partner',5), pg_temp.cv('MARITAL_STATUS','U','Unknown',6),
       pg_temp.cv('MARITAL_STATUS','Z','Legally separated (old)',7,'Retired 2015, use D', false);
SELECT pg_temp.al('MARITAL_STATUS','S','FHIR','http://terminology.hl7.org/CodeSystem/v3-MaritalStatus','S','Never Married'),
       pg_temp.al('MARITAL_STATUS','M','FHIR','http://terminology.hl7.org/CodeSystem/v3-MaritalStatus','M','Married'),
       pg_temp.al('MARITAL_STATUS','D','FHIR','http://terminology.hl7.org/CodeSystem/v3-MaritalStatus','D','Divorced'),
       pg_temp.al('MARITAL_STATUS','W','FHIR','http://terminology.hl7.org/CodeSystem/v3-MaritalStatus','W','Widowed'),
       pg_temp.al('MARITAL_STATUS','P','FHIR','http://terminology.hl7.org/CodeSystem/v3-MaritalStatus','T','Domestic partner'),
       pg_temp.al('MARITAL_STATUS','U','FHIR','http://terminology.hl7.org/CodeSystem/v3-NullFlavor','UNK','Unknown'),
       pg_temp.al('MARITAL_STATUS','Z','FHIR','http://terminology.hl7.org/CodeSystem/v3-MaritalStatus','L','Legally Separated');

-- RACE: transactional table stores the DISPLAY text (legacy), codes here are local
SELECT pg_temp.cv('RACE','R01','White',1), pg_temp.cv('RACE','R02','Black or African American',2),
       pg_temp.cv('RACE','R03','Asian',3), pg_temp.cv('RACE','R04','American Indian or Alaska Native',4),
       pg_temp.cv('RACE','R05','Native Hawaiian or Other Pacific Islander',5), pg_temp.cv('RACE','R06','Other',6),
       pg_temp.cv('RACE','R98','Patient declined',7), pg_temp.cv('RACE','R99','Unknown',8);
SELECT pg_temp.al('RACE','R01','CDCREC','urn:oid:2.16.840.1.113883.6.238','2106-3','White'),
       pg_temp.al('RACE','R02','CDCREC','urn:oid:2.16.840.1.113883.6.238','2054-5','Black or African American'),
       pg_temp.al('RACE','R03','CDCREC','urn:oid:2.16.840.1.113883.6.238','2028-9','Asian'),
       pg_temp.al('RACE','R04','CDCREC','urn:oid:2.16.840.1.113883.6.238','1002-5','American Indian or Alaska Native'),
       pg_temp.al('RACE','R05','CDCREC','urn:oid:2.16.840.1.113883.6.238','2076-8','Native Hawaiian or Other Pacific Islander'),
       pg_temp.al('RACE','R06','CDCREC','urn:oid:2.16.840.1.113883.6.238','2131-1','Other Race'),
       pg_temp.al('RACE','R98','FHIR','http://terminology.hl7.org/CodeSystem/v3-NullFlavor','ASKU','Asked but no answer'),
       pg_temp.al('RACE','R99','FHIR','http://terminology.hl7.org/CodeSystem/v3-NullFlavor','UNK','Unknown'),
       pg_temp.al('RACE','R01','INBOUND','text','White','White','IN'),
       pg_temp.al('RACE','R02','INBOUND','text','Black or African American','Black or African American','IN'),
       pg_temp.al('RACE','R03','INBOUND','text','Asian','Asian','IN');

-- ETHNICITY
SELECT pg_temp.cv('ETHNICITY','E1','Hispanic or Latino',1), pg_temp.cv('ETHNICITY','E2','Not Hispanic or Latino',2),
       pg_temp.cv('ETHNICITY','E8','Declined',3), pg_temp.cv('ETHNICITY','E9','Unknown',4);
SELECT pg_temp.al('ETHNICITY','E1','CDCREC','urn:oid:2.16.840.1.113883.6.238','2135-2','Hispanic or Latino'),
       pg_temp.al('ETHNICITY','E2','CDCREC','urn:oid:2.16.840.1.113883.6.238','2186-5','Not Hispanic or Latino'),
       pg_temp.al('ETHNICITY','E8','FHIR','http://terminology.hl7.org/CodeSystem/v3-NullFlavor','ASKU','Asked but no answer'),
       pg_temp.al('ETHNICITY','E9','FHIR','http://terminology.hl7.org/CodeSystem/v3-NullFlavor','UNK','Unknown');

-- LANGUAGE: patient table holds a mix of full names and legacy 3-letter codes
SELECT pg_temp.cv('LANGUAGE','English','English',1), pg_temp.cv('LANGUAGE','Spanish','Spanish',2),
       pg_temp.cv('LANGUAGE','Chinese','Chinese (Mandarin)',3), pg_temp.cv('LANGUAGE','Arabic','Arabic',4),
       pg_temp.cv('LANGUAGE','Korean','Korean',5), pg_temp.cv('LANGUAGE','Polish','Polish',6),
       pg_temp.cv('LANGUAGE','ASL','American Sign Language',7),
       pg_temp.cv('LANGUAGE','ENG','English (legacy code)',90,'Pre-2016 registration system code', false),
       pg_temp.cv('LANGUAGE','SPA','Spanish (legacy code)',91,'Pre-2016 registration system code', false);
SELECT pg_temp.al('LANGUAGE','English','BCP47','urn:ietf:bcp:47','en','English'),
       pg_temp.al('LANGUAGE','ENG',    'BCP47','urn:ietf:bcp:47','en','English'),
       pg_temp.al('LANGUAGE','Spanish','BCP47','urn:ietf:bcp:47','es','Spanish'),
       pg_temp.al('LANGUAGE','SPA',    'BCP47','urn:ietf:bcp:47','es','Spanish'),
       pg_temp.al('LANGUAGE','Chinese','BCP47','urn:ietf:bcp:47','zh','Chinese'),
       pg_temp.al('LANGUAGE','Arabic', 'BCP47','urn:ietf:bcp:47','ar','Arabic'),
       pg_temp.al('LANGUAGE','Korean', 'BCP47','urn:ietf:bcp:47','ko','Korean'),
       pg_temp.al('LANGUAGE','Polish', 'BCP47','urn:ietf:bcp:47','pl','Polish'),
       pg_temp.al('LANGUAGE','ASL',    'BCP47','urn:ietf:bcp:47','ase','American Sign Language');

-- PATIENT_CLASS
SELECT pg_temp.cv('PATIENT_CLASS','E','Emergency',1), pg_temp.cv('PATIENT_CLASS','I','Inpatient',2),
       pg_temp.cv('PATIENT_CLASS','O','Outpatient',3), pg_temp.cv('PATIENT_CLASS','P','Preadmit',4),
       pg_temp.cv('PATIENT_CLASS','B','Observation (bed)',5,'Local: observation status patients'),
       pg_temp.cv('PATIENT_CLASS','R','Recurring (series)',6);
SELECT pg_temp.al('PATIENT_CLASS','E','FHIR','http://terminology.hl7.org/CodeSystem/v3-ActCode','EMER','emergency'),
       pg_temp.al('PATIENT_CLASS','I','FHIR','http://terminology.hl7.org/CodeSystem/v3-ActCode','IMP','inpatient encounter'),
       pg_temp.al('PATIENT_CLASS','O','FHIR','http://terminology.hl7.org/CodeSystem/v3-ActCode','AMB','ambulatory'),
       pg_temp.al('PATIENT_CLASS','P','FHIR','http://terminology.hl7.org/CodeSystem/v3-ActCode','PRENC','pre-admission'),
       pg_temp.al('PATIENT_CLASS','B','FHIR','http://terminology.hl7.org/CodeSystem/v3-ActCode','OBSENC','observation encounter'),
       pg_temp.al('PATIENT_CLASS','E','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0004','E','Emergency'),
       pg_temp.al('PATIENT_CLASS','I','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0004','I','Inpatient'),
       pg_temp.al('PATIENT_CLASS','O','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0004','O','Outpatient'),
       pg_temp.al('PATIENT_CLASS','P','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0004','P','Preadmit'),
       pg_temp.al('PATIENT_CLASS','B','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0004','O','Outpatient'),
       pg_temp.al('PATIENT_CLASS','R','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0004','R','Recurring patient');

-- ADMIT_TYPE (NUBC UB-04 FL14 priority of admission)
SELECT pg_temp.cv('ADMIT_TYPE','EMERGENCY','Emergency',1), pg_temp.cv('ADMIT_TYPE','URGENT','Urgent',2),
       pg_temp.cv('ADMIT_TYPE','ELECTIVE','Elective',3), pg_temp.cv('ADMIT_TYPE','NEWBORN','Newborn',4),
       pg_temp.cv('ADMIT_TYPE','TRAUMA','Trauma',5), pg_temp.cv('ADMIT_TYPE','ROUTINE','Routine (outpatient)',6,'Local: not billed on UB-04');
SELECT pg_temp.al('ADMIT_TYPE','EMERGENCY','NUBC',NULL,'1','Emergency'),
       pg_temp.al('ADMIT_TYPE','URGENT',   'NUBC',NULL,'2','Urgent'),
       pg_temp.al('ADMIT_TYPE','ELECTIVE', 'NUBC',NULL,'3','Elective'),
       pg_temp.al('ADMIT_TYPE','NEWBORN',  'NUBC',NULL,'4','Newborn'),
       pg_temp.al('ADMIT_TYPE','TRAUMA',   'NUBC',NULL,'5','Trauma');

-- DISCH_DISP (NUBC patient discharge status)
SELECT pg_temp.cv('DISCH_DISP','01','Discharged to home or self care',1),
       pg_temp.cv('DISCH_DISP','02','Discharged/transferred to a short-term general hospital',2),
       pg_temp.cv('DISCH_DISP','03','Discharged/transferred to skilled nursing facility (SNF)',3),
       pg_temp.cv('DISCH_DISP','06','Discharged/transferred to home under care of home health',4),
       pg_temp.cv('DISCH_DISP','07','Left against medical advice',5),
       pg_temp.cv('DISCH_DISP','20','Expired',6),
       pg_temp.cv('DISCH_DISP','50','Discharged to hospice - home',7),
       pg_temp.cv('DISCH_DISP','LWBS','Left without being seen',8,'Local ED code, billed as 07', true);
SELECT pg_temp.al('DISCH_DISP',c,'FHIR','http://terminology.hl7.org/CodeSystem/discharge-disposition',f,d)
FROM (VALUES ('01','home','Home'),('02','hosp','Hospital'),('03','snf','Skilled nursing facility'),
             ('06','home','Home'),('07','aadvice','Left against advice'),('20','exp','Expired'),('LWBS','aadvice','Left against advice')) v(c,f,d);

-- ENC_STATUS
SELECT pg_temp.cv('ENC_STATUS','PREADMIT','Pre-admitted',1), pg_temp.cv('ENC_STATUS','ARRIVED','Arrived',2),
       pg_temp.cv('ENC_STATUS','ADMITTED','Admitted / in progress',3), pg_temp.cv('ENC_STATUS','DISCHARGED','Discharged',4),
       pg_temp.cv('ENC_STATUS','CANCELLED','Cancelled',5), pg_temp.cv('ENC_STATUS','NOSHOW','No show',6);
SELECT pg_temp.al('ENC_STATUS',c,'FHIR','http://hl7.org/fhir/encounter-status',f,f)
FROM (VALUES ('PREADMIT','planned'),('ARRIVED','arrived'),('ADMITTED','in-progress'),('DISCHARGED','finished'),('CANCELLED','cancelled'),('NOSHOW','cancelled')) v(c,f);

-- DX_TYPE
SELECT pg_temp.cv('DX_TYPE','A','Admitting',1), pg_temp.cv('DX_TYPE','W','Working',2), pg_temp.cv('DX_TYPE','F','Final',3);
SELECT pg_temp.al('DX_TYPE','A','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0052','A','Admitting'),
       pg_temp.al('DX_TYPE','W','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0052','W','Working'),
       pg_temp.al('DX_TYPE','F','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0052','F','Final'),
       pg_temp.al('DX_TYPE','A','FHIR','http://terminology.hl7.org/CodeSystem/diagnosis-role','AD','Admission diagnosis'),
       pg_temp.al('DX_TYPE','F','FHIR','http://terminology.hl7.org/CodeSystem/diagnosis-role','DD','Discharge diagnosis');

-- RELATIONSHIP
SELECT pg_temp.cv('RELATIONSHIP','SPOUSE','Spouse',1), pg_temp.cv('RELATIONSHIP','MOTHER','Mother',2),
       pg_temp.cv('RELATIONSHIP','FATHER','Father',3), pg_temp.cv('RELATIONSHIP','CHILD','Child',4),
       pg_temp.cv('RELATIONSHIP','SIBLING','Sibling',5), pg_temp.cv('RELATIONSHIP','FRIEND','Friend',6),
       pg_temp.cv('RELATIONSHIP','OTHER','Other',7);
SELECT pg_temp.al('RELATIONSHIP',c,'FHIR','http://terminology.hl7.org/CodeSystem/v3-RoleCode',f,d)
FROM (VALUES ('SPOUSE','SPS','spouse'),('MOTHER','MTH','mother'),('FATHER','FTH','father'),('CHILD','CHILD','child'),
             ('SIBLING','SIB','sibling'),('FRIEND','FRND','unrelated friend')) v(c,f,d);

-- CONTACT_ROLE
SELECT pg_temp.cv('CONTACT_ROLE','EMC','Emergency contact',1), pg_temp.cv('CONTACT_ROLE','NOK','Next of kin',2),
       pg_temp.cv('CONTACT_ROLE','GRD','Legal guardian',3), pg_temp.cv('CONTACT_ROLE','POA','Health care power of attorney',4);
SELECT pg_temp.al('CONTACT_ROLE','EMC','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0131','C','Emergency Contact'),
       pg_temp.al('CONTACT_ROLE','NOK','HL7V2','http://terminology.hl7.org/CodeSystem/v2-0131','N','Next-of-Kin'),
       pg_temp.al('CONTACT_ROLE','GRD','FHIR', 'http://terminology.hl7.org/CodeSystem/v3-RoleCode','GUARD','guardian'),
       pg_temp.al('CONTACT_ROLE','POA','FHIR', 'http://terminology.hl7.org/CodeSystem/v3-RoleCode','POWATT','power of attorney');

-- ID_TYPE
SELECT pg_temp.cv('ID_TYPE','MR','Medical record number',1), pg_temp.cv('ID_TYPE','SS','Social Security number',2),
       pg_temp.cv('ID_TYPE','DL','Driver''s license',3), pg_temp.cv('ID_TYPE','MB','Insurance member id',4),
       pg_temp.cv('ID_TYPE','PI','Patient portal id',5,'Local meaning differs from HL7 PI (patient internal identifier)');
SELECT pg_temp.al('ID_TYPE',c,'HL7V2','http://terminology.hl7.org/CodeSystem/v2-0203',c,d)
FROM (VALUES ('MR','Medical record number'),('SS','Social Security number'),('DL','Driver''s license number'),
             ('MB','Member Number'),('PI','Patient internal identifier')) v(c,d);

-- ALLERGY
SELECT pg_temp.cv('ALLERGEN_TYPE','DA','Drug',1), pg_temp.cv('ALLERGEN_TYPE','FA','Food',2),
       pg_temp.cv('ALLERGEN_TYPE','EA','Environmental',3), pg_temp.cv('ALLERGEN_TYPE','MC','Miscellaneous contraindication',4);
SELECT pg_temp.al('ALLERGEN_TYPE',c,'HL7V2','http://terminology.hl7.org/CodeSystem/v2-0127',c,d)
FROM (VALUES ('DA','Drug allergy'),('FA','Food allergy'),('EA','Environmental allergy'),('MC','Miscellaneous contraindication')) v(c,d);
SELECT pg_temp.al('ALLERGEN_TYPE','DA','FHIR','http://hl7.org/fhir/allergy-intolerance-category','medication','Medication'),
       pg_temp.al('ALLERGEN_TYPE','FA','FHIR','http://hl7.org/fhir/allergy-intolerance-category','food','Food'),
       pg_temp.al('ALLERGEN_TYPE','EA','FHIR','http://hl7.org/fhir/allergy-intolerance-category','environment','Environment');
SELECT pg_temp.cv('ALLERGY_SEV','MI','Mild',1), pg_temp.cv('ALLERGY_SEV','MO','Moderate',2), pg_temp.cv('ALLERGY_SEV','SV','Severe',3);
SELECT pg_temp.al('ALLERGY_SEV',c,'FHIR','http://hl7.org/fhir/reaction-event-severity',f,f)
FROM (VALUES ('MI','mild'),('MO','moderate'),('SV','severe')) v(c,f);
SELECT pg_temp.cv('ALLERGY_STATUS','ACTIVE','Active',1), pg_temp.cv('ALLERGY_STATUS','INACTIVE','Inactive',2),
       pg_temp.cv('ALLERGY_STATUS','RESOLVED','Resolved',3), pg_temp.cv('ALLERGY_STATUS','ERROR','Entered in error',4);
SELECT pg_temp.al('ALLERGY_STATUS',c,'FHIR','http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical',f,f)
FROM (VALUES ('ACTIVE','active'),('INACTIVE','inactive'),('RESOLVED','resolved')) v(c,f);

-- LOCATION_TYPE, PRACT_ROLE (local only, no standard alias)
SELECT pg_temp.cv('LOCATION_TYPE','WARD','Nursing unit',1), pg_temp.cv('LOCATION_TYPE','ROOM','Room',2),
       pg_temp.cv('LOCATION_TYPE','BED','Bed',3), pg_temp.cv('LOCATION_TYPE','EXAM','Exam room',4),
       pg_temp.cv('LOCATION_TYPE','BAY','ED bay / curtain',5);
SELECT pg_temp.cv('PRACT_ROLE','PHYSICIAN','Physician',1), pg_temp.cv('PRACT_ROLE','NURSE','Registered nurse',2),
       pg_temp.cv('PRACT_ROLE','TECHNOLOGIST','Technologist',3), pg_temp.cv('PRACT_ROLE','PATHOLOGIST','Pathologist',4),
       pg_temp.cv('PRACT_ROLE','APP','Advanced practice provider (NP/PA)',5), pg_temp.cv('PRACT_ROLE','RESIDENT','Resident physician',6);

-- FIN_CLASS (with X12 claim filing indicator alias)
SELECT pg_temp.cv('FIN_CLASS','MEDICARE','Medicare',1), pg_temp.cv('FIN_CLASS','MEDICAID','Medicaid',2),
       pg_temp.cv('FIN_CLASS','COMMERCIAL','Commercial',3), pg_temp.cv('FIN_CLASS','SELF','Self pay',4),
       pg_temp.cv('FIN_CLASS','WORKCOMP','Workers compensation',5), pg_temp.cv('FIN_CLASS','CHARITY','Charity care (local)',6);
SELECT pg_temp.al('FIN_CLASS',c,'X12',NULL,f,d)
FROM (VALUES ('MEDICARE','MB','Medicare Part B'),('MEDICAID','MC','Medicaid'),('COMMERCIAL','CI','Commercial Insurance Co.'),
             ('SELF','09','Self-pay'),('WORKCOMP','WC','Workers'' Compensation Health Claim')) v(c,f,d);

-- ADT_EVENT
SELECT pg_temp.cv('ADT_EVENT',c,d,n)
FROM (VALUES ('A01','Admit/visit notification',1),('A02','Transfer a patient',2),('A03','Discharge/end visit',3),
             ('A04','Register a patient',4),('A08','Update patient information',5),('A11','Cancel admit',6),
             ('A40','Merge patient - patient identifier list',7)) v(c,d,n);

-- local-only code sets (no external meaning)
SELECT pg_temp.cv('VIP_FLAG','0','None',1), pg_temp.cv('VIP_FLAG','1','Employee',2), pg_temp.cv('VIP_FLAG','2','Board member / donor',3),
       pg_temp.cv('VIP_FLAG','3','Public figure',4), pg_temp.cv('VIP_FLAG','9','Break-the-glass restricted',5);
SELECT pg_temp.cv('ARRIVAL_MODE','AMB','Ambulance (ALS/BLS)',1), pg_temp.cv('ARRIVAL_MODE','WALK','Walk-in / private vehicle',2),
       pg_temp.cv('ARRIVAL_MODE','HELI','Air transport',3), pg_temp.cv('ARRIVAL_MODE','POL','Police custody',4),
       pg_temp.cv('ARRIVAL_MODE','XFER','Transfer from outside facility',5);

-- -----------------------------------------------------------------------------
-- Allergen picklist (nursing). allergy.allergen_text is free text and only
-- partially matches this list.
-- -----------------------------------------------------------------------------
CREATE TABLE adt.allergen_dictionary (
  allergen_code   varchar(10) PRIMARY KEY,       -- local
  display         varchar(100) NOT NULL,
  allergen_type   varchar(2) NOT NULL,           -- code set ALLERGEN_TYPE
  synonyms        varchar(200),                  -- pipe separated, used by the free-text matcher
  rxnorm_code     varchar(15),
  snomed_code     varchar(20),
  mapping_note    varchar(200),
  active          boolean NOT NULL DEFAULT true
);

INSERT INTO adt.allergen_dictionary VALUES
 ('ALG00012','Penicillins',               'DA','Penicillin|PCN|penicillin G|Pen VK', '7980', NULL,       'RxNorm mapped to penicillin G (IN); class-level allergy, mapping approximate', true),
 ('ALG00031','Sulfonamide antibiotics',   'DA','SULFA DRUGS|Sulfa|Bactrim',          NULL,   '387406002','Mapped to SNOMED substance Sulfonamide', true),
 ('ALG00047','Codeine',                   'DA','Codeine|Tylenol #3',                 '2670', NULL,       NULL, true),
 ('ALG00055','Iodinated contrast media',  'DA','Iodinated contrast|IV contrast|CT dye', NULL, '426722004',NULL, true),
 ('ALG00102','Peanut',                    'FA','Peanuts|peanut butter',              NULL,   '762952008',NULL, true),
 ('ALG00118','Shellfish',                 'FA','shrimp|crab|lobster',                NULL,   NULL,       'Not mapped yet', true),
 ('ALG00201','Natural rubber latex',      'EA','Latex',                              NULL,   '1003754000',NULL, true),
 ('ALG00215','Bee venom',                 'EA','bee sting|wasp',                     NULL,   NULL,       'Not mapped yet', true),
 ('ALG00230','Adhesive tape',             'EA','tape|tegaderm',                      NULL,   NULL,       'Local only', true),
 ('ALG09990','No known drug allergies',   'DA','NKDA|NKA',                           NULL,   NULL,       'Not a substance; should become a negation statement', true),
 ('ALG09991','Unable to assess',          'MC','UTA',                                NULL,   NULL,       'Local workflow code', true),
 ('ALG00013','Ampicillin (old)',          'DA','Ampicillin',                         NULL,   NULL,       'Retired 2019, merged into ALG00012', false);

-- =============================================================================
-- LIS: DICTIONARY / DICTIONARY_MAP, organism master, canned result choices
-- =============================================================================

CREATE TABLE lis.dictionary (
  dict_name       varchar(20) NOT NULL,
  code            varchar(10) NOT NULL,
  display         varchar(100) NOT NULL,
  description     varchar(250),
  sort_order      smallint,
  active          char(1) NOT NULL DEFAULT 'Y',  -- Y/N, as in many LIS products
  PRIMARY KEY (dict_name, code)
);

CREATE TABLE lis.dictionary_map (
  dict_name       varchar(20) NOT NULL,
  code            varchar(10) NOT NULL,
  target_system   varchar(120) NOT NULL,
  target_code     varchar(40) NOT NULL,
  target_display  varchar(120),
  FOREIGN KEY (dict_name, code) REFERENCES lis.dictionary
);

INSERT INTO lis.dictionary (dict_name, code, display, description, sort_order) VALUES
 -- abnormal flags (HL7 v2 0078)
 ('ABN_FLAG','N','Normal',NULL,1), ('ABN_FLAG','L','Low',NULL,2), ('ABN_FLAG','H','High',NULL,3),
 ('ABN_FLAG','LL','Critical low',NULL,4), ('ABN_FLAG','HH','Critical high',NULL,5), ('ABN_FLAG','A','Abnormal',NULL,6),
 ('ABN_FLAG','AA','Critical abnormal',NULL,7), ('ABN_FLAG','<','Below absolute low (off scale)',NULL,8),
 ('ABN_FLAG','>','Above absolute high (off scale)',NULL,9),
 -- result status
 ('RES_STATUS','P','Preliminary',NULL,1), ('RES_STATUS','F','Final',NULL,2), ('RES_STATUS','C','Corrected',NULL,3),
 ('RES_STATUS','X','Cancelled - cannot be done',NULL,4), ('RES_STATUS','I','Pending - specimen in lab',NULL,5),
 -- order / order item status
 ('ORD_STATUS','SC','Scheduled',NULL,1), ('ORD_STATUS','IP','In process',NULL,2), ('ORD_STATUS','CM','Complete',NULL,3),
 ('ORD_STATUS','CA','Cancelled',NULL,4), ('ORD_STATUS','HD','On hold',NULL,5),
 -- priority
 ('PRIORITY','S','STAT','Result within 60 min of receipt',1), ('PRIORITY','A','ASAP','Within 4 h',2),
 ('PRIORITY','R','Routine','Same day',3), ('PRIORITY','T','Timed','Collect at specified time',4),
 -- specimen condition (local)
 ('SPEC_COND','OK','Acceptable',NULL,1), ('SPEC_COND','HEMOLYZED','Hemolyzed',NULL,2), ('SPEC_COND','LIPEMIC','Lipemic',NULL,3),
 ('SPEC_COND','ICTERIC','Icteric',NULL,4), ('SPEC_COND','CLOTTED','Clotted',NULL,5), ('SPEC_COND','QNS','Quantity not sufficient',NULL,6),
 -- specimen rejection reasons (local, made-up)
 ('REJECT','RJ01','Specimen unlabeled',NULL,1), ('REJECT','RJ02','Label/requisition mismatch',NULL,2),
 ('REJECT','RJ03','Grossly hemolyzed',NULL,3), ('REJECT','RJ04','Clotted (EDTA/citrate)',NULL,4),
 ('REJECT','RJ05','Quantity not sufficient',NULL,5), ('REJECT','RJ06','Received outside stability window',NULL,6),
 ('REJECT','RJ07','Wrong container',NULL,7), ('REJECT','RJ08','Leaking container',NULL,8),
 -- susceptibility interpretation / method
 ('AST_INTERP','S','Susceptible',NULL,1), ('AST_INTERP','I','Intermediate',NULL,2), ('AST_INTERP','R','Resistant',NULL,3),
 ('AST_INTERP','SDD','Susceptible-dose dependent',NULL,4), ('AST_INTERP','NI','No interpretation',NULL,5),
 ('AST_METHOD','MIC','Minimum inhibitory concentration',NULL,1), ('AST_METHOD','KB','Disk diffusion (Kirby-Bauer)',NULL,2),
 ('AST_METHOD','ETEST','Gradient diffusion',NULL,3),
 -- result comments (canned, local made-up)
 ('CANNED_CMT','#HEM','Specimen hemolyzed, interpret with caution',NULL,1),
 ('CANNED_CMT','#LIP','Specimen lipemic',NULL,2),
 ('CANNED_CMT','#RCL','Recollection requested',NULL,3),
 ('CANNED_CMT','#CRIT','Critical value called and read back',NULL,4),
 ('CANNED_CMT','#DELTA','Delta check failure verified',NULL,5),
 ('CANNED_CMT','#FRIED','Calculated (Friedewald)',NULL,6),
 ('CANNED_CMT','#SO','Performed at reference laboratory',NULL,7);

INSERT INTO lis.dictionary_map (dict_name, code, target_system, target_code, target_display) VALUES
 ('ABN_FLAG','N', 'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','N','Normal'),
 ('ABN_FLAG','L', 'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','L','Low'),
 ('ABN_FLAG','H', 'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','H','High'),
 ('ABN_FLAG','LL','http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','LL','Critical low'),
 ('ABN_FLAG','HH','http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','HH','Critical high'),
 ('ABN_FLAG','A', 'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','A','Abnormal'),
 ('ABN_FLAG','AA','http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','AA','Critical abnormal'),
 ('ABN_FLAG','<', 'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','<','Off scale low'),
 ('ABN_FLAG','>', 'http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','>','Off scale high'),
 ('RES_STATUS','P','http://hl7.org/fhir/observation-status','preliminary','Preliminary'),
 ('RES_STATUS','F','http://hl7.org/fhir/observation-status','final','Final'),
 ('RES_STATUS','C','http://hl7.org/fhir/observation-status','corrected','Corrected'),
 ('RES_STATUS','X','http://hl7.org/fhir/observation-status','cancelled','Cancelled'),
 ('RES_STATUS','I','http://hl7.org/fhir/observation-status','registered','Registered'),
 ('RES_STATUS','P','http://terminology.hl7.org/CodeSystem/v2-0085','P','Preliminary results'),
 ('RES_STATUS','F','http://terminology.hl7.org/CodeSystem/v2-0085','F','Final results'),
 ('RES_STATUS','C','http://terminology.hl7.org/CodeSystem/v2-0085','C','Record coming over is a correction'),
 ('ORD_STATUS','SC','http://hl7.org/fhir/request-status','active','Active'),
 ('ORD_STATUS','IP','http://hl7.org/fhir/request-status','active','Active'),
 ('ORD_STATUS','CM','http://hl7.org/fhir/request-status','completed','Completed'),
 ('ORD_STATUS','CA','http://hl7.org/fhir/request-status','revoked','Revoked'),
 ('ORD_STATUS','HD','http://hl7.org/fhir/request-status','on-hold','On Hold'),
 ('PRIORITY','S','http://hl7.org/fhir/request-priority','stat','STAT'),
 ('PRIORITY','A','http://hl7.org/fhir/request-priority','asap','ASAP'),
 ('PRIORITY','R','http://hl7.org/fhir/request-priority','routine','Routine'),
 ('AST_INTERP','S','http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','S','Susceptible'),
 ('AST_INTERP','I','http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','I','Intermediate'),
 ('AST_INTERP','R','http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','R','Resistant'),
 ('AST_INTERP','SDD','http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','SDD','Susceptible-dose dependent'),
 ('AST_INTERP','NI','http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation','NS','Non-susceptible'),
 ('SPEC_COND','HEMOLYZED','http://terminology.hl7.org/CodeSystem/v2-0493','HEM','Hemolyzed'),
 ('SPEC_COND','CLOTTED','http://terminology.hl7.org/CodeSystem/v2-0493','CLOT','Clotted');
 -- LIPEMIC / ICTERIC / QNS: no v2-0493 equivalent, left unmapped

-- organism master (micro). Local codes are made-up; SNOMED codes are real.
CREATE TABLE lis.organism (
  organism_code   varchar(10) PRIMARY KEY,       -- local
  organism_name   varchar(120) NOT NULL,
  gram_reaction   varchar(10),                   -- POS | NEG | N/A
  organism_group  varchar(30),
  snomed_code     varchar(20),
  alert_flag      boolean NOT NULL DEFAULT false, -- infection-control alert organism
  active          boolean NOT NULL DEFAULT true
);

INSERT INTO lis.organism VALUES
 ('ECOL',  'Escherichia coli',                         'NEG','Enterobacterales',  '112283007', false, true),
 ('KPNE',  'Klebsiella pneumoniae',                    'NEG','Enterobacterales',  '56415008',  false, true),
 ('PAER',  'Pseudomonas aeruginosa',                   'NEG','Non-fermenter',     '52499004',  false, true),
 ('SAUR',  'Staphylococcus aureus',                    'POS','Staphylococcus',    '3092008',   false, true),
 ('MRSA',  'Staphylococcus aureus, methicillin resistant','POS','Staphylococcus', '115329001', true,  true),
 ('EFAE',  'Enterococcus faecalis',                    'POS','Enterococcus',      '78065002',  false, true),
 ('SPYO',  'Streptococcus pyogenes (Group A)',         'POS','Streptococcus',     '80166006',  false, true),
 ('CALB',  'Candida albicans',                         'N/A','Yeast',             '53326005',  false, true),
 ('GNR',   'Gram negative rods, not further identified','NEG','Preliminary',      NULL,        false, true),
 ('GPCCL', 'Gram positive cocci in clusters',          'POS','Preliminary',       NULL,        false, true),
 ('MIXFL', 'Mixed flora, 3 or more organisms',         NULL, 'Descriptor',        NULL,        false, true),
 ('NOGRO', 'No growth at 5 days',                      NULL, 'Descriptor',        NULL,        false, true),
 ('CONTAM','Probable contaminant, no ID performed',    NULL, 'Descriptor',        NULL,        false, true),
 ('ESBLEC','E. coli ESBL (old code)',                  'NEG','Enterobacterales',  NULL,        true,  false);

-- canned coded results allowed per test (picklists the tech chooses from)
CREATE TABLE lis.result_choice (
  test_code       varchar(15) NOT NULL REFERENCES lis.test_catalog (test_code),
  choice_code     varchar(10) NOT NULL,          -- local keyboard shortcut code
  display         varchar(60) NOT NULL,
  abnormal_flag   varchar(2),
  snomed_code     varchar(20),
  sort_order      smallint,
  PRIMARY KEY (test_code, choice_code)
);

INSERT INTO lis.result_choice VALUES
 ('STREPA','POS','Positive','A','10828004',1), ('STREPA','NEG','Negative','N','260385009',2), ('STREPA','INV','Invalid, repeat',NULL,NULL,3),
 ('UPRO','NEG','Negative','N','260385009',1), ('UPRO','TR','Trace','A','260405006',2), ('UPRO','1+','1+ (30 mg/dL)','A',NULL,3),
 ('UPRO','2+','2+ (100 mg/dL)','A',NULL,4), ('UPRO','3+','3+ (300 mg/dL)','A',NULL,5),
 ('UGLU','NEG','Negative','N','260385009',1), ('UGLU','TR','Trace','A','260405006',2), ('UGLU','1+','1+','A',NULL,3), ('UGLU','2+','2+','A',NULL,4),
 ('ULEU','NEG','Negative','N','260385009',1), ('ULEU','TR','Trace','A','260405006',2), ('ULEU','SM','Small','A',NULL,3),
 ('ULEU','MOD','Moderate','A',NULL,4), ('ULEU','LG','Large','A',NULL,5),
 ('UNIT','NEG','Negative','N','260385009',1), ('UNIT','POS','Positive','A','10828004',2),
 ('UCOL','YEL','Yellow','N',NULL,1), ('UCOL','STR','Straw','N',NULL,2), ('UCOL','AMB','Amber','A',NULL,3),
 ('UCOL','RED','Red','A',NULL,4), ('UCOL','BRN','Brown','A',NULL,5),
 ('BCX','NG5','No growth at 5 days','N',NULL,1), ('BCX','NG2','No growth at 2 days, final to follow',NULL,NULL,2),
 ('BCX','ORG','Organism isolated, see ID','A',NULL,3);

-- =============================================================================
-- RIS: flat CODE_TABLE, BI-RADS, cancel reasons
-- =============================================================================

CREATE TABLE ris.code_table (
  table_name      varchar(20) NOT NULL,
  code            varchar(15) NOT NULL,
  display         varchar(120) NOT NULL,
  ext_code        varchar(40),                   -- one external code column, the vendor's only mapping slot
  ext_system      varchar(120),
  active          boolean NOT NULL DEFAULT true,
  PRIMARY KEY (table_name, code)
);

INSERT INTO ris.code_table (table_name, code, display, ext_code, ext_system) VALUES
 ('RPT_STATUS','P','Preliminary',     'preliminary','http://hl7.org/fhir/diagnostic-report-status'),
 ('RPT_STATUS','F','Final',           'final',      'http://hl7.org/fhir/diagnostic-report-status'),
 ('RPT_STATUS','A','Addendum',        'appended',   'http://hl7.org/fhir/diagnostic-report-status'),
 ('RPT_STATUS','C','Corrected',       'corrected',  'http://hl7.org/fhir/diagnostic-report-status'),
 ('RPT_STATUS','D','Dictated, not transcribed', NULL, NULL),
 ('PRIORITY','STAT','STAT',           'stat',   'http://hl7.org/fhir/request-priority'),
 ('PRIORITY','URG','Urgent',          'urgent', 'http://hl7.org/fhir/request-priority'),
 ('PRIORITY','ROUT','Routine',        'routine','http://hl7.org/fhir/request-priority'),
 ('PRIORITY','PREOP','Pre-op (local)', NULL,    NULL),
 ('ORD_STATUS','ORDERED','Ordered',          'active',   'http://hl7.org/fhir/request-status'),
 ('ORD_STATUS','SCHEDULED','Scheduled',      'active',   'http://hl7.org/fhir/request-status'),
 ('ORD_STATUS','IN_PROGRESS','In progress',  'active',   'http://hl7.org/fhir/request-status'),
 ('ORD_STATUS','COMPLETED','Completed',      'completed','http://hl7.org/fhir/request-status'),
 ('ORD_STATUS','CANCELLED','Cancelled',      'revoked',  'http://hl7.org/fhir/request-status'),
 ('LATERALITY','L','Left',      '7771000',  'http://snomed.info/sct'),
 ('LATERALITY','R','Right',     '24028007', 'http://snomed.info/sct'),
 ('LATERALITY','B','Bilateral', '51440002', 'http://snomed.info/sct'),
 ('CONTRAST','NONE','Without contrast', NULL, NULL),
 ('CONTRAST','IV','IV contrast',        NULL, NULL),
 ('CONTRAST','ORAL','Oral contrast',    NULL, NULL),
 ('CONTRAST','IVOR','IV and oral contrast', NULL, NULL),
 ('CANCEL_RSN','CR01','Ordered in error',                  NULL, NULL),
 ('CANCEL_RSN','CR02','Duplicate order',                   NULL, NULL),
 ('CANCEL_RSN','CR03','Contrast contraindicated (renal)',  NULL, NULL),
 ('CANCEL_RSN','CR04','Patient refused',                   NULL, NULL),
 ('CANCEL_RSN','CR05','Patient discharged before exam',    NULL, NULL),
 ('CANCEL_RSN','CR06','Changed to different procedure',    NULL, NULL),
 ('CANCEL_RSN','CR07','Insurance authorization denied',    NULL, NULL);

CREATE TABLE ris.birads (
  category        varchar(2) PRIMARY KEY,
  display         varchar(80) NOT NULL,
  management      varchar(150)
);
INSERT INTO ris.birads VALUES
 ('0','Incomplete - need additional imaging evaluation','Recall for additional imaging and/or prior comparison'),
 ('1','Negative','Routine screening'),
 ('2','Benign','Routine screening'),
 ('3','Probably benign','Short-interval (6-month) follow-up'),
 ('4','Suspicious','Tissue diagnosis'),
 ('4A','Low suspicion for malignancy','Tissue diagnosis'),
 ('4B','Moderate suspicion for malignancy','Tissue diagnosis'),
 ('4C','High suspicion for malignancy','Tissue diagnosis'),
 ('5','Highly suggestive of malignancy','Tissue diagnosis'),
 ('6','Known biopsy-proven malignancy','Surgical excision when clinically appropriate');

-- record the cancel reason on the cancelled CT (it existed as free text only)
ALTER TABLE ris.imaging_order ADD COLUMN cancel_reason_code varchar(10);
UPDATE ris.imaging_order SET cancel_reason_code = 'CR03' WHERE status = 'CANCELLED';

-- =============================================================================
-- PACS: DICOM UID registry, body part defined terms
-- =============================================================================

CREATE TABLE pacs.uid_registry (
  uid             varchar(64) PRIMARY KEY,
  name            varchar(120) NOT NULL,
  uid_type        varchar(20) NOT NULL,          -- SOP_CLASS | TRANSFER_SYNTAX
  retired         boolean NOT NULL DEFAULT false
);
INSERT INTO pacs.uid_registry VALUES
 ('1.2.840.10008.5.1.4.1.1.1',     'Computed Radiography Image Storage',                         'SOP_CLASS', false),
 ('1.2.840.10008.5.1.4.1.1.1.1',   'Digital X-Ray Image Storage - For Presentation',             'SOP_CLASS', false),
 ('1.2.840.10008.5.1.4.1.1.1.2',   'Digital Mammography X-Ray Image Storage - For Presentation', 'SOP_CLASS', false),
 ('1.2.840.10008.5.1.4.1.1.2',     'CT Image Storage',                                           'SOP_CLASS', false),
 ('1.2.840.10008.5.1.4.1.1.4',     'MR Image Storage',                                           'SOP_CLASS', false),
 ('1.2.840.10008.5.1.4.1.1.6.1',   'Ultrasound Image Storage',                                   'SOP_CLASS', false),
 ('1.2.840.10008.5.1.4.1.1.7',     'Secondary Capture Image Storage',                            'SOP_CLASS', false),
 ('1.2.840.10008.5.1.4.1.1.88.67', 'X-Ray Radiation Dose SR Storage',                            'SOP_CLASS', false),
 ('1.2.840.10008.5.1.4.1.1.13.1.3','Breast Tomosynthesis Image Storage',                         'SOP_CLASS', false),
 ('1.2.840.10008.1.2',             'Implicit VR Little Endian',                                  'TRANSFER_SYNTAX', false),
 ('1.2.840.10008.1.2.1',           'Explicit VR Little Endian',                                  'TRANSFER_SYNTAX', false),
 ('1.2.840.10008.1.2.2',           'Explicit VR Big Endian',                                     'TRANSFER_SYNTAX', true),
 ('1.2.840.10008.1.2.4.50',        'JPEG Baseline (Process 1)',                                  'TRANSFER_SYNTAX', false),
 ('1.2.840.10008.1.2.4.70',        'JPEG Lossless, Non-Hierarchical, First-Order Prediction',    'TRANSFER_SYNTAX', false),
 ('1.2.840.10008.1.2.4.90',        'JPEG 2000 Image Compression (Lossless Only)',                'TRANSFER_SYNTAX', false);

CREATE TABLE pacs.body_part (
  body_part       varchar(16) PRIMARY KEY,       -- DICOM (0018,0015) defined term
  display         varchar(60) NOT NULL,
  snomed_code     varchar(20)                    -- NULL = not mapped in this PACS
);
INSERT INTO pacs.body_part VALUES
 ('HEAD',    'Head',              '69536005'),
 ('CHEST',   'Chest',             '51185008'),
 ('BREAST',  'Breast',            '76752008'),
 ('KNEE',    'Knee',              '72696002'),
 ('ABDOMEN', 'Abdomen',           NULL),
 ('PELVIS',  'Pelvis',            NULL),
 ('CSPINE',  'Cervical spine',    NULL),
 ('EXTREMITY','Extremity (generic)', NULL),
 ('WHOLEBODY','Whole body',       NULL);

-- =============================================================================
-- Interface engine translation tables
-- =============================================================================

CREATE TABLE integration.lookup_table (
  table_name      varchar(40) NOT NULL,
  source_value    varchar(60) NOT NULL,
  target_value    varchar(60),
  description     varchar(200),
  last_modified   date,
  modified_by     varchar(20),
  PRIMARY KEY (table_name, source_value)
);

INSERT INTO integration.lookup_table VALUES
 -- EHR order priority -> LIS priority
 ('EPIC_LAB_PRIORITY','S','S','STAT','2019-03-01','jdoe'),
 ('EPIC_LAB_PRIORITY','A','A','ASAP','2019-03-01','jdoe'),
 ('EPIC_LAB_PRIORITY','R','R','Routine','2019-03-01','jdoe'),
 ('EPIC_LAB_PRIORITY','T','R','Timed -> routine (LIS cannot do timed)','2021-06-14','mrivera'),
 ('EPIC_LAB_PRIORITY','P','R','Pre-op -> routine','2021-06-14','mrivera'),
 -- EHR orderable -> LIS test code (most are identical, some are not)
 ('EPIC_TO_LIS_TEST','LAB100','CBC','CBC with auto diff','2019-03-01','jdoe'),
 ('EPIC_TO_LIS_TEST','LAB110','BMP','Basic metabolic panel','2019-03-01','jdoe'),
 ('EPIC_TO_LIS_TEST','LAB115','HEPF','Hepatic function panel','2019-03-01','jdoe'),
 ('EPIC_TO_LIS_TEST','LAB120','LIPID','Lipid panel','2019-03-01','jdoe'),
 ('EPIC_TO_LIS_TEST','LAB205','HBA1C','Hemoglobin A1c','2019-03-01','jdoe'),
 ('EPIC_TO_LIS_TEST','LAB230','TSH','TSH','2019-03-01','jdoe'),
 ('EPIC_TO_LIS_TEST','LAB310','TROPHS','hs-Troponin I (replaced LAB300 cTnI in 2023)','2023-02-01','mrivera'),
 ('EPIC_TO_LIS_TEST','LAB300',NULL,'Retired conventional troponin, no target','2023-02-01','mrivera'),
 ('EPIC_TO_LIS_TEST','LAB410','LACT','Lactic acid','2019-03-01','jdoe'),
 ('EPIC_TO_LIS_TEST','LAB501','UA','UA dipstick','2019-03-01','jdoe'),
 ('EPIC_TO_LIS_TEST','LAB701','BCX','Blood culture x2 sets','2019-03-01','jdoe'),
 ('EPIC_TO_LIS_TEST','LAB720','STREPA','Rapid strep A','2020-11-02','jdoe'),
 -- outbound flag translation for the state reporting feed
 ('LIS_FLAG_TO_STATE','N','N',NULL,'2020-01-10','jdoe'),
 ('LIS_FLAG_TO_STATE','H','A','State feed only knows N/A','2020-01-10','jdoe'),
 ('LIS_FLAG_TO_STATE','L','A','State feed only knows N/A','2020-01-10','jdoe'),
 ('LIS_FLAG_TO_STATE','HH','A',NULL,'2020-01-10','jdoe'),
 ('LIS_FLAG_TO_STATE','LL','A',NULL,'2020-01-10','jdoe'),
 ('LIS_FLAG_TO_STATE','A','A',NULL,'2020-01-10','jdoe'),
 -- department -> HL7 sending facility / PV1-3 point of care
 ('DEPT_TO_POC','ED','ED',NULL,'2018-05-20','jdoe'),
 ('DEPT_TO_POC','ICU','MICU',NULL,'2018-05-20','jdoe'),
 ('DEPT_TO_POC','MED4','4W',NULL,'2018-05-20','jdoe'),
 ('DEPT_TO_POC','FAMMED','FMC',NULL,'2018-05-20','jdoe'),
 ('DEPT_TO_POC','OBGYN','WHC',NULL,'2018-05-20','jdoe'),
 ('DEPT_TO_POC','ORTHO','ORTH',NULL,'2018-05-20','jdoe'),
 ('DEPT_TO_POC','PEDS','PEDS',NULL,'2018-05-20','jdoe'),
 -- RIS modality -> PACS routing AE
 ('MODALITY_TO_AE','CT','SEGH_CT01',NULL,'2022-08-01','kpatel'),
 ('MODALITY_TO_AE','MR','SEGH_MR01',NULL,'2022-08-01','kpatel'),
 ('MODALITY_TO_AE','US','SEGH_US01',NULL,'2022-08-01','kpatel'),
 ('MODALITY_TO_AE','MG','SEGH_MG01',NULL,'2022-08-01','kpatel'),
 ('MODALITY_TO_AE','DX','SEGH_DX01','Portables route to DX02 by room rule','2022-08-01','kpatel'),
 -- inbound sex normalization from outside feeds
 ('INBOUND_SEX','M','M',NULL,'2018-05-20','jdoe'),
 ('INBOUND_SEX','MALE','M',NULL,'2018-05-20','jdoe'),
 ('INBOUND_SEX','F','F',NULL,'2018-05-20','jdoe'),
 ('INBOUND_SEX','FEMALE','F',NULL,'2018-05-20','jdoe'),
 ('INBOUND_SEX','O','X','Added 2022','2022-03-15','mrivera'),
 ('INBOUND_SEX','U','U',NULL,'2018-05-20','jdoe'),
 ('INBOUND_SEX','A','U','Ambiguous -> unknown','2018-05-20','jdoe');

COMMENT ON TABLE adt.code_set            IS 'Generic code set master (HIS). Transactional tables store code_value.code';
COMMENT ON TABLE adt.code_value_alias    IS 'Outbound/inbound aliases of local codes to external code systems';
COMMENT ON TABLE adt.allergen_dictionary IS 'Nursing allergen picklist; adt.allergy.allergen_text is free text and only partially matches it';
COMMENT ON TABLE lis.dictionary          IS 'Generic LIS dictionary (flags, statuses, reject reasons, canned comments)';
COMMENT ON TABLE lis.organism            IS 'Microbiology organism master; local codes, partially mapped to SNOMED CT';
COMMENT ON TABLE ris.code_table          IS 'Flat RIS code table with a single external code slot';
COMMENT ON TABLE integration.lookup_table IS 'Interface engine translation tables';

ANALYZE;
