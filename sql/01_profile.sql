-- NYC 311 service requests (2025): data profiling
-- Run against the raw table `raw_311` (all columns loaded as text, unchanged).
-- Date format in the source file: 01/01/2025 12:00:12 AM  ->  '%m/%d/%Y %r'

USE nyc311;

-- 0. One-time setup: rename the two columns that have parentheses in the source file
ALTER TABLE raw_311 RENAME COLUMN `problem_(formerly_complaint_type)` TO complaint_type;
ALTER TABLE raw_311 RENAME COLUMN `problem_detail_(formerly_descriptor)` TO descriptor;

-- 1. Totals and missing values
SELECT COUNT(*) AS total,
       SUM(closed_date IS NULL) AS missing_closed,
       SUM(due_date IS NULL) AS missing_due,
       SUM(borough IS NULL OR borough IN ('Unspecified','')) AS bad_borough,
       SUM(latitude IS NULL) AS missing_lat
FROM raw_311;

-- 2. Closed before created
SELECT COUNT(*) AS closed_before_created
FROM raw_311
WHERE closed_date IS NOT NULL
  AND STR_TO_DATE(closed_date, '%m/%d/%Y %r') < STR_TO_DATE(created_date, '%m/%d/%Y %r');

-- 3. Created dates by year (should be only 2025)
SELECT YEAR(STR_TO_DATE(created_date, '%m/%d/%Y %r')) AS yr, COUNT(*) AS n
FROM raw_311
GROUP BY yr
ORDER BY yr;

-- 4. Borough values
SELECT borough, COUNT(*) AS n
FROM raw_311
GROUP BY borough
ORDER BY n DESC;

-- 5. Agencies with more than one agency name
SELECT agency, COUNT(DISTINCT agency_name) AS names, COUNT(*) AS n
FROM raw_311
GROUP BY agency
HAVING names > 1
ORDER BY n DESC;

-- 6. Coordinates outside NYC
SELECT COUNT(*) AS bad_coords
FROM raw_311
WHERE latitude IS NOT NULL
  AND (CAST(latitude AS DECIMAL(10,6)) NOT BETWEEN 40.49 AND 40.92
       OR CAST(longitude AS DECIMAL(10,6)) NOT BETWEEN -74.27 AND -73.68);

-- 7. Complaint type variety
SELECT COUNT(DISTINCT complaint_type) AS types FROM raw_311;

SELECT complaint_type, COUNT(*) AS n
FROM raw_311
GROUP BY 1
ORDER BY n DESC
LIMIT 30;

-- 8. Most repeated closed timestamps (looks for batch closing)
SELECT closed_date, COUNT(*) AS n
FROM raw_311
WHERE closed_date IS NOT NULL
GROUP BY closed_date
ORDER BY n DESC
LIMIT 10;

-- 9. Due date coverage by agency
SELECT agency,
       COUNT(*) AS requests,
       SUM(due_date IS NOT NULL) AS with_due,
       ROUND(100 * SUM(due_date IS NOT NULL) / COUNT(*), 1) AS pct_with_due
FROM raw_311
GROUP BY agency
ORDER BY requests DESC
LIMIT 15;

-- 10. Same complaint type under more than one agency (example check)
SELECT complaint_type, agency, COUNT(*) AS n
FROM raw_311
WHERE complaint_type IN ('Encampment', 'Traffic Signal Condition')
GROUP BY 1, 2;
