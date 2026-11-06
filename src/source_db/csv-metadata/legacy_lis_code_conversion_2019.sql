-- generated from legacy_lis_code_conversion_2019.csv (15 rows) by scripts/extract_csv_metadata.py
-- types are inferred from the data; review before use
CREATE SCHEMA IF NOT EXISTS vocab;
CREATE TABLE vocab.legacy_lis_code_conversion_2019 (
  old_lis_code                 varchar(4) NOT NULL,  -- code, source column "OLD_LIS_CODE"
  old_name                     varchar(16) NOT NULL,  -- string, source column "OLD_NAME"
  new_lis_code                 varchar(7),  -- string, source column "NEW_LIS_CODE"
  conversion_rule              varchar(7) NOT NULL,  -- string, source column "CONVERSION_RULE"
  results_migrated             boolean NOT NULL,  -- boolean, source column "RESULTS_MIGRATED"
  notes                        varchar(79),  -- string, source column "NOTES"
  PRIMARY KEY (old_lis_code)
);
-- \copy vocab.legacy_lis_code_conversion_2019 FROM 'vocab/legacy_lis_code_conversion_2019.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')
