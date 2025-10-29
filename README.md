# UCI Online Retail — Data Cleaning & Quality Assessment

**Goal:** Build an analysis-ready dataset from the UCI Online Retail data by detecting and remediating data quality issues (missing IDs, duplicates, returns, zero/negative prices, extreme outliers), and document the business impact of each decision.

## Highlights 
- **Reproducible SQL pipeline** from raw → deduped → clean with indexes and validation.
- **Quantified impacts** on rows and revenue for each cleaning rule.
- **Business framing:** isolate retail behavior vs. wholesale to improve segmentation and CLV reliability.
- **Documentation-first:** full Data Quality Assessment in `/docs/`.

## Repo structure
sql/ # data_quality_checks.sql, data_cleaning.sql
docs/ # PDF report + figures
data/ # placeholders; see below to fetch data
outputs/ # summary XLSX and sample cleaned CSV


## Data access
This project uses the public **UCI Online Retail** dataset (Dec 2010–Dec 2011). 
Download can be found at `data/raw/Online Retail.xlsx`.

## Citation
Chen, D. (2015). Online Retail [Dataset]. UCI Machine Learning Repository. https://doi.org/10.24432/C5BW33.
