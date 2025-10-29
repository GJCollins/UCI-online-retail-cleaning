-- ===================
-- DATA QUALITY CHECKS
-- ===================

-- Check total records
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT customer_id) as unique_customers,
    COUNT(DISTINCT invoice_no) as unique_invoices,
    COUNT(DISTINCT stock_code) as unique_products
FROM retail.online_retail_raw;

-- Check for missing values
SELECT 
    COUNT(*) as total_rows,
    COUNT(*) - COUNT(invoice_no) as missing_invoice_number,
	COUNT(*) - COUNT(stock_code) as missing_stock_code,
	COUNT(*) - COUNT(description) as missing_description,
	COUNT(*) - COUNT(quantity) as missing_quantity,
	COUNT(*) - COUNT(invoice_date) as missing_invoice_date,
    COUNT(*) - COUNT(unit_price) as missing_price,
	COUNT(*) - COUNT(customer_id) as missing_customer_id,
	COUNT(*) - COUNT(country) as missing_country
FROM retail.online_retail_raw;


-- Check for customer IDs
SELECT 
    COUNT(*) as total_records,
    COUNT(*) - COUNT(customer_id) as missing_customer_id,
    ROUND((COUNT(*) - COUNT(customer_id))::NUMERIC / COUNT(*) * 100, 2) as pct_missing
FROM retail.online_retail_raw;

-- Check for duplicate transactions
SELECT 
    invoice_no,
    stock_code,
    customer_id,
    COUNT(*) as duplicate_count
FROM retail.online_retail_raw
WHERE customer_id IS NOT NULL
GROUP BY invoice_no, stock_code, customer_id
HAVING COUNT(*) > 1;

-- Look at actual duplicate records to understand them
SELECT 
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country
FROM retail.online_retail_raw
WHERE customer_id IS NOT NULL
  AND (invoice_no, stock_code, customer_id) IN (
      SELECT invoice_no, stock_code, customer_id
      FROM retail.online_retail_raw
      WHERE customer_id IS NOT NULL
      GROUP BY invoice_no, stock_code, customer_id
      HAVING COUNT(*) > 1
  )
ORDER BY invoice_no, stock_code, customer_id, invoice_date
LIMIT 50;

-- Find TRUE exact duplicates (every field matches)
WITH duplicate_rows AS (
    SELECT 
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country,
        ROW_NUMBER() OVER (
            PARTITION BY invoice_no, stock_code, customer_id, quantity, 
                         invoice_date, unit_price, description
            ORDER BY invoice_no
        ) as row_num
    FROM retail.online_retail_raw
    WHERE customer_id IS NOT NULL
)
SELECT 
    COUNT(*) as total_exact_duplicates,
    COUNT(DISTINCT invoice_no) as invoices_affected
FROM duplicate_rows
WHERE row_num > 1;

-- Examine financial impact
WITH duplicate_rows AS (
    SELECT 
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country,
        (quantity * unit_price) as line_total,
        ROW_NUMBER() OVER (
            PARTITION BY invoice_no, stock_code, customer_id, quantity, 
                         invoice_date, unit_price, description
            ORDER BY invoice_no
        ) as row_num
    FROM retail.online_retail_raw
    WHERE customer_id IS NOT NULL
),
total_revenue AS (
    SELECT SUM(quantity * unit_price) as total_revenue
    FROM retail.online_retail_raw
    WHERE customer_id IS NOT NULL
)
SELECT 
    COUNT(*) as total_exact_duplicates,
    COUNT(DISTINCT invoice_no) as invoices_affected,
    SUM(line_total) as duplicated_revenue,
    ROUND(SUM(line_total), 2) as duplicated_revenue_formatted,
    (SELECT total_revenue FROM total_revenue) as total_revenue,
    ROUND((SUM(line_total) / (SELECT total_revenue FROM total_revenue) * 100), 2) as pct_revenue_duplicated
FROM duplicate_rows
WHERE row_num > 1;

-- Remove exact duplicates, keep only one copy
CREATE TABLE retail.online_retail_raw_deduped AS
SELECT DISTINCT ON (invoice_no, stock_code, customer_id, quantity, 
                     invoice_date, unit_price, description, country)
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country
FROM retail.online_retail_raw
WHERE customer_id IS NOT NULL
ORDER BY invoice_no, stock_code, customer_id, quantity, 
         invoice_date, unit_price, description, country;

-- Check how many were removed
SELECT 
    (SELECT COUNT(*) FROM retail.online_retail_raw WHERE customer_id IS NOT NULL) as before_dedup,
    (SELECT COUNT(*) FROM retail.online_retail_raw_deduped) as after_dedup,
    (SELECT COUNT(*) FROM retail.online_retail_raw WHERE customer_id IS NOT NULL) - 
    (SELECT COUNT(*) FROM retail.online_retail_raw_deduped) as duplicates_removed;

-- Check for cancelled orders
SELECT 
    COUNT(*) as cancelled_orders,
    ROUND(COUNT(*)::NUMERIC / 
		(SELECT COUNT(*) 
		FROM retail.online_retail_raw_deduped
        WHERE customer_id IS NOT NULL) * 100, 2) as pct_cancelled,
		ROUND(SUM(quantity * unit_price), 2) as total_revenue
FROM retail.online_retail_raw
WHERE customer_id IS NOT NULL
  AND invoice_no LIKE 'C%'; --info found in ICS variables table

-- Check for negative quantities
SELECT 
    COUNT(*) FILTER (WHERE quantity < 0) as negative_quantity,
    MIN(quantity) as min_quantity,
    ROUND(COUNT(*) FILTER (WHERE quantity < 0)::NUMERIC / COUNT(*) * 100, 2) as pct_negative
FROM retail.online_retail_raw_deduped
WHERE customer_id IS NOT NULL
  AND invoice_no NOT LIKE 'C%';

-- Check for negative or zero unit prices
SELECT 
    COUNT(*) FILTER (WHERE unit_price < 0) as invalid_price,
    MIN(unit_price) as min_price,
    MAX(unit_price) as max_price,
    COUNT(*) FILTER (WHERE unit_price = 0) as zero_price
FROM retail.online_retail_raw_deduped
WHERE customer_id IS NOT NULL
  AND invoice_no NOT LIKE 'C%'
  AND quantity > 0;

-- Check outliers
WITH transaction_values AS (
    SELECT 
        quantity * unit_price as total_price
    FROM retail.online_retail_raw_deduped
    WHERE customer_id IS NOT NULL
      AND invoice_no NOT LIKE 'C%'
      AND quantity > 0
      AND unit_price > 0
)
SELECT 
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_price ASC) as median,
	PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_price ASC) as p95,
    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_price ASC) as p99,
    MAX(total_price) as max_value
FROM transaction_values;

-- Remove outliers

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

-- See how many transactions are above £1000, £5000, £10000
SELECT 
    COUNT(*) FILTER (WHERE total_price > 1000) as over_1000,
    COUNT(*) FILTER (WHERE total_price > 5000) as over_5000,
    COUNT(*) FILTER (WHERE total_price > 10000) as over_10000,
    COUNT(*) as total_transactions
FROM (
    SELECT quantity * unit_price as total_price
    FROM retail.online_retail_raw
    WHERE customer_id IS NOT NULL
      AND invoice_no NOT LIKE 'C%'
      AND quantity > 0
      AND unit_price > 0
) AS t;

-- Check date range
SELECT 
    MIN(invoice_date) as earliest_transaction,
    MAX(invoice_date) as latest_transaction,
    EXTRACT(DAY FROM (MAX(invoice_date) - MIN(invoice_date))) as days_covered
FROM retail.online_retail_raw_deduped;

-- Check customer id data consistency
SELECT 
    MIN(customer_id) as min_id,
    MAX(customer_id) as max_id,
    COUNT(DISTINCT customer_id) as unique_customers
FROM retail.online_retail_raw
WHERE customer_id IS NOT NULL;
