-- ==========================
-- CREATE CLEANED DATA TABLE
-- ==========================

-- Purpose: Build analysis-ready clean table (retail focus)
-- Input: retail.online_retail_raw / retail.online_retail_raw_deduped
-- Output: retail.online_retail_clean
-- Engine: PostgreSQL 14+

DROP TABLE IF EXISTS retail.online_retail_clean CASCADE;

CREATE TABLE retail.online_retail_clean AS
SELECT 
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    (quantity * unit_price) as total_price,
    DATE_TRUNC('month', invoice_date) as invoice_month,
    EXTRACT(DOW FROM invoice_date) as day_of_week,
    EXTRACT(HOUR FROM invoice_date) as hour_of_day
FROM retail.online_retail_raw_deduped      	-- Remove duplicates
WHERE 
    customer_id IS NOT NULL                    -- Remove missing customers
    AND invoice_no NOT LIKE 'C%'               -- Remove cancellations
    AND quantity > 0                           -- Remove returns/negatives
    AND unit_price > 0                         -- Remove zero/negative prices
    AND (quantity * unit_price) <= (           -- Remove top 1% outliers
        SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY quantity * unit_price)
        FROM retail.online_retail_raw_deduped
    );


-- Updated Table Taking 1% Outliers From Filtered Table (new version)

DROP TABLE IF EXISTS retail.online_retail_clean CASCADE;

CREATE TABLE retail.online_retail_clean AS
WITH filtered AS (
    SELECT 
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country,
        (quantity * unit_price) AS total_price,
        DATE_TRUNC('month', invoice_date) AS invoice_month,
        EXTRACT(DOW FROM invoice_date) AS day_of_week,
        EXTRACT(HOUR FROM invoice_date) AS hour_of_day
    FROM retail.online_retail_raw_deduped             -- Remove duplicates
    WHERE 
        customer_id IS NOT NULL                       -- Remove missing customers
        AND invoice_no NOT LIKE 'C%'                  -- Remove cancellations
        AND quantity > 0                              -- Remove returns/negatives
        AND unit_price > 0                            -- Remove zero/negative prices
),
cutoff AS (
    SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_price) AS p99_total_price
    FROM filtered
)
SELECT f.*
FROM filtered f
CROSS JOIN cutoff c
WHERE f.total_price <= c.p99_total_price;            -- Remove top 1% outliers


-- Create indexes for performance
CREATE INDEX idx_clean_customer ON retail.online_retail_clean2(customer_id);
CREATE INDEX idx_clean_date ON retail.online_retail_clean2(invoice_date);
CREATE INDEX idx_clean_invoice ON retail.online_retail_clean2(invoice_no);

-- Verify cleaned data
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT customer_id) as unique_customers,
    MIN(invoice_date) as start_date,
    MAX(invoice_date) as end_date,
    ROUND(SUM(total_price), 2) as total_revenue
FROM retail.online_retail_clean2;

-- Average transaction for RAW data (with customer_id only)
SELECT 
    ROUND(AVG(quantity * unit_price), 2) as avg_transaction_raw
FROM retail.online_retail_raw
WHERE customer_id IS NOT NULL;

-- Average transaction for CLEAN data
SELECT 
    ROUND(AVG(total_price), 2) as avg_transaction_clean
FROM retail.online_retail_clean2;

-- Breakdown of what caused revenue loss
SELECT 
    'Missing Customer ID' as removal_reason,
    COUNT(*) as records,
    ROUND(SUM(quantity * unit_price), 2) as revenue_removed,
    ROUND((SUM(quantity * unit_price) / 9747747 * 100), 2) as pct_of_total_revenue
FROM retail.online_retail_raw
WHERE customer_id IS NULL

UNION ALL

SELECT 
    'Cancelled Orders',
    COUNT(*),
    ROUND(SUM(quantity * unit_price), 2),
    ROUND((SUM(quantity * unit_price) / 9747747 * 100), 2)
FROM retail.online_retail_raw
WHERE customer_id IS NOT NULL
  AND invoice_no LIKE 'C%'

UNION ALL

SELECT 
    'Negative Quantities',
    COUNT(*),
    ROUND(SUM(quantity * unit_price), 2),
    ROUND((SUM(quantity * unit_price) / 9747747 * 100), 2)
FROM retail.online_retail_raw
WHERE customer_id IS NOT NULL
  AND invoice_no NOT LIKE 'C%'
  AND quantity <= 0

UNION ALL

SELECT 
    'Top 1% Outliers',
    COUNT(*),
    ROUND(SUM(quantity * unit_price), 2),
    ROUND((SUM(quantity * unit_price) / 9747747 * 100), 2)
FROM retail.online_retail_raw
WHERE customer_id IS NOT NULL
  AND invoice_no NOT LIKE 'C%'
  AND quantity > 0
  AND unit_price > 0
  AND (quantity * unit_price) > (
      SELECT PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY quantity * unit_price)
      FROM retail.online_retail_raw_deduped
      WHERE customer_id IS NOT NULL
        AND invoice_no NOT LIKE 'C%'
        AND quantity > 0
        AND unit_price > 0
  );
