-- HR ATTRITION ANALYSIS
-- SQL Server / SSMS
-- Data preprocessing, cleaning, transformation and exploratory analysis

USE [TDI]
GO

-- DATA PRE-PROCESSING
CREATE TABLE [dbo].[HR2 Dataset](
    [id] [nvarchar](50) NOT NULL,
    [first_name] [nvarchar](50) NOT NULL,
    [last_name] [nvarchar](50) NOT NULL,
    [birth_date] [date] NOT NULL,
    [gender] [nvarchar](50) NOT NULL,
    [race] [nvarchar](50) NOT NULL,
    [department] [nvarchar](50) NOT NULL,
    [job_title] [nvarchar](50) NOT NULL,
    [location] [nvarchar](50) NOT NULL,
    [hire_date] [date] NOT NULL,
    [term_date] [varchar](50) NULL,
    [location_city] [nvarchar](50) NOT NULL,
    [location_state] [nvarchar](50) NOT NULL
) ON [PRIMARY]
GO

INSERT INTO [HR2 Dataset]
SELECT * FROM [HR Dataset];

-- DATA CLEANING AND PREPROCESSING

-- 1. Missing values
SELECT
    COUNT(*) AS TotalRecords,
    COUNT(CASE WHEN birth_date IS NULL THEN 1 END) AS MissingBirthDates,
    COUNT(CASE WHEN hire_date IS NULL THEN 1 END) AS MissingHireDates,
    COUNT(CASE WHEN term_date IS NULL THEN 1 END) AS MissingTermDates
FROM [HR2 Dataset];

-- 2. Duplicate identification and removal
SELECT id, COUNT(*)
FROM [HR2 Dataset]
GROUP BY id
HAVING COUNT(*) > 1;

SELECT * FROM [HR2 Dataset]
WHERE id IN (
    SELECT id
    FROM [HR2 Dataset]
    GROUP BY id
    HAVING COUNT(*) > 1
)
ORDER BY id;

WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY id ORDER BY hire_date DESC) AS rn
    FROM [HR2 Dataset]
)
DELETE FROM CTE
WHERE rn > 1;

-- 3. Data standardization
UPDATE [HR2 Dataset]
SET gender = 'F'
WHERE gender = 'FM';

SELECT DISTINCT job_title
FROM [HR2 Dataset]
ORDER BY job_title;

UPDATE [HR2 Dataset]
SET job_title = CASE
    WHEN job_title = 'Assistant ProFssor' THEN 'Assistant Professor'
    WHEN job_title = 'Associate ProFssor' THEN 'Associate Professor'
    WHEN job_title = 'Data Coordiator' THEN 'Data Coordinator'
    WHEN job_title = 'Relationshiop Manager' THEN 'Relationship Manager'
    ELSE job_title
END;

UPDATE [HR2 Dataset]
SET term_date = LEFT(term_date,10)
WHERE LEN(term_date) > 10
AND term_date IS NOT NULL;

UPDATE [HR2 Dataset]
SET
    first_name = UPPER(LEFT(first_name, 1)) + LOWER(SUBSTRING(first_name, 2, LEN(first_name))),
    last_name = UPPER(LEFT(last_name, 1)) + LOWER(SUBSTRING(last_name, 2, LEN(last_name)));

UPDATE [HR2 Dataset]
SET
    first_name = LTRIM(RTRIM(first_name)),
    last_name = LTRIM(RTRIM(last_name));

-- 4. Creating analytical variables
ALTER TABLE [HR2 Dataset]
ADD
    tenure_years INT,
    age INT,
    employment_status VARCHAR(10),
    department_headcount INT,
    gender_ratio DECIMAL(5, 2),
    avg_tenure_department DECIMAL(5, 2),
    avg_age_jobtitle DECIMAL(5, 2),
    retention_rate DECIMAL(5, 2);

ALTER TABLE [HR2 Dataset] ADD attrition_status VARCHAR(10);

UPDATE [HR2 Dataset]
SET tenure_years = DATEDIFF(YEAR, hire_date, ISNULL(term_date, GETDATE()));

UPDATE [HR2 Dataset]
SET age = DATEDIFF(YEAR, birth_date, GETDATE());

UPDATE [HR2 Dataset]
SET attrition_status = CASE
    WHEN term_date IS NULL THEN 'Active'
    WHEN term_date > GETDATE() THEN 'Active'
    WHEN term_date <= GETDATE() THEN 'Left'
END;

UPDATE [HR2 Dataset]
SET department_headcount = (
    SELECT COUNT(*)
    FROM [HR2 Dataset] AS inner_table
    WHERE inner_table.department = [HR2 Dataset].department
);

ALTER TABLE [HR2 Dataset]
ADD
    male_ratio DECIMAL(5, 2),
    female_ratio DECIMAL(5, 2),
    nonconforming_ratio DECIMAL(5, 2);

WITH GenderCounts AS (
    SELECT
        department,
        COUNT(*) AS total_count,
        SUM(CASE WHEN gender = 'M' THEN 1 ELSE 0 END) AS male_count,
        SUM(CASE WHEN gender = 'F' THEN 1 ELSE 0 END) AS female_count,
        SUM(CASE WHEN gender = 'Nonconforming' THEN 1 ELSE 0 END) AS nonconforming_count
    FROM [HR2 Dataset]
    GROUP BY department
)
UPDATE [HR2 Dataset]
SET
    male_ratio = (CAST(GenderCounts.male_count AS DECIMAL(10, 2)) * 100.0 / CAST(GenderCounts.total_count AS DECIMAL(10, 2))),
    female_ratio = (CAST(GenderCounts.female_count AS DECIMAL(10, 2)) * 100.0 / CAST(GenderCounts.total_count AS DECIMAL(10, 2))),
    nonconforming_ratio = (CAST(GenderCounts.nonconforming_count AS DECIMAL(10, 2)) * 100.0 / CAST(GenderCounts.total_count AS DECIMAL(10, 2)))
FROM [HR2 Dataset]
INNER JOIN GenderCounts
ON [HR2 Dataset].department = GenderCounts.department;

-- Gender composition by department
SELECT
    department,
    COUNT(*) AS total_count,
    SUM(CASE WHEN gender = 'M' THEN 1 ELSE 0 END) AS male_count,
    SUM(CASE WHEN gender = 'F' THEN 1 ELSE 0 END) AS female_count,
    SUM(CASE WHEN gender = 'Nonconforming' THEN 1 ELSE 0 END) AS nonconforming_count,
    ROUND(CAST(SUM(CASE WHEN gender = 'M' THEN 1 ELSE 0 END) AS DECIMAL(10, 2)) * 100.0 / NULLIF(COUNT(*), 0), 2) AS male_ratio,
    ROUND(CAST(SUM(CASE WHEN gender = 'F' THEN 1 ELSE 0 END) AS DECIMAL(10, 2)) * 100.0 / NULLIF(COUNT(*), 0), 2) AS female_ratio,
    ROUND(CAST(SUM(CASE WHEN gender = 'Nonconforming' THEN 1 ELSE 0 END) AS DECIMAL(10, 2)) * 100.0 / NULLIF(COUNT(*), 0), 2) AS nonconforming_ratio
FROM [HR2 Dataset]
GROUP BY department
ORDER BY department;

-- Average tenure by department
WITH AvgTenure AS (
    SELECT
        department,
        AVG(DATEDIFF(YEAR, hire_date, ISNULL(term_date, GETDATE()))) AS avg_tenure
    FROM [HR2 Dataset]
    GROUP BY department
)
UPDATE hr
SET avg_tenure_department = at.avg_tenure
FROM [HR2 Dataset] AS hr
INNER JOIN AvgTenure AS at
ON hr.department = at.department;

-- Average age by job title
WITH AvgAge AS (
    SELECT
        job_title,
        AVG(DATEDIFF(YEAR, birth_date, GETDATE())) AS avg_age
    FROM [HR2 Dataset]
    GROUP BY job_title
)
UPDATE [HR2 Dataset]
SET avg_age_jobtitle = AvgAge.avg_age
FROM [HR2 Dataset]
JOIN AvgAge
ON [HR2 Dataset].job_title = AvgAge.job_title;

-- Retention rate by department
WITH Retention AS (
    SELECT
        department,
        (CAST(COUNT(CASE WHEN term_date IS NULL THEN 1 END) AS FLOAT) * 100.0 / COUNT(*)) AS retention_rate
    FROM [HR2 Dataset]
    GROUP BY department
)
UPDATE [HR2 Dataset]
SET retention_rate = Retention.retention_rate
FROM [HR2 Dataset]
JOIN Retention
ON [HR2 Dataset].department = Retention.department;

-- Monthly / yearly hires
ALTER TABLE [HR2 Dataset]
ADD
    monthly_hires INT NULL,
    yearly_hires INT NULL,
    monthly_attrition INT NULL,
    yearly_attrition INT NULL;

WITH YearlyHires AS (
    SELECT
        YEAR(hire_date) AS hire_year,
        COUNT(*) AS yearly_hires
    FROM [HR2 Dataset]
    GROUP BY YEAR(hire_date)
)
UPDATE hr
SET yearly_hires = yh.yearly_hires
FROM [HR2 Dataset] AS hr
INNER JOIN YearlyHires AS yh
ON YEAR(hr.hire_date) = yh.hire_year;

WITH MonthlyAttrition AS (
    SELECT
        YEAR(term_date) AS term_year,
        MONTH(term_date) AS term_month,
        COUNT(*) AS monthly_attrition
    FROM [HR2 Dataset]
    WHERE term_date IS NOT NULL
    GROUP BY YEAR(term_date), MONTH(term_date)
)
UPDATE hr
SET monthly_attrition = ma.monthly_attrition
FROM [HR2 Dataset] AS hr
INNER JOIN MonthlyAttrition AS ma
ON YEAR(hr.term_date) = ma.term_year
AND MONTH(hr.term_date) = ma.term_month;

WITH YearlyAttrition AS (
    SELECT
        YEAR(term_date) AS term_year,
        COUNT(*) AS yearly_attrition
    FROM [HR2 Dataset]
    WHERE term_date IS NOT NULL
    GROUP BY YEAR(term_date)
)
UPDATE hr
SET yearly_attrition = ya.yearly_attrition
FROM [HR2 Dataset] AS hr
INNER JOIN YearlyAttrition AS ya
ON YEAR(hr.term_date) = ya.term_year;

-- EDA: employee attrition rate by department
SELECT
    department,
    COUNT(*) AS total_employees,
    COUNT(CASE WHEN term_date IS NOT NULL THEN 1 END) AS num_terminated,
    (COUNT(CASE WHEN term_date IS NOT NULL THEN 1 END) * 100.0 / COUNT(*)) AS attrition_rate
FROM [HR2 Dataset]
GROUP BY department;

-- Tenure category
ALTER TABLE [HR2 Dataset]
ADD tenure_category VARCHAR(15);

UPDATE [HR2 Dataset]
SET tenure_category = CASE
    WHEN DATEDIFF(YEAR, hire_date, ISNULL(term_date, GETDATE())) < 1 THEN '0 - 1 yr'
    WHEN DATEDIFF(YEAR, hire_date, ISNULL(term_date, GETDATE())) BETWEEN 1 AND 5 THEN '1 - 5 yrs'
    WHEN DATEDIFF(YEAR, hire_date, ISNULL(term_date, GETDATE())) BETWEEN 5 AND 10 THEN '5 - 10 yrs'
    ELSE '> 10 yrs'
END;

-- 5. Outlier review using tenure z-scores
WITH Stats AS (
    SELECT
        AVG(tenure_years) AS mean,
        STDEV(tenure_years) AS stddev
    FROM [HR2 Dataset]
)
SELECT *,
       (tenure_years - mean) / stddev AS z_score,
       CASE
           WHEN ABS((tenure_years - mean) / stddev) > 3 THEN 'Outlier'
           ELSE 'Normal'
       END AS outlier_status
FROM [HR2 Dataset], Stats;

-- ANALYSIS FOR KEY FACTORS CONTRIBUTING TO EMPLOYEE ATTRITION

-- 1. Overall attrition rate
SELECT
    (COUNT(CASE WHEN term_date IS NOT NULL THEN 1 END) * 100.0 / COUNT(*)) AS attrition_rate
FROM [HR2 Dataset];

-- 2. Attrition rate by department
SELECT
    department,
    (COUNT(CASE WHEN term_date IS NOT NULL THEN 1 END) * 100.0 / COUNT(*)) AS attrition_rate
FROM [HR2 Dataset]
GROUP BY department
ORDER BY attrition_rate DESC;

-- 3. Attrition rate by job role
SELECT
    job_title,
    (COUNT(CASE WHEN term_date IS NOT NULL THEN 1 END) * 100.0 / COUNT(*)) AS attrition_rate
FROM [HR2 Dataset]
GROUP BY job_title
ORDER BY attrition_rate DESC;

-- 4. Attrition rate by tenure
SELECT
    tenure_years,
    (COUNT(CASE WHEN term_date IS NOT NULL THEN 1 END) * 100.0 / COUNT(*)) AS attrition_rate
FROM [HR2 Dataset]
GROUP BY tenure_years
ORDER BY tenure_years;

-- 5. Attrition rate by gender
SELECT
    gender,
    (COUNT(CASE WHEN term_date IS NOT NULL THEN 1 END) * 100.0 / COUNT(*)) AS attrition_rate
FROM [HR2 Dataset]
GROUP BY gender;

-- 6. Attrition rate by race / ethnicity
SELECT
    race,
    (COUNT(CASE WHEN term_date IS NOT NULL THEN 1 END) * 100.0 / COUNT(*)) AS attrition_rate
FROM [HR2 Dataset]
GROUP BY race
ORDER BY attrition_rate DESC;

-- 7. Average tenure
SELECT
    AVG(DATEDIFF(YEAR, hire_date, ISNULL(term_date, GETDATE()))) AS avg_tenure
FROM [HR2 Dataset];

-- 8. Average tenure by department
SELECT
    department,
    AVG(DATEDIFF(YEAR, hire_date, ISNULL(term_date, GETDATE()))) AS avg_tenure
FROM [HR2 Dataset]
GROUP BY department
ORDER BY avg_tenure ASC;

-- 9. Overall retention rate
SELECT
    (COUNT(CASE WHEN term_date IS NULL THEN 1 END) * 100.0 / COUNT(*)) AS retention_rate
FROM [HR2 Dataset];

-- 10. Retention rate by department
SELECT
    department,
    (COUNT(CASE WHEN term_date IS NULL THEN 1 END) * 100.0 / COUNT(*)) AS retention_rate
FROM [HR2 Dataset]
GROUP BY department
ORDER BY retention_rate DESC;

-- Backup and cleaned tables
SELECT * INTO [HR2 Dataset Backup]
FROM [HR2 Dataset];

SELECT * INTO [HR2 Dataset Cleaned]
FROM [HR2 Dataset];
