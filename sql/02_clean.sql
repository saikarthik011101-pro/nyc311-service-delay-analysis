-- NYC 311 service requests (2025): build the clean table
-- Input : raw_311   (text columns, unchanged; run 01_profile.sql step 0 first for the column renames)
-- Output: clean_311 (typed, standardised, with derived columns)
-- Change the year range in the WHERE clause at the bottom if you use another year.

USE nyc311;

DROP TABLE IF EXISTS clean_311;

CREATE TABLE clean_311 AS
WITH base AS (
  SELECT
    CAST(unique_key AS UNSIGNED)             AS unique_key,
    STR_TO_DATE(created_date, '%m/%d/%Y %r') AS created_dt,
    STR_TO_DATE(closed_date,  '%m/%d/%Y %r') AS closed_dt,
    STR_TO_DATE(due_date,     '%m/%d/%Y %r') AS due_dt,
    UPPER(TRIM(agency))                      AS agency,
    UPPER(TRIM(complaint_type))              AS complaint_type,
    UPPER(TRIM(descriptor))                  AS descriptor,
    UPPER(TRIM(status))                      AS status,
    UPPER(TRIM(open_data_channel_type))      AS channel,
    -- keep only the five real boroughs; 'Unspecified' and blanks become NULL
    CASE WHEN UPPER(TRIM(borough)) IN
         ('BRONX','BROOKLYN','MANHATTAN','QUEENS','STATEN ISLAND')
         THEN UPPER(TRIM(borough)) END       AS borough,
    -- keep only valid 5-digit zip codes
    CASE WHEN TRIM(incident_zip) REGEXP '^[0-9]{5}$'
         THEN TRIM(incident_zip) END         AS incident_zip,
    -- keep only coordinates that fall inside New York City
    CASE WHEN CAST(latitude AS DECIMAL(10,6)) BETWEEN 40.49 AND 40.92
          AND CAST(longitude AS DECIMAL(10,6)) BETWEEN -74.27 AND -73.68
         THEN CAST(latitude AS DECIMAL(10,6)) END   AS latitude,
    CASE WHEN CAST(latitude AS DECIMAL(10,6)) BETWEEN 40.49 AND 40.92
          AND CAST(longitude AS DECIMAL(10,6)) BETWEEN -74.27 AND -73.68
         THEN CAST(longitude AS DECIMAL(10,6)) END  AS longitude
  FROM raw_311
),
ranked AS (
  -- duplicate rule (my own assumption): same agency, complaint, descriptor,
  -- location and day. The first request is kept, later ones are flagged.
  SELECT *, ROW_NUMBER() OVER (
      PARTITION BY agency, complaint_type, descriptor, latitude, longitude, DATE(created_dt)
      ORDER BY created_dt, unique_key) AS rn
  FROM base
)
SELECT
  unique_key, created_dt, closed_dt, due_dt, agency, complaint_type, descriptor,
  status, channel, borough, incident_zip, latitude, longitude,
  DATE_FORMAT(created_dt, '%Y-%m') AS created_month,
  (rn > 1 AND latitude IS NOT NULL) AS is_duplicate,
  -- resolution time in hours; NULL if still open or closed before created
  CASE WHEN closed_dt >= created_dt
       THEN TIMESTAMPDIFF(MINUTE, created_dt, closed_dt) / 60 END AS resolution_hours,
  -- 1 when the closing time is exactly midnight (date-only closing)
  CASE WHEN closed_dt IS NOT NULL AND TIME(closed_dt) = '00:00:00'
       THEN 1 ELSE 0 END AS closed_date_only,
  -- only available for the few requests that have an official due date
  CASE WHEN closed_dt >= created_dt AND due_dt IS NOT NULL
       THEN (closed_dt > due_dt) END AS missed_due_date
FROM ranked
WHERE created_dt >= '2025-01-01' AND created_dt < '2026-01-01';

-- Indexes to speed up the analysis queries
ALTER TABLE clean_311
  ADD INDEX idx_created (created_dt),
  ADD INDEX idx_borough (borough(20)),
  ADD INDEX idx_agency (agency(10)),
  ADD INDEX idx_type (complaint_type(60));

-- Quick checks (expected for the 2025 file: total 3,655,042; 190 complaint types)
SELECT COUNT(*) AS total,
       SUM(is_duplicate) AS dupes,
       SUM(borough IS NULL) AS no_borough,
       SUM(resolution_hours IS NULL) AS no_resolution,
       SUM(closed_date_only) AS midnight_closures,
       MIN(resolution_hours) AS min_h,
       MAX(resolution_hours) AS max_h,
       COUNT(DISTINCT complaint_type) AS types_after_cleaning
FROM clean_311;
