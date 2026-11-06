-- generated from lab_loinc_mapping_worksheet.csv (21 rows) by scripts/extract_csv_metadata.py
-- types are inferred from the data; review before use
CREATE SCHEMA IF NOT EXISTS vocab;
CREATE TABLE vocab.lab_loinc_mapping_worksheet (
  local_code                   varchar(7) NOT NULL,  -- string, source column "Local Code"
  local_test_name              varchar(28) NOT NULL,  -- string, source column "Local Test Name"
  specimen                     varchar(7) NOT NULL,  -- string, source column "Specimen"
  units                        varchar(13),  -- string, source column "Units"
  loinc                        varchar(7),  -- string, loinc, source column "LOINC"
  loinc_long_name              varchar(78),  -- string, source column "LOINC Long Name"
  map_status                   varchar(12) NOT NULL,  -- string, source column "Map Status"
  mapped_by                    varchar(10),  -- string, person_initials, source column "Mapped By"
  map_date                     date,  -- date, MM/DD/YYYY, source column "Map Date"
  notes                        varchar(68),  -- string, source column "Notes"
  PRIMARY KEY (local_code)
);
-- \copy vocab.lab_loinc_mapping_worksheet FROM 'vocab/lab_loinc_mapping_worksheet.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')
