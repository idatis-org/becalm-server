DROP SCHEMA IF EXISTS sd CASCADE;
DROP SCHEMA IF EXISTS becalm CASCADE;

DROP VIEW IF EXISTS sd.v_devices;
DROP VIEW IF EXISTS sd.v_patients;
DROP VIEW IF EXISTS sd.v_measures_last_1hour;
DROP TABLE IF EXISTS sd.measures;
DROP TABLE IF EXISTS sd.measure_types;
DROP TABLE IF EXISTS sd.devices_patients
DROP TABLE IF EXISTS sd.devices;
DROP TABLE IF EXISTS becalm.patients;


/* Utilities

SELECT extract(HOUR FROM '2020-03-20T18:15:59'::timestamp); -- 18
SELECT extract(MINUTE FROM '2020-03-20T18:15:59'::timestamp); -- 15
SELECT extract(SECOND FROM '2020-03-20T18:15:59'::timestamp); -- 59

*/

-- ************************
-- Schemas
-- ************************

CREATE SCHEMA IF NOT EXISTS becalm AUTHORIZATION becalm;
  GRANT CREATE ON SCHEMA becalm TO postgres;
  GRANT USAGE ON SCHEMA becalm TO postgres;

CREATE SCHEMA IF NOT EXISTS sd AUTHORIZATION becalm;
  GRANT CREATE ON SCHEMA sd TO postgres;
  GRANT USAGE ON SCHEMA sd TO postgres;

-- ************************
-- Pacientes
-- ************************

CREATE TABLE becalm.patients (
  id_patient int NOT NULL,
  first_name_patient varchar(50) NOT NULL,
  last_name_patient varchar(50) NOT NULL,
  location_hospital varchar(100) NOT NULL, -- candidate to FK
  location_place varchar(100) NOT NULL,
  date_creation timestamp NOT NULL DEFAULT NOW(),
  CONSTRAINT patients_pkey PRIMARY KEY (id_patient)
);

-- ************************
-- Aparatos que meten datos
-- ************************

CREATE TABLE sd.devices (
   id_device smallint NOT NULL,
   name_device text NOT NULL,
   type_device text NOT NULL, -- raspberry_pi
   model_device text NOT NULL, -- 3B+
   version_device text NOT NULL,
   ip_device inet NOT NULL,
   location_hospital varchar(100) NOT NULL, -- candidate to FK
   location_place varchar(100) NOT NULL,
   date_creation timestamp NOT NULL DEFAULT NOW(),
   CONSTRAINT devices_pkey PRIMARY KEY (id_device)
);

-- ******************************
-- Enlace 1 aparato : N pacientes
-- ******************************

CREATE TABLE sd.devices_patients (
  id_patient int NOT NULL,
  id_device smallint NOT NULL,
  CONSTRAINT devices_patients_pkey PRIMARY KEY (id_patient,id_device),
  CONSTRAINT devices_patients_fkey1 FOREIGN KEY (id_patient) REFERENCES becalm.patients(id_patient),
  CONSTRAINT devices_patients_fkey2 FOREIGN KEY (id_device) REFERENCES sd.devices(id_device)
);

-- ***************
-- Tipos de medida
-- ***************

-- tipos de medidas gestionadas por el sistema
CREATE TABLE sd.measure_types (
  measure_type char NOT NULL,
  measure_name text NOT NULL, -- TODO: use text ids to allow multilingual use
  measure_unit varchar(10) NOT NULL,
  measure_alert_min_value real NOT NULL,
  measure_alert_max_value real NOT NULL,
  measure_min_value real NOT NULL,
  measure_max_value real NOT NULL,
  measure_precision smallint NOT NULL,
  CONSTRAINT measure_types_pkey PRIMARY KEY (measure_type)
);

-- esto son datos de configuración: IMPORTANTE comprobar que están bien
INSERT INTO sd.measure_types (
  measure_type,
  measure_name,
  measure_unit,
  measure_alert_min_value,
  measure_alert_max_value,
  measure_min_value,
  measure_max_value,
  measure_precision
)
VALUES
('t', 'Temperatura', '°C', 36, 40, 30, 50, 1),
('p', 'Presión aire máscara', 'Pa', 100700, 101400, 100500, 101500, 1),
('c', 'Concentración CO2 máscara', 'ppm', 110, 190, 100, 200, 0),
('o', 'Sp02 - Saturación de oxígeno en sangre', '?', 110, 185, 100, 200, 0);


-- tabla con datos, particionada por paciente 
CREATE TABLE sd.measures (
  id_patient smallint NOT NULL,
  measure_type char NOT NULL,
  measure_value real NOT NULL, --  CHECK (measure_value > 0) TODO: add control function based on measure
  date_generation timestamp NOT NULL,
  date_insertion timestamp DEFAULT NOW(),
  CONSTRAINT measures_pkey PRIMARY KEY (id_patient, measure_type, date_generation),
  CONSTRAINT measures_id_patient_fkey FOREIGN KEY (id_patient) REFERENCES becalm.patients(id_patient),
  CONSTRAINT measures_measure_type_fkey FOREIGN KEY (measure_type) REFERENCES sd.measure_types(measure_type)
) PARTITION BY LIST (id_patient);

-- indexar tabla
CREATE INDEX idx_date_generation_inverse ON sd.measures (date_generation DESC);
CREATE INDEX idx_measure_type ON sd.measures USING btree (measure_type DESC);

-- create a partition for each device
-- DROP TABLE sd.measures_1;
CREATE TABLE sd.measures_1 PARTITION OF sd.measures FOR VALUES IN (1);
CREATE TABLE sd.measures_2 PARTITION OF sd.measures FOR VALUES IN (2);
CREATE TABLE sd.measures_3 PARTITION OF sd.measures FOR VALUES IN (3);
CREATE TABLE sd.measures_4 PARTITION OF sd.measures FOR VALUES IN (4);
CREATE TABLE sd.measures_5 PARTITION OF sd.measures FOR VALUES IN (5);
CREATE TABLE sd.measures_6 PARTITION OF sd.measures FOR VALUES IN (6);
CREATE TABLE sd.measures_7 PARTITION OF sd.measures FOR VALUES IN (7);
CREATE TABLE sd.measures_8 PARTITION OF sd.measures FOR VALUES IN (8);
CREATE TABLE sd.measures_9 PARTITION OF sd.measures FOR VALUES IN (9);
CREATE TABLE sd.measures_10 PARTITION OF sd.measures FOR VALUES IN (10);


-- *****
-- VIEWS
-- *****

-- list all devices
CREATE VIEW sd.v_devices AS 
SELECT 
  d.id_device,
  d.name_device,
  d.type_device,
  d.model_device,
  d.version_device,
  d.ip_device,
  d.location_hospital,
  d.location_place,
  d.date_creation
FROM sd.devices d
ORDER BY id_device;

-- list all patients
CREATE VIEW sd.v_patients AS 
SELECT
  p.id_patient,
  p.first_name_patient,
  p.last_name_patient,
  p.location_hospital,
  p.location_place,
  p.date_creation
FROM becalm.patients p
ORDER BY id_patient;

-- last measures for each patient over the last 1-hour

-- will check last hour measures
CREATE VIEW sd.v_measures_last_1hour AS 
WITH _m AS (
  SELECT
    m.id_patient,
    m.measure_type,
    m.measure_value,
    m.date_generation,
    row_number() OVER (PARTITION BY m.id_patient, m.measure_type ORDER BY m.date_generation DESC) as row_num
  FROM sd.measures m
  WHERE date_generation > CURRENT_TIMESTAMP - INTERVAL '1 hour'
)
SELECT
  _m.id_patient,
  _m.measure_type,
  _m.measure_value,
  _m.date_generation
FROM _m WHERE row_num = 1;


-- *********
-- FUNCTIONS
-- *********


-- post measures
CREATE OR REPLACE FUNCTION sd.post_measures(_i_id_patient int, _i_data jsonb, OUT _o_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
/*
Inserts patient measures data
The sd.measures will perform checks when entering data using its own triggers
 
Input :

- @param int _i_id_patient the id of the patient from which data has been obtained
- @param jsonb _i_data a JSON array with the data

Returns json :
  HTTP status code (201, 400, 500) and comment (created, bad request, error)

Utilities:
  SELECT * FROM sd.measures ORDER BY id_patient, measure_type, date_generation DESC;
  INSERT INTO sensor_data.measures (id_patient, measure_type, measure_value, date_generation) VALUES (1, 't', 37.5, '2020-04-02T12:15+02'), 
  DELETE FROM sd.measures;
  SELECT json_typeof('[]'); -- array
  SELECT json_object_keys('{"f1":"abc","f2":2}');
  SELECT json_object_keys('{"f1":"abc","f2":2}');
  SELECT * FROM json_populate_recordset(null::sd.measures, '[{"measure_type":"t","measure_value":12.1,"date_generation":"2020-04-03T13:45"}]')
  SELECT jsonb_array_length('[{"id_patient":1,"measure_type":"t"},{"id_patient":2,"measure_type":"o"}]');

Use cases:

-- 201 Created
SELECT sd.post_measures(1, '[{ "measure_type": "c", "measure_value": 120.10, "date_generation":"2020-04-01T15:32"}]');
SELECT sd.post_measures(1, '[
  { "measure_type": "c", "measure_value": 120.1, "date_generation":"2020-04-01T15:29"},
  { "measure_type": "t", "measure_value": 37.7, "date_generation":"2020-04-01T15:30"}
  ]');

-- 400 Bad Request
SELECT sd.post_measures(1, '{}'); -- not an array
SELECT sd.post_measures(1, '[]'); -- empty measures array
SELECT sd.post_measures(-1, '[{ "measure_type": "c", "measure_value": 120.1, "date_generation":"2020-04-01T15:29"}]'); -- patient not found
*/

DECLARE
   MIN_MEASURES int := 1; -- at least one measure must be inserted
   MAX_MEASURES int := 1000; -- limit of the number of measures that can be inserted (security/performance)
   _n_inserted_measures int; -- number of rows inserted - used to check it equals the input
   _n_requested_measures int;
   _status_message text; -- used to provide feedback 
 
  --error management
  _err_schema_name text;
  _err_table_name text;
  _err_constraint_name text;
  _err_sql_state text;
  _err_message_text text;
  _err_hint text;

BEGIN

  -- init variables
  _o_json := jsonb_build_object('code', 500, 'status', 'SQL server error'); 

  -- 1. INITIAL CHECKS
  
  -- check _i_data is a JSON array
  IF jsonb_typeof(_i_data) <> 'array' THEN 
    RAISE EXCEPTION 'Bad request: _i_data must be a JSON array'
      USING ERRCODE = 'IT001', HINT = 'Please check sd.post_measures';
  END IF;

  -- know how many measures we are supposed to insert
  _n_requested_measures := jsonb_array_length(_i_data);
  RAISE NOTICE 'inserting % measures...', _n_requested_measures;

  -- check the number of measures to insert does not exceed the limit
  IF (_n_requested_measures > MAX_MEASURES) OR (_n_requested_measures < MIN_MEASURES) THEN
    RAISE EXCEPTION 'Bad request: the number of measures must be between % and %', MIN_MEASURES, MAX_MEASURES
      USING ERRCODE = 'IT001', HINT = 'Please check sd.post_measures';
  END IF;
  
  -- check that the user exists
  PERFORM * FROM becalm.patients WHERE id_patient = _i_id_patient;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Bad request: patient id % not found', _i_id_patient
      USING ERRCODE = 'IT001', HINT = 'Please check sd.post_measures';
  END IF;

  -- 2. INSERT DATA
  
  INSERT INTO sd.measures 
  (SELECT
    _i_id_patient,
    measure_type,
    ROUND(measure_value::numeric, 6),
    date_generation
  FROM jsonb_populate_recordset(null::sd.measures, _i_data));
  GET DIAGNOSTICS _n_inserted_measures = ROW_COUNT;
  
  -- 3. CHECK AND RETURN
  IF _n_inserted_measures = _n_requested_measures THEN
    _status_message := 'Created ' || _n_inserted_measures::text || ' measures';
    _o_json := jsonb_build_object('code', 201, 'status', _status_message);
  ELSE 
    RAISE EXCEPTION 'Issue when inserting measures. The function tries to insert % rows instead of %', _n_inserted_measures, _n_requested_measures
           USING HINT = 'Please check sd.post_measures';
  END IF;
  
  --exception handling
  EXCEPTION
    WHEN foreign_key_violation THEN --SQL state 23503
    GET STACKED DIAGNOSTICS
      _err_schema_name = SCHEMA_NAME,
      _err_table_name = TABLE_NAME,
      _err_constraint_name = CONSTRAINT_NAME;
      SELECT row_to_json (s) FROM 
      (SELECT 400 as code, 
      'Foreign key violation on implan: ' || _i_name_implan ||
        ', schema: ' || _err_schema_name || 
        ', table: ' || _err_table_name ||
        ', constraint name: ' || _err_constraint_name as status
      ) s INTO _o_json;
    WHEN SQLSTATE 'IT001' THEN
      GET STACKED DIAGNOSTICS
      _err_sql_state = RETURNED_SQLSTATE,
      _err_message_text = MESSAGE_TEXT,
      _err_hint = PG_EXCEPTION_HINT;
      SELECT row_to_json (s) FROM 
      (SELECT 400 as code, 
          'SQL Error Server. SQLSTATE = ' || _err_sql_state ||
          ', Error message = ' || _err_message_text ||
          '. Hint = ' || _err_hint
         as status
      ) s INTO _o_json;
    WHEN OTHERS THEN 
    GET STACKED DIAGNOSTICS
      _err_sql_state = RETURNED_SQLSTATE,
      _err_message_text = MESSAGE_TEXT;
    SELECT row_to_json (s) FROM 
    (SELECT 500 as code, 
        'SQL Error Server. SQLSTATE = ' || _err_sql_state ||
        ', Error message = ' || _err_message_text
       as status
    ) s INTO _o_json;

END;
$function$
;


-- función para sacar datos
CREATE OR REPLACE FUNCTION sd.get_measures_v100(_i_filters jsonb, OUT _o_json jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
/*

GET API endpoint for measures

v100 - initial version

Params:
  @ _i_filters json with [mandatory (*)] key/value filters:
  (*) id_patient
  (*) start_date
  
Returns json:
  code: [200, 400, 500]
  status: text
  data: array with objects data (or empty array)

Utilities:

  SELECT * FROM sd.measures;
  
  EXPLAIN ANALYZE SELECT sd.get_measures_v100('{"id_patient":1,"start_date":"2020-04-01"}'); 
  EXPLAIN ANALYZE SELECT sd.get_measures_v100('{"id_object":10137,"api_key":"toto", "strip_nulls": true}'); -- 12-15ms

Use cases:

  -- 200 OK
  SELECT sd.get_measures_v100('{"id_patient":1,"start_date":"2020-04-01"}');
  SELECT sd.get_measures_v100('{"id_patient":2,"start_date":"2020-01-01"}');
  SELECT sd.get_measures_v100('{"id_patient":1,"start_date":"2020-06-04T12:53:36","end_date":"2020-06-04T12:53:36"}');
  
  -- 404 Not Found
  -- NOT IMPLEMENTED IF PATIENT DOES NOT EXIST
  
  -- 400 Bad Request
  SELECT sd.get_measures_v100('{"id_patient":-1,"start_date":"2020-04-01"}'); -- unknown patient
  SELECT sd.get_measures_v100('{"id_patient":1}'); -- start_date not provided (mandatory parameter)
  SELECT sd.get_measures_v100('{"id_patient":1,"start_date":"2020-01-01T00:01","end_date":"2020-01-01T00:00"}'); -- start date > end date
  SELECT sd.get_measures_v100('{"id_patient":-1,"start_date":"2020-04-01", "unknown_param": true}'); -- unknown param
*/

DECLARE
  _i_id_patient int;
  _i_start_date timestamp;
  _i_end_date timestamp;

  _err_schema_name text;
  _err_table_name text;
  _err_constraint_name text;
  _err_sql_state text;
  _err_message_text text;
  _err_hint text;

BEGIN
  
  SELECT jsonb_build_object('code', 500, 'status', 'SQL Server Error', 'data', '{}'::text[]) INTO _o_json;
  
  -- 1. CHECKS

  -- reject any keys which are not in the list of defined parameters
  IF (SELECT count(s.jsonb_object_keys) FROM
      (SELECT "jsonb_object_keys" FROM jsonb_object_keys (_i_filters::jsonb - '{id_patient, start_date, end_date}'::text[]) ) s) > 0 
        THEN RAISE EXCEPTION 'Bad request: invalid parameters provided' USING ERRCODE = 'IT001',
        HINT = 'Valid parameters are: id_patient, start_date, end_date. Please check sd.get_measures_v100';
  END IF;

  -- check that a valid id_ has been provided as parameter (both are OK)
  IF NOT (_i_filters::jsonb ?& ARRAY['id_patient', 'start_date'] ) THEN
    RAISE EXCEPTION 'Bad request: either id_patient or start_date are missing' USING ERRCODE = 'IT001', HINT = 'Please check sd.get_measures_v100';
  END IF;
 
  -- assign id_patient
  _i_id_patient := ((_i_filters)->>'id_patient')::int;

-- check the patient is valid
  PERFORM id_patient FROM becalm.patients WHERE id_patient = _i_id_patient;
  IF NOT FOUND THEN
      RAISE EXCEPTION 'Bad request: please select a valid patient (id_patient)'
      USING ERRCODE = 'IT001', HINT = 'Please check sd.get_measures_v100';
  END IF;

-- cast data 
  _i_start_date := ((_i_filters)->>'start_date')::timestamp;
  _i_end_date := ((_i_filters)->>'end_date')::timestamp;

-- check the start date <= end date
  IF (_i_start_date IS NOT NULL) AND (_i_end_date IS NOT NULL) THEN
    IF _i_start_date > _i_end_date THEN
      RAISE EXCEPTION 'Bad request: start date must be before or equal to end date'
      USING ERRCODE = 'IT001', HINT = 'Please check sd.get_measures_v100';
    END IF;
  END IF;
  
  
  -- 2. RETURN DATA
  WITH

  -- **************
  -- PREPARE TABLES
  -- **************

  _sd AS (
  SELECT
    m.id_patient,
    m.measure_type,
    m.measure_value,
    m.date_generation
  FROM
    sd.measures m
  WHERE
    id_patient = _i_id_patient
    AND
      CASE WHEN _i_start_date IS NULL THEN true
      ELSE date_generation >= _i_start_date
      END
    AND
      CASE WHEN _i_end_date IS NULL THEN true
      ELSE date_generation <= _i_end_date
      END
  ORDER BY date_generation DESC
  )
      
  -- *****************************
  -- Arrange JSON and extra fields
  -- *****************************
  
   SELECT
      to_jsonb(r)
  FROM
      (
      SELECT
          200 AS code,
          'OK' AS status,
          -- array with objects {id_patient, measures: [{measure_type, measure_value...}, {..}]
          (
          SELECT jsonb_agg(s) FROM
              (
                SELECT 
                  p.id_patient,
                  coalesce((SELECT jsonb_agg(t) FROM (
                     SELECT
                       _sd.measure_type,
                       _sd.measure_value,
                       _sd.date_generation
                     FROM _sd 
                     WHERE _sd.id_patient = p.id_patient
                    ) t), '[]'::jsonb) as measures
                 FROM becalm.patients p
                 WHERE id_patient = _i_id_patient
              ) s
           ) AS "data") r
      INTO _o_json;
  
    
  -- TODO: remove id_patients for which measures is empty ([])
   
  -- return 404 if no data found
  IF jsonb_typeof(_o_json -> 'data') = 'null' THEN
    SELECT jsonb_build_object('code', 404, 'status', 'Not Found', 'data', '{}'::text[]) INTO _o_json;
  END IF;
  
  -- exception handling
  -- IT001 is error 400 - bad request
   EXCEPTION
  WHEN SQLSTATE 'IT001' THEN 
    GET STACKED DIAGNOSTICS _err_sql_state = RETURNED_SQLSTATE,
    _err_message_text = MESSAGE_TEXT,
    _err_hint = PG_EXCEPTION_HINT;
  
  SELECT
      to_jsonb (s)
  FROM
      (
      SELECT
          400 AS code,
          'Wrong call to SQL Server. SQLSTATE = ' || _err_sql_state || ', Error message = ' || _err_message_text || '. Hint = ' || _err_hint AS status ) s
  INTO
      _o_json;
  -- catch other errors under status 500
  WHEN OTHERS THEN GET STACKED DIAGNOSTICS _err_sql_state = RETURNED_SQLSTATE,
  _err_message_text = MESSAGE_TEXT,
  _err_hint = PG_EXCEPTION_HINT;
  
  SELECT
      to_jsonb (s)
  FROM
      (
      SELECT
          500 AS code,
          'SQL Error Server. SQLSTATE = ' || _err_sql_state || ', Error message = ' || _err_message_text || '. Hint = ' || _err_hint AS status ) s
  INTO
      _o_json;
END;
$function$;

-- *****
-- TESTS
-- *****

-- Pacientes
INSERT INTO becalm.patients (
  id_patient,
  first_name_patient,
  last_name_patient,
  location_hospital,
  location_place)
VALUES
  (1, 'Felipe', 'Becalm', 'Valdemoro', 'Sala 4 - Cama 1'),
  (2, 'Enrique', 'Becalm', 'Valdemoro', 'Sala 4 - Cama 2');
  

-- Aparatos de medida
INSERT INTO sd.devices (
   id_device,
   name_device,
   type_device,
   model_device,
   version_device,
   location_hospital,
   location_place
) 
VALUES (1, 'rasp-smt-dev', 'raspberry_pi', '3B', '1.2', 'Valdemoro', 'Sala 4');

-- insert some test data 
INSERT INTO sd.measures (id_patient, measure_type, measure_value, date_generation) VALUES
(1, 't', 37.5, '2020-04-02T12:15+02'), -- 12:15 hora española, se almacena como 10:15 hora UTC
(1, 't', 37.5, '2020-04-02T12:16+02'),
(1, 't', 37.5, '2020-04-02T12:16.1+02'),
(1, 'p', 100012, '2020-04-02T12:16.1+02'),
(1, 'c', 120, '2020-04-02T12:16.1+02'),
(1, 'o', 121, '2020-04-02T12:16.1+02'),
(2, 't', 37.5, '2020-04-02T12:15+02'), -- second raspberry
(2, 't', 37.5, '2020-04-02T12:16+02'),
(2, 't', 37.5, '2020-04-02T12:16.1+02'),
(2, 'p', 100012, '2020-04-02T12:16.1+02'),
(2, 'c', 120, '2020-04-02T12:16.1+02'),
(2, 'o', 121, '2020-04-02T12:16.1+02');

-- full table (uses partitions)
EXPLAIN ANALYZE SELECT * FROM sd.measures WHERE date_generation > '02-04-2020' AND id_patient = 1;
EXPLAIN ANALYZE SELECT * FROM sd.measures WHERE date_generation > '02-04-2020' AND id_patient = 2;

-- retrieve data 
SELECT
  id_patient,
  measure_type,
  measure_value,
  date_generation
FROM sd.measures m
WHERE date_generation > '2020-04-02T12:00' AND id_patient = 2;



