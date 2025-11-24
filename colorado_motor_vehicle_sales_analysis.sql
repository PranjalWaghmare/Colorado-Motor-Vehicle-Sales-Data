-- Colorado Motor Vehicle Sales Analysis Script (MySQL Workbench)
-- Author: Pranjal Waghmare
-- Date: November 11, 2025
-- Description: Complete SQL project to clean, analyze, and summarize Colorado vehicle sales data.

CREATE DATABASE IF NOT EXISTS colorado_sales;
USE colorado_sales;

-- 1. Create raw table (for manual CSV import)
DROP TABLE IF EXISTS raw_motor_sales;
CREATE TABLE raw_motor_sales (
  year INT,
  quarter INT,
  county VARCHAR(255),
  sales BIGINT
);

-- >>> STEP 1 <<<
-- Import 'colorado_motor_vehicle_sales.csv' into 'raw_motor_sales' manually via:
-- Right-click table → Table Data Import Wizard

-- 2. Create cleaned table from raw data
DROP TABLE IF EXISTS cleaned_motor_sales;
CREATE TABLE cleaned_motor_sales AS
SELECT
  CAST(year AS SIGNED) AS year,
  CAST(quarter AS SIGNED) AS quarter,
  CONCAT(UPPER(LEFT(TRIM(REPLACE(county, '/', ' & ')),1)),
         LOWER(SUBSTRING(TRIM(REPLACE(county, '/', ' & ')),2))
        ) AS county,
  CAST(sales AS SIGNED) AS sales
FROM raw_motor_sales;

-- 3. Remove exact duplicates
ALTER TABLE cleaned_motor_sales ADD COLUMN tmp_id INT AUTO_INCREMENT PRIMARY KEY;
CREATE TABLE tmp_nodup AS
SELECT year, quarter, county, sales
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY year, quarter, county, sales ORDER BY tmp_id) AS rn
  FROM cleaned_motor_sales
) t
WHERE rn = 1;
DROP TABLE cleaned_motor_sales;
RENAME TABLE tmp_nodup TO cleaned_motor_sales;

-- 4. Add indexes
ALTER TABLE cleaned_motor_sales
  MODIFY COLUMN year INT NOT NULL,
  MODIFY COLUMN quarter INT NOT NULL,
  MODIFY COLUMN county VARCHAR(255) NOT NULL,
  MODIFY COLUMN sales BIGINT NOT NULL;
CREATE INDEX idx_year ON cleaned_motor_sales(year);
CREATE INDEX idx_county ON cleaned_motor_sales(county);

-- 5. Summary Statistics
SELECT COUNT(*) AS total_rows,
       COUNT(DISTINCT county) AS unique_counties,
       MIN(year) AS start_year,
       MAX(year) AS end_year,
       SUM(sales) AS total_sales
FROM cleaned_motor_sales;

-- 6. EDA Queries
-- Yearly totals
SELECT year, SUM(sales) AS total_sales
FROM cleaned_motor_sales
GROUP BY year ORDER BY year;

-- Year-over-year percentage change
WITH yearly AS (
  SELECT year, SUM(sales) AS total_sales FROM cleaned_motor_sales GROUP BY year
)
SELECT year,
       total_sales,
       ROUND((total_sales - LAG(total_sales) OVER (ORDER BY year)) / NULLIF(LAG(total_sales) OVER (ORDER BY year),0) * 100, 2) AS yoy_change_pct
FROM yearly;

-- Quarterly totals (all years combined)
SELECT quarter, SUM(sales) AS total_sales
FROM cleaned_motor_sales
GROUP BY quarter ORDER BY quarter;

-- Top 10 counties by total sales
SELECT county, SUM(sales) AS total_sales
FROM cleaned_motor_sales
GROUP BY county ORDER BY total_sales DESC LIMIT 10;

-- Bottom 10 counties
SELECT county, SUM(sales) AS total_sales
FROM cleaned_motor_sales
GROUP BY county ORDER BY total_sales ASC LIMIT 10;

-- Quarterly timeline
SELECT year, quarter, SUM(sales) AS total_sales
FROM cleaned_motor_sales
GROUP BY year, quarter ORDER BY year, quarter;

-- County share of state total
WITH county_total AS (
  SELECT county, SUM(sales) AS county_sales FROM cleaned_motor_sales GROUP BY county
),
state_total AS (
  SELECT SUM(sales) AS state_sales FROM cleaned_motor_sales
)
SELECT c.county, c.county_sales,
       ROUND(c.county_sales / s.state_sales * 100, 2) AS pct_of_state_sales
FROM county_total c CROSS JOIN state_total s
ORDER BY c.county_sales DESC;

-- 7. Views for dashboards
DROP VIEW IF EXISTS v_yearly_sales;
CREATE VIEW v_yearly_sales AS
SELECT year, SUM(sales) AS total_sales
FROM cleaned_motor_sales GROUP BY year;

DROP VIEW IF EXISTS v_quarterly_sales;
CREATE VIEW v_quarterly_sales AS
SELECT quarter, SUM(sales) AS total_sales
FROM cleaned_motor_sales GROUP BY quarter;

DROP VIEW IF EXISTS v_county_sales;
CREATE VIEW v_county_sales AS
SELECT county, SUM(sales) AS total_sales
FROM cleaned_motor_sales GROUP BY county;

-- 8. Stored procedure example: Get top-N counties
DROP PROCEDURE IF EXISTS get_top_counties;
DELIMITER $$
CREATE PROCEDURE get_top_counties(IN n INT)
BEGIN
  SELECT county, SUM(sales) AS total_sales
  FROM cleaned_motor_sales
  GROUP BY county ORDER BY total_sales DESC LIMIT n;
END $$
DELIMITER ;


