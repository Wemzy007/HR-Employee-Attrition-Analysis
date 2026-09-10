-- HR EMPLOYEE ATTRITION ANALYSIS
-- SQL Server / SSMS
-- Portfolio-ready data preparation, validation and exploratory analysis

USE [TDI];
GO

/* ================================================================
   1. DATA PREPARATION
   ================================================================ */

-- Source table assumed to be [HR Dataset].
-- Create a working copy so the source data is not modified.
IF OBJECT_ID('[dbo].[HR2 Dataset]', 'U') IS NOT NULL
    DROP TABLE [dbo].[HR2 Dataset];
GO

SELECT *
INTO [dbo].[HR2 Dataset]
FROM [dbo].[HR Dataset];
GO

/* ================================================================
   2. DATA QUALITY CHECKS
   ================================================================ */

-- Record count
SELECT COUNT(*) AS total_records
FROM [dbo].[HR2 Dataset];

-- Missing-value review
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN id IS NULL THEN 1 ELSE 0 END) AS missing_id,
    SUM(CASE WHEN birth_date IS NULL THEN 1 ELSE 0 END) AS missing_birth_date,
    SUM(CASE WHEN hire_date IS NULL THEN 1 ELSE 0 END) AS missing_hire_date,
    SUM(CASE WHEN term_date IS NULL THEN 1 ELSE 0 END) AS missing_term_date
FROM [dbo].[HR2 Dataset];

-- Duplicate employee IDs
SELECT id, COUNT(*) AS duplicate_count
FROM [dbo].[HR2 Dataset]
GROUP BY id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

/* ================================================================
   3. DUPLICATE REMOVAL
   Keep the most recent hire record for each employee ID.
   ================================================================ */

WITH duplicate_check AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY id
               ORDER BY hire_date DESC
           ) AS rn
    FROM [dbo].[HR2 Dataset]
)
DELETE FROM duplicate_check
WHERE rn > 1;

/* ================================================================
   4. STANDARDIZATION
   ================================================================ */

-- Standardize gender coding
UPDATE [dbo].[HR2 Dataset]
SET gender = 'F'
WHERE gender = 'FM';

-- Correct known job-title inconsistencies
UPDATE [dbo].[HR2 Dataset]
SET job_title = CASE
    WHEN job_title = 'Assistant ProFssor' THEN 'Assistant Professor'
    WHEN job_title = 'Associate ProFssor' THEN 'Associate Professor'
    WHEN job_title = 'Data Coordiator' THEN 'Data Coordinator'
    WHEN job_title = 'Relationshiop Manager' THEN 'Relationship Manager'
    ELSE job_title
END;

-- Trim employee names
UPDATE [dbo].[HR2 Dataset]
SET
    first_name = LTRIM(RTRIM(first_name)),
    last_name  = LTRIM(RTRIM(last_name));

-- Standardize name casing
UPDATE [dbo].[HR2 Dataset]
SET
    first_name = UPPER(LEFT(first_name, 1)) + LOWER(SUBSTRING(first_name, 2, LEN(first_name))),
    last_name  = UPPER(LEFT(last_name, 1)) + LOWER(SUBSTRING(last_name, 2, LEN(last_name)));

-- Convert termination dates to a clean date value.
-- The original field may contain a timestamp, so only the date portion is used.
ALTER TABLE [dbo].[HR2 Dataset]
ADD term_date_clean DATE NULL;

UPDATE [dbo].[HR2 Dataset]
SET term_date_clean = TRY_CONVERT(DATE, LEFT(term_date, 10));

/* ================================================================
   5. ANALYTICAL VARIABLES
   ================================================================ */

ALTER TABLE [dbo].[HR2 Dataset]
ADD
    age INT NULL,
    tenure_years DECIMAL(5,2) NULL,
    tenure_category VARCHAR(15) NULL,
    employment_status VARCHAR(10) NULL,
    attrition_status VARCHAR(10) NULL,
    department_headcount INT NULL,
    male_ratio DECIMAL(5,2) NULL,
    female_ratio DECIMAL(5,2) NULL,
    nonconforming_ratio DECIMAL(5,2) NULL,
    avg_tenure_department DECIMAL(5,2) NULL,
    avg_age_jobtitle DECIMAL(5,2) NULL,
    retention_rate DECIMAL(5,2) NULL,
    monthly_hires INT NULL,
    yearly_hires INT NULL,
    monthly_attrition INT NULL,
    yearly_attrition INT NULL;

-- Age as of the current date, corrected for whether the birthday has occurred.
UPDATE [dbo].[HR2 Dataset]
SET age = DATEDIFF(YEAR, birth_date, CAST(GETDATE() AS DATE))
          - CASE
                WHEN DATEADD(YEAR, DATEDIFF(YEAR, birth_date, CAST(GETDATE() AS DATE)), birth_date)
                     > CAST(GETDATE() AS DATE)
                THEN 1 ELSE 0
            END;

-- Tenure in years, calculated from hire date to termination date for former employees
-- and to today for active employees.
UPDATE [dbo].[HR2 Dataset]
SET tenure_years = CAST(
        DATEDIFF(DAY, hire_date, ISNULL(term_date_clean, CAST(GETDATE() AS DATE))) / 365.25
        AS DECIMAL(5,2)
    );

UPDATE [dbo].[HR2 Dataset]
SET tenure_category = CASE
    WHEN tenure_years < 1 THEN '0 - 1 yr'
    WHEN tenure_years < 5 THEN '1 - 5 yrs'
    WHEN tenure_years < 10 THEN '5 - 10 yrs'
    ELSE '> 10 yrs'
END;

UPDATE [dbo].[HR2 Dataset]
SET
    employment_status = CASE
        WHEN term_date_clean IS NULL OR term_date_clean > CAST(GETDATE() AS DATE)
            THEN 'Active'
        ELSE 'Left'
    END,
    attrition_status = CASE
        WHEN term_date_clean IS NULL OR term_date_clean > CAST(GETDATE() AS DATE)
            THEN 'Active'
        ELSE 'Left'
    END;

/* ================================================================
   6. DEPARTMENT HEADCOUNT & GENDER MIX
   ================================================================ */

WITH department_counts AS (
    SELECT department, COUNT(*) AS headcount
    FROM [dbo].[HR2 Dataset]
    GROUP BY department
)
UPDATE hr
SET department_headcount = dc.headcount
FROM [dbo].[HR2 Dataset] hr
JOIN department_counts dc
  ON hr.department = dc.department;

WITH gender_counts AS (
    SELECT
        department,
        COUNT(*) AS total_count,
        SUM(CASE WHEN gender = 'M' THEN 1 ELSE 0 END) AS male_count,
        SUM(CASE WHEN gender = 'F' THEN 1 ELSE 0 END) AS female_count,
        SUM(CASE WHEN gender = 'Nonconforming' THEN 1 ELSE 0 END) AS nonconforming_count
    FROM [dbo].[HR2 Dataset]
    GROUP BY department
)
UPDATE hr
SET
    male_ratio = CAST(gc.male_count * 100.0 / NULLIF(gc.total_count, 0) AS DECIMAL(5,2)),
    female_ratio = CAST(gc.female_count * 100.0 / NULLIF(gc.total_count, 0) AS DECIMAL(5,2)),
    nonconforming_ratio = CAST(gc.nonconforming_count * 100.0 / NULLIF(gc.total_count, 0) AS DECIMAL(5,2))
FROM [dbo].[HR2 Dataset] hr
JOIN gender_counts gc
  ON hr.department = gc.department;

/* ================================================================
   7. DEPARTMENT / JOB TITLE METRICS
   ================================================================ */

WITH avg_tenure AS (
    SELECT department, AVG(tenure_years) AS avg_tenure
    FROM [dbo].[HR2 Dataset]
    GROUP BY department
)
UPDATE hr
SET avg_tenure_department = CAST(at.avg_tenure AS DECIMAL(5,2))
FROM [dbo].[HR2 Dataset] hr
JOIN avg_tenure at
  ON hr.department = at.department;

WITH avg_age AS (
    SELECT job_title, AVG(CAST(age AS DECIMAL(10,2))) AS avg_age
    FROM [dbo].[HR2 Dataset]
    GROUP BY job_title
)
UPDATE hr
SET avg_age_jobtitle = CAST(aa.avg_age AS DECIMAL(5,2))
FROM [dbo].[HR2 Dataset] hr
JOIN avg_age aa
  ON hr.job_title = aa.job_title;

WITH retention AS (
    SELECT
        department,
        COUNT(CASE WHEN employment_status = 'Active' THEN 1 END) * 100.0
            / NULLIF(COUNT(*),0) AS retention_rate
    FROM [dbo].[HR2 Dataset]
    GROUP BY department
)
UPDATE hr
SET retention_rate = CAST(r.retention_rate AS DECIMAL(5,2))
FROM [dbo].[HR2 Dataset] hr
JOIN retention r
  ON hr.department = r.department;

/* ================================================================
   8. MONTHLY / YEARLY WORKFORCE MOVEMENT
   ================================================================ */

WITH monthly_hires AS (
    SELECT YEAR(hire_date) AS hire_year, MONTH(hire_date) AS hire_month, COUNT(*) AS hires
    FROM [dbo].[HR2 Dataset]
    GROUP BY YEAR(hire_date), MONTH(hire_date)
)
UPDATE hr
SET monthly_hires = mh.hires
FROM [dbo].[HR2 Dataset] hr
JOIN monthly_hires mh
  ON YEAR(hr.hire_date) = mh.hire_year
 AND MONTH(hr.hire_date) = mh.hire_month;

WITH yearly_hires AS (
    SELECT YEAR(hire_date) AS hire_year, COUNT(*) AS hires
    FROM [dbo].[HR2 Dataset]
    GROUP BY YEAR(hire_date)
)
UPDATE hr
SET yearly_hires = yh.hires
FROM [dbo].[HR2 Dataset] hr
JOIN yearly_hires yh
  ON YEAR(hr.hire_date) = yh.hire_year;

WITH monthly_attrition AS (
    SELECT YEAR(term_date_clean) AS term_year, MONTH(term_date_clean) AS term_month, COUNT(*) AS attrition_count
    FROM [dbo].[HR2 Dataset]
    WHERE term_date_clean IS NOT NULL
    GROUP BY YEAR(term_date_clean), MONTH(term_date_clean)
)
UPDATE hr
SET monthly_attrition = ma.attrition_count
FROM [dbo].[HR2 Dataset] hr
JOIN monthly_attrition ma
  ON YEAR(hr.term_date_clean) = ma.term_year
 AND MONTH(hr.term_date_clean) = ma.term_month;

WITH yearly_attrition AS (
    SELECT YEAR(term_date_clean) AS term_year, COUNT(*) AS attrition_count
    FROM [dbo].[HR2 Dataset]
    WHERE term_date_clean IS NOT NULL
    GROUP BY YEAR(term_date_clean)
)
UPDATE hr
SET yearly_attrition = ya.attrition_count
FROM [dbo].[HR2 Dataset] hr
JOIN yearly_attrition ya
  ON YEAR(hr.term_date_clean) = ya.term_year;

/* ================================================================
   9. CORE EDA / BUSINESS QUESTIONS
   ================================================================ */

-- Overall attrition and retention
SELECT
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) AS attrition_count,
    COUNT(CASE WHEN employment_status = 'Active' THEN 1 END) AS active_count,
    CAST(COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate,
    CAST(COUNT(CASE WHEN employment_status = 'Active' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS retention_rate
FROM [dbo].[HR2 Dataset];

-- Attrition by department
SELECT
    department,
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) AS attrition_count,
    CAST(COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate
FROM [dbo].[HR2 Dataset]
GROUP BY department
ORDER BY attrition_rate DESC;

-- Attrition by job title
SELECT
    job_title,
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) AS attrition_count,
    CAST(COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate
FROM [dbo].[HR2 Dataset]
GROUP BY job_title
ORDER BY attrition_rate DESC, attrition_count DESC;

-- Attrition by tenure category
SELECT
    tenure_category,
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) AS attrition_count,
    CAST(COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate
FROM [dbo].[HR2 Dataset]
GROUP BY tenure_category
ORDER BY
    CASE tenure_category
        WHEN '0 - 1 yr' THEN 1
        WHEN '1 - 5 yrs' THEN 2
        WHEN '5 - 10 yrs' THEN 3
        WHEN '> 10 yrs' THEN 4
    END;

-- Attrition by gender
SELECT
    gender,
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) AS attrition_count,
    CAST(COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate
FROM [dbo].[HR2 Dataset]
GROUP BY gender
ORDER BY attrition_rate DESC;

-- Attrition by race / ethnicity
SELECT
    race,
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) AS attrition_count,
    CAST(COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate
FROM [dbo].[HR2 Dataset]
GROUP BY race
ORDER BY attrition_rate DESC;

-- Attrition by work location
SELECT
    location,
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) AS attrition_count,
    CAST(COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate
FROM [dbo].[HR2 Dataset]
GROUP BY location
ORDER BY attrition_rate DESC;

-- Attrition by city
SELECT
    location_city,
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) AS attrition_count,
    CAST(COUNT(CASE WHEN employment_status = 'Left' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS attrition_rate
FROM [dbo].[HR2 Dataset]
GROUP BY location_city
ORDER BY attrition_rate DESC;

-- Average tenure overall
SELECT AVG(tenure_years) AS average_tenure_years
FROM [dbo].[HR2 Dataset];

-- Average tenure by department
SELECT
    department,
    AVG(tenure_years) AS average_tenure_years
FROM [dbo].[HR2 Dataset]
GROUP BY department
ORDER BY average_tenure_years ASC;

-- Retention by department
SELECT
    department,
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN employment_status = 'Active' THEN 1 END) AS active_employees,
    CAST(COUNT(CASE WHEN employment_status = 'Active' THEN 1 END) * 100.0 / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS retention_rate
FROM [dbo].[HR2 Dataset]
GROUP BY department
ORDER BY retention_rate DESC;

/* ================================================================
   10. OUTLIER REVIEW
   ================================================================ */

WITH tenure_stats AS (
    SELECT
        AVG(tenure_years) AS mean_tenure,
        STDEV(tenure_years) AS stddev_tenure
    FROM [dbo].[HR2 Dataset]
)
SELECT
    hr.id,
    hr.department,
    hr.job_title,
    hr.tenure_years,
    ts.mean_tenure,
    ts.stddev_tenure,
    CASE
        WHEN ts.stddev_tenure = 0 OR ts.stddev_tenure IS NULL THEN NULL
        ELSE (hr.tenure_years - ts.mean_tenure) / ts.stddev_tenure
    END AS z_score,
    CASE
        WHEN ts.stddev_tenure IS NOT NULL
             AND ts.stddev_tenure <> 0
             AND ABS((hr.tenure_years - ts.mean_tenure) / ts.stddev_tenure) > 3
            THEN 'Outlier'
        ELSE 'Normal'
    END AS outlier_status
FROM [dbo].[HR2 Dataset] hr
CROSS JOIN tenure_stats ts;

/* ================================================================
   11. ANALYTICAL OUTPUT TABLES
   ================================================================ */

IF OBJECT_ID('[dbo].[HR2 Dataset Backup]', 'U') IS NOT NULL
    DROP TABLE [dbo].[HR2 Dataset Backup];

SELECT *
INTO [dbo].[HR2 Dataset Backup]
FROM [dbo].[HR2 Dataset];

IF OBJECT_ID('[dbo].[HR2 Dataset Cleaned]', 'U') IS NOT NULL
    DROP TABLE [dbo].[HR2 Dataset Cleaned];

SELECT *
INTO [dbo].[HR2 Dataset Cleaned]
FROM [dbo].[HR2 Dataset];

/* ================================================================
   12. FINAL VALIDATION
   ================================================================ */

SELECT
    COUNT(*) AS final_record_count,
    COUNT(DISTINCT id) AS distinct_employee_ids,
    SUM(CASE WHEN employment_status = 'Active' THEN 1 ELSE 0 END) AS active_employees,
    SUM(CASE WHEN employment_status = 'Left' THEN 1 ELSE 0 END) AS employees_left,
    SUM(CASE WHEN term_date_clean IS NULL THEN 1 ELSE 0 END) AS null_clean_term_dates
FROM [dbo].[HR2 Dataset Cleaned];

-- End of HR Employee Attrition Analysis
