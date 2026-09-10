# HR Employee Attrition Analysis

## Project Overview

This project analyzes employee workforce data to identify patterns in employee attrition and retention across demographics, locations, departments, job roles, and tenure.

The analysis was completed using **Microsoft SQL Server** for data profiling, cleaning, transformation, and analysis, followed by **Microsoft Excel** for pivot-table analysis, visualizations, dashboard development, and reporting.

## Business Problem

Spire Pro Integrated Limited was experiencing employee turnover that could affect productivity, morale, and operating costs. The project focused on understanding where employee attrition was concentrated and identifying areas where targeted retention strategies could be considered.

## Project Objectives

- Analyze attrition across age, gender, race/ethnicity, and location
- Compare attrition across departments and job titles
- Examine the relationship between tenure and attrition
- Evaluate retention patterns across departments and age groups
- Identify high-attrition locations, departments, and roles
- Provide data-driven recommendations for improving employee retention

## Dataset

**Source:** The Data Initiative (TDI)

The analysis uses employee workforce records containing fields such as employee ID, name, birth date, gender, race, department, job title, location, hire date, and termination date.

After preprocessing, the analysis reported **22,214 employee records** and **2,572 attrition cases**.

## Data Preparation & SQL Analysis

SQL Server was used for the main data preparation and analytical workflow, including:

- Data profiling and structure checks
- Missing-value checks
- Duplicate identification and removal using `ROW_NUMBER()`
- Gender standardization
- Correction of inconsistent job-title spellings
- Termination-date formatting
- Employee-name standardization and whitespace trimming
- Creation of analytical variables including age, tenure, employment status, attrition status, department headcount, gender ratios, average tenure, average age by job title, and retention rate
- Calculation of attrition and retention metrics by department, job title, tenure, gender, and race/ethnicity
- Outlier review using tenure z-scores
- Monthly and yearly hire/attrition measures

## Excel Analysis & Dashboard

The SQL analysis was exported to Microsoft Excel for visualization and reporting.

The Excel workbook contains analysis areas covering:

- Attrition by Demography
- Attrition by Department
- Attrition by Job Title
- Attrition by Tenure
- Retention Rate
- Dashboard
- Data Source

The final dashboard brings the major workforce indicators and analytical findings together for management-oriented interpretation.

## Key Findings

- Overall retention was approximately **82.86%**, while the reported overall attrition rate was approximately **11.58%**.
- Headquarters had a slightly higher attrition rate (**11.77%**) than remote employees (**10.98%**).
- Cincinnati (**12.98%**) and Lexington (**12.56%**) recorded the highest listed city attrition rates.
- Engineering recorded the highest number of attrition instances, with **787** cases.
- Accounting recorded **384** attrition cases, while Human Resources recorded **212**.
- Data Visualization Specialist, Human Resources Analyst II, Research Assistant I, and Business Analyst roles were identified among the higher-attrition job groups.
- Attrition was highest during the first two years of employment and declined as tenure increased.
- Employees with 11+ years of tenure showed minimal attrition in the analysis.
- Marketing recorded the highest department retention rate at **85.43%**, while Human Resources recorded the lowest at **82.9%**.

## Recommendations

Based on the observed patterns, the project recommends:

1. Strengthening onboarding, training, mentorship, and support during the first two years of employment.
2. Developing targeted retention plans for departments, roles, and locations with higher attrition.
3. Providing clearer career-development and progression opportunities, particularly in higher-attrition roles.
4. Using exit interviews and regular employee surveys to investigate the underlying reasons behind observed attrition patterns.
5. Reviewing successful retention practices in lower-attrition departments such as Marketing and considering whether appropriate practices can be adapted elsewhere.
6. Monitoring workforce attrition regularly so that emerging retention risks can be identified earlier.

## Project Structure

```text
HR-Employee-Attrition-Analysis/
├── README.md
├── Data/
│   └── HR Attrition Dataset.csv
├── SQL/
│   └── CAPSTONE SQL QUERY.sql
├── Excel/
│   └── SQL CAPSTONE PROJECT EXCEL VISUALISATION.xlsx
├── Report/
│   └── Capstone Report SQL.pdf
├── Presentation/
│   └── CAPSTONE PRESENTATION SQL.pptx
└── screenshots/
    └── dashboard.png
```

> The repository structure reflects the intended portfolio organization. Files will be added using the actual project deliverables supplied for this analysis; no synthetic replacement dataset or invented project output is included.

## Tools & Skills

- Microsoft SQL Server / SSMS
- SQL
- Microsoft Excel
- Data Cleaning & Preprocessing
- Exploratory Data Analysis
- Workforce Analytics
- Pivot Tables
- Pivot Charts
- Dashboard Development
- Data Visualization
- Insight Generation
- Business Recommendations

## Conclusion

The analysis highlights clear differences in employee attrition across locations, departments, job roles, and tenure levels. The strongest pattern is the concentration of attrition among employees in their early years of employment, while long-tenured employees show substantially lower turnover.

These findings provide a practical starting point for targeted retention initiatives, while further HR investigation would be required to establish the underlying causes of the observed patterns.

## Analytical Note

The relationships and patterns identified in this project describe associations within the dataset. They should not be interpreted as proof of causation without additional HR information, employee feedback, and further investigation.
