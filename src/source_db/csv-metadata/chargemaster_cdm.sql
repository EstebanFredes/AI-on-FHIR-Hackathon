-- generated from chargemaster_cdm.csv (27 rows) by scripts/extract_csv_metadata.py
-- types are inferred from the data; review before use
CREATE SCHEMA IF NOT EXISTS vocab;
CREATE TABLE vocab.chargemaster_cdm (
  cdm_number                   varchar(9) NOT NULL,  -- code, source column "CDM_NUMBER"
  charge_description           varchar(31) NOT NULL,  -- string, source column "CHARGE_DESCRIPTION"
  dept                         varchar(3) NOT NULL,  -- string, source column "DEPT"
  rev_code                     varchar(4) NOT NULL,  -- code, ub04_revenue, source column "REV_CODE"
  cpt_hcpcs                    varchar(5),  -- string, cpt_hcpcs, source column "CPT_HCPCS"
  gross_charge                 numeric(8,2) NOT NULL,  -- decimal, source column "GROSS_CHARGE"
  effective_date               date NOT NULL,  -- date, YYYY-MM-DD, source column "EFFECTIVE_DATE"
  status                       varchar(1) NOT NULL,  -- string, source column "STATUS"
  PRIMARY KEY (cdm_number)
);
-- \copy vocab.chargemaster_cdm FROM 'vocab/chargemaster_cdm.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',')
