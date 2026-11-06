-- generated from department_cost_centers.csv (11 rows) by scripts/extract_csv_metadata.py
-- types are inferred from the data; review before use
CREATE SCHEMA IF NOT EXISTS vocab;
CREATE TABLE vocab.department_cost_centers (
  dept_code                    varchar(7) NOT NULL,  -- string
  department_name              varchar(29) NOT NULL,  -- string
  cost_center                  varchar(7) NOT NULL,  -- string, cost_center
  gl_unit                      varchar(6) NOT NULL,  -- string
  service_line                 varchar(18) NOT NULL,  -- string
  director                     varchar(10),  -- string, person_initials
  active                       boolean NOT NULL,  -- boolean
  PRIMARY KEY (dept_code)
);
-- \copy vocab.department_cost_centers FROM 'vocab/department_cost_centers.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';')
