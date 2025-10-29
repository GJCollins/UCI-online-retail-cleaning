# UCI Online Retail — Data Cleaning & Quality Assessment

**Goal:** Build an analysis-ready dataset from the UCI Online Retail data by detecting and remediating data quality issues (missing IDs, duplicates, returns, zero/negative prices, extreme outliers), and document the business impact of each decision.

## Highlights 
- **Reproducible SQL pipeline** from raw → deduped → clean with indexes and validation.
- **Quantified impacts** on rows and revenue for each cleaning rule.
- **Business framing:** isolate retail behavior vs. wholesale to improve segmentation and CLV reliability.
- **Documentation-first:** full Data Quality Assessment in `/docs/`.

## Repo structure
- sql/ data_quality_checks.sql, data_cleaning.sql
- docs/ PDF report + figures
- data/ placeholders; see below to fetch data
- outputs/ summary XLSX and sample cleaned CSV

## Data access
This project uses the public **UCI Online Retail** dataset (Dec 2010–Dec 2011). 
Download can be found at `data/raw/Online Retail.xlsx`.

## Citation
Chen, D. (2015). Online Retail [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5BW33.

> I do not commit raw data to the repo. See `data/README.md` for instructions.

## Quick start
1) Create Environment
    -- Create database
CREATE DATABASE customer_segmentation;

2) Load raw data into Postgres (example):
   -- Create schema
CREATE SCHEMA IF NOT EXISTS retail;
If you have issues with COPY command, use pgAdmin's Import tool

3) Run data quality checks:
   \i sql/data_quality_checks.sql

4) Build clean tables
   \i sql/data_cleaning.sql

-- (Use your preferred method to load data/raw/Online Retail.xlsx into retail.online_retail_raw)

## Outputs

outputs/cleaning_summary.xlsx – before/after metrics

outputs/online_retail_clean.csv – cleaned dataset for analysis (retail-focused)

Methods (What was cleaned and why)
  1) Remove rows with missing customer_id (segmentation requires IDs)
  2) Drop exact duplicates across all fields
  3) Exclude cancellations/returns (invoices beginning with C)
  4) Enforce positive quantity and unit_price
  5) Remove extreme outliers using PERCENTILE_CONT(0.99) on line totals
  6) Add convenience fields: total_price, invoice_month, day_of_week, hour_of_day

See /docs/Data_Quality_Assessment_Report.pdf for details and quantified impact.
