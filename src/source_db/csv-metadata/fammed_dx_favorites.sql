-- generated from fammed_dx_favorites.csv (27 rows) by scripts/extract_csv_metadata.py
-- types are inferred from the data; review before use
CREATE SCHEMA IF NOT EXISTS vocab;
CREATE TABLE vocab.fammed_dx_favorites (
  pick_no                      varchar(5) NOT NULL,  -- string, source column "Pick#"
  clinician_term               varchar(35) NOT NULL,  -- string, source column "Clinician Term"
  icd10                        varchar(7),  -- string, icd10cm, source column "ICD10"
  category                     varchar(9) NOT NULL,  -- string, source column "Category"
  added_by                     varchar(8) NOT NULL,  -- string, person_initials, source column "Added By"
  last_reviewed                varchar(7) NOT NULL,  -- year_month, YYYY-MM, source column "Last Reviewed"
  comment                      varchar(66),  -- string, source column "Comment"
  PRIMARY KEY (pick_no)
);
-- \copy vocab.fammed_dx_favorites FROM 'vocab/fammed_dx_favorites.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')
