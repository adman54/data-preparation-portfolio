-- 01_initial_exploration.sql
-- Purpose: Initial exploration to identify data quality issues
-- Author: Data Portfolio Project
-- Date: 2024

-- Create table for raw data import
CREATE TABLE IF NOT EXISTS raw_sales_data (
    transaction_id VARCHAR(50),
    customer_id VARCHAR(50),
    customer_email VARCHAR(100),
    product_sku VARCHAR(50),
    quantity VARCHAR(50),  -- Stored as VARCHAR due to inconsistent formats
    amount VARCHAR(50),    -- Stored as VARCHAR due to currency symbols and commas
    currency VARCHAR(10),
    order_date VARCHAR(50), -- Various date formats
    ship_country VARCHAR(100),
    payment_method VARCHAR(50),
    category VARCHAR(50)
);

-- ============================================
-- STEP 1: Basic Data Profiling
-- ============================================

-- Check total record count
SELECT COUNT(*) as total_records
FROM raw_sales_data;

-- Check for complete duplicates
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT transaction_id) as unique_transactions,
    COUNT(*) - COUNT(DISTINCT transaction_id) as duplicate_count
FROM raw_sales_data;

-- ============================================
-- STEP 2: Identify Missing Values
-- ============================================

SELECT 
    'customer_email' as column_name,
    COUNT(*) as total_records,
    COUNT(customer_email) as non_null_records,
    COUNT(*) - COUNT(customer_email) as null_records,
    ROUND(((COUNT(*) - COUNT(customer_email))::NUMERIC / COUNT(*)) * 100, 2) as null_percentage
FROM raw_sales_data
UNION ALL
SELECT 
    'currency' as column_name,
    COUNT(*) as total_records,
    COUNT(currency) as non_null_records,
    COUNT(*) - COUNT(currency) as null_records,
    ROUND(((COUNT(*) - COUNT(currency))::NUMERIC / COUNT(*)) * 100, 2) as null_percentage
FROM raw_sales_data
UNION ALL
SELECT 
    'category' as column_name,
    COUNT(*) as total_records,
    COUNT(category) as non_null_records,
    COUNT(*) - COUNT(category) as null_records,
    ROUND(((COUNT(*) - COUNT(category))::NUMERIC / COUNT(*)) * 100, 2) as null_percentage
FROM raw_sales_data
ORDER BY null_percentage DESC;

-- ============================================
-- STEP 3: Analyze Data Format Issues
-- ============================================

-- Check date format variations
SELECT 
    order_date,
    COUNT(*) as occurrences,
    CASE 
        WHEN order_date ~ '^\d{2}/\d{2}/\d{4}$' THEN 'MM/DD/YYYY'
        WHEN order_date ~ '^\d{2}-\d{2}-\d{4}$' THEN 'DD-MM-YYYY'
        WHEN order_date ~ '^\d{4}/\d{2}/\d{2}$' THEN 'YYYY/MM/DD'
        WHEN order_date ~ '^\d{4}-\d{2}-\d{2}$' THEN 'YYYY-MM-DD'
        ELSE 'OTHER'
    END as date_format
FROM raw_sales_data
GROUP BY order_date
ORDER BY occurrences DESC
LIMIT 10;

-- Check currency variations
SELECT 
    currency,
    COUNT(*) as count
FROM raw_sales_data
GROUP BY currency
ORDER BY count DESC;

-- Check amount format issues (currency symbols, commas, parentheses for negatives)
SELECT 
    amount,
    CASE
        WHEN amount LIKE '$%' THEN 'USD Symbol'
        WHEN amount LIKE '€%' THEN 'EUR Symbol'
        WHEN amount LIKE '£%' THEN 'GBP Symbol'
        WHEN amount LIKE '¥%' THEN 'JPY Symbol'
        WHEN amount LIKE '%,%' THEN 'Contains Comma'
        WHEN amount LIKE '(%' THEN 'Negative (Parentheses)'
        WHEN amount ~ '^[0-9.]+$' THEN 'Clean Numeric'
        ELSE 'Other Format'
    END as amount_format,
    COUNT(*) as occurrences
FROM raw_sales_data
GROUP BY amount, amount_format
ORDER BY occurrences DESC
LIMIT 15;

-- ============================================
-- STEP 4: Check Country Name Variations
-- ============================================

SELECT 
    UPPER(ship_country) as country_upper,
    COUNT(*) as count,
    STRING_AGG(DISTINCT ship_country, ', ') as variations
FROM raw_sales_data
GROUP BY UPPER(ship_country)
HAVING COUNT(DISTINCT ship_country) > 1
ORDER BY count DESC;

-- ============================================
-- STEP 5: Identify Duplicate Transactions
-- ============================================

WITH duplicate_analysis AS (
    SELECT 
        transaction_id,
        COUNT(*) as duplicate_count,
        STRING_AGG(DISTINCT customer_email, ', ') as email_variations,
        STRING_AGG(DISTINCT amount, ', ') as amount_variations,
        STRING_AGG(DISTINCT order_date, ', ') as date_variations
    FROM raw_sales_data
    GROUP BY transaction_id
    HAVING COUNT(*) > 1
)
SELECT * FROM duplicate_analysis
ORDER BY duplicate_count DESC;

-- ============================================
-- STEP 6: Identify Data Anomalies
-- ============================================

-- Check for suspicious quantity values
SELECT 
    quantity,
    COUNT(*) as occurrences
FROM raw_sales_data
WHERE quantity::VARCHAR IN ('0', '-1', '-2', '-5', '999', '99999')
   OR quantity NOT ~ '^[0-9]+$'
GROUP BY quantity
ORDER BY occurrences DESC;

-- Check for suspicious email formats
SELECT 
    customer_email,
    CASE
        WHEN customer_email IS NULL THEN 'NULL'
        WHEN customer_email NOT LIKE '%@%' THEN 'Missing @'
        WHEN customer_email NOT LIKE '%@%.%' THEN 'Invalid Domain'
        WHEN customer_email LIKE '%@' THEN 'Ends with @'
        WHEN customer_email NOT LIKE '%@%.%' THEN 'Missing Domain Extension'
        ELSE 'Valid Format'
    END as email_issue
FROM raw_sales_data
WHERE customer_email IS NULL 
   OR customer_email NOT LIKE '%@%.%'
   OR customer_email LIKE '%@'
LIMIT 20;

-- ============================================
-- STEP 7: Summary Statistics
-- ============================================

-- Create a data quality summary
WITH quality_metrics AS (
    SELECT 
        COUNT(*) as total_records,
        COUNT(DISTINCT transaction_id) as unique_transactions,
        COUNT(CASE WHEN customer_email IS NULL OR customer_email = 'NULL' THEN 1 END) as missing_emails,
        COUNT(CASE WHEN currency IS NULL OR currency = '' THEN 1 END) as missing_currency,
        COUNT(CASE WHEN category IS NULL OR category = '' THEN 1 END) as missing_category,
        COUNT(CASE WHEN quantity ~ '^[0-9]+$' AND CAST(quantity AS INTEGER) < 0 THEN 1 END) as negative_quantities,
        COUNT(CASE WHEN quantity = '0' THEN 1 END) as zero_quantities
    FROM raw_sales_data
)
SELECT 
    'Total Records' as metric,
    total_records as value
FROM quality_metrics
UNION ALL
SELECT 'Unique Transactions', unique_transactions FROM quality_metrics
UNION ALL
SELECT 'Duplicate Records', total_records - unique_transactions FROM quality_metrics
UNION ALL
SELECT 'Missing Emails', missing_emails FROM quality_metrics
UNION ALL
SELECT 'Missing Currency', missing_currency FROM quality_metrics
UNION ALL
SELECT 'Missing Category', missing_category FROM quality_metrics
UNION ALL
SELECT 'Negative Quantities', negative_quantities FROM quality_metrics
UNION ALL
SELECT 'Zero Quantities', zero_quantities FROM quality_metrics;

-- Comments on findings:
-- 1. ~15% of records are duplicates based on transaction_id
-- 2. ~30% of email addresses are missing or malformed
-- 3. Multiple date formats present: MM/DD/YYYY, DD-MM-YYYY, YYYY/MM/DD
-- 4. Currency recorded in symbols ($ € £ ¥) and codes (USD, EUR, GBP, JPY)
-- 5. Amounts contain commas, currency symbols, and parentheses for negatives
-- 6. Country names have multiple variations (USA, US, United States, etc.)
-- 7. Some quantities are negative or unrealistically large (99999)