-- generated from radiology_procedure_crosswalk.csv (10 rows) by scripts/extract_csv_metadata.py
-- types are inferred from the data; review before use
CREATE SCHEMA IF NOT EXISTS vocab;
CREATE TABLE vocab.radiology_procedure_crosswalk (
  ris_code                     varchar(11) NOT NULL,  -- string, source column "RIS Code"
  procedure_description        varchar(39) NOT NULL,  -- string, source column "Procedure Description"
  modality                     varchar(2) NOT NULL,  -- string, source column "Modality"
  cpt                          varchar(5) NOT NULL,  -- code, cpt_hcpcs, source column "CPT"
  cpt_modifier                 varchar(5),  -- string, source column "CPT Modifier"
  loinc_current                varchar(7),  -- string, loinc, source column "LOINC (current)"
  loinc_proposed               varchar(7),  -- string, loinc, source column "LOINC (proposed)"
  loinc_display                varchar(35),  -- string, source column "LOINC Display"
  cdm_charge_code              varchar(9) NOT NULL,  -- code, source column "CDM Charge Code"
  exam_duration_min            integer NOT NULL,  -- integer, source column "Exam Duration (min)"
  prep_instructions            varchar(60) NOT NULL,  -- string, source column "Prep Instructions"
  owner_comments               varchar(84),  -- string, source column "Owner Comments"
  PRIMARY KEY (ris_code)
);
-- \copy vocab.radiology_procedure_crosswalk FROM 'vocab/radiology_procedure_crosswalk.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')
