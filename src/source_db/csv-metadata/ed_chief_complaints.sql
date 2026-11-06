-- generated from ed_chief_complaints.csv (16 rows) by scripts/extract_csv_metadata.py
-- types are inferred from the data; review before use
CREATE SCHEMA IF NOT EXISTS vocab;
CREATE TABLE vocab.ed_chief_complaints (
  cc_code                      varchar(5) NOT NULL,  -- string, source column "CC_CODE"
  complaint                    varchar(28) NOT NULL,  -- string, source column "COMPLAINT"
  body_system                  varchar(15) NOT NULL,  -- string, source column "BODY_SYSTEM"
  default_esi                  integer NOT NULL,  -- integer, source column "DEFAULT_ESI"
  triage_protocol              varchar(44),  -- string, source column "TRIAGE_PROTOCOL"
  sepsis_screen                boolean NOT NULL,  -- boolean, source column "SEPSIS_SCREEN"
  stroke_alert                 boolean NOT NULL,  -- boolean, source column "STROKE_ALERT"
  PRIMARY KEY (cc_code)
);
-- \copy vocab.ed_chief_complaints FROM 'vocab/ed_chief_complaints.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')
