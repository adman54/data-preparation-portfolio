-- 04_final_transformations.sql
-- Purpose: Final transformations to create analysis-ready datasets
-- Author: Data Portfolio Project
-- Date: 2024

-- ============================================
-- PART 1: Create enriched sales fact table
-- ============================================

DROP TABLE IF EXISTS sales_fact;

CREATE TABLE sales_fact AS
SELECT 
    -- Primary Keys
    transaction_id,
    customer_id,
    product_sku,
    
    -- Date Dimensions
    order_date,
    EXTRACT(YEAR FROM order_date) as order_year,
    EXTRACT(QUARTER FROM order_date) as order_quarter,
    EXTRACT(MONTH FROM order_date) as order_month,
    EXTRACT(WEEK FROM order_date) as order_week,
    TO_CHAR(order_date, 'Month') as order_month_name,
    TO_CHAR(order_date, 'Day') as order_day_name,
    CASE 
        WHEN EXTRACT(DOW FROM order_date) IN (0, 6) THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    
    -- Measures
    quantity,
    amount_usd,
    amount_usd * quantity as total_amount_usd,
    
    -- Dimensions
    customer_email,
    ship_country,
    payment_method,
    category,
    original_currency,
    
    -- Data Quality Indicators
    email_was_inferred,
    quantity_was_adjusted,
    
    -- Derived Metrics
    CASE 
        WHEN amount_usd < 50 THEN 'Small'
        WHEN amount_usd < 250 THEN 'Medium'
        WHEN amount_usd < 1000 THEN 'Large'
        ELSE 'Enterprise'
    END as transaction_size,
    
    CASE 
        WHEN ship_country IN ('United States', 'Canada', 'Mexico') THEN 'North America'
        WHEN ship_country IN ('United Kingdom', 'Germany', 'France', 'Spain', 'Italy', 
                              'Netherlands', 'Belgium') THEN 'Europe'
        WHEN ship_country IN ('Japan', 'South Korea', 'India') THEN 'Asia'
        WHEN ship_country = 'Australia' THEN 'Oceania'
        ELSE 'Other'
    END as region,
    
    -- Add processing timestamp
    CURRENT_TIMESTAMP as processed_at
    
FROM cleaned_sales_data;

-- ============================================
-- PART 2: Create customer summary table
-- ============================================

DROP TABLE IF EXISTS customer_summary;

CREATE TABLE customer_summary AS
SELECT 
    customer_id,
    MIN(customer_email) as customer_email,  -- In case of variations
    COUNT(DISTINCT transaction_id) as total_transactions,
    COUNT(DISTINCT product_sku) as unique_products_purchased,
    COUNT(DISTINCT category) as unique_categories_purchased,
    SUM(quantity) as total_items_purchased,
    ROUND(SUM(amount_usd), 2) as total_spent_usd,
    ROUND(AVG(amount_usd), 2) as avg_transaction_value,
    MIN(order_date) as first_purchase_date,
    MAX(order_date) as last_purchase_date,
    MAX(order_date) - MIN(order_date) as customer_lifetime_days,
    MODE() WITHIN GROUP (ORDER BY ship_country) as primary_shipping_country,
    MODE() WITHIN GROUP (ORDER BY payment_method) as preferred_payment_method,
    
    -- Customer segmentation
    CASE 
        WHEN COUNT(DISTINCT transaction_id) = 1 THEN 'One-time'
        WHEN COUNT(DISTINCT transaction_id) BETWEEN 2 AND 3 THEN 'Occasional'
        WHEN COUNT(DISTINCT transaction_id) BETWEEN 4 AND 6 THEN 'Regular'
        ELSE 'Frequent'
    END as customer_segment,
    
    -- RFM components (Recency, Frequency, Monetary)
    CURRENT_DATE - MAX(order_date) as days_since_last_purchase,
    COUNT(DISTINCT transaction_id) as purchase_frequency,
    NTILE(5) OVER (ORDER BY SUM(amount_usd)) as monetary_quintile
    
FROM cleaned_sales_data
GROUP BY customer_id;

-- ============================================
-- PART 3: Create product performance table
-- ============================================

DROP TABLE IF EXISTS product_performance;

CREATE TABLE product_performance AS
SELECT 
    product_sku,
    category,
    COUNT(DISTINCT transaction_id) as times_ordered,
    COUNT(DISTINCT customer_id) as unique_customers,
    SUM(quantity) as total_quantity_sold,
    ROUND(SUM(amount_usd), 2) as total_revenue_usd,
    ROUND(AVG(amount_usd), 2) as avg_selling_price,
    MIN(amount_usd) as min_selling_price,
    MAX(amount_usd) as max_selling_price,
    STDDEV(amount_usd) as price_volatility,
    
    -- Ranking metrics
    RANK() OVER (ORDER BY SUM(amount_usd) DESC) as revenue_rank,
    RANK() OVER (ORDER BY COUNT(DISTINCT transaction_id) DESC) as popularity_rank,
    
    -- Performance indicators
    CASE 
        WHEN SUM(amount_usd) > (SELECT AVG(total) FROM 
            (SELECT SUM(amount_usd) as total FROM cleaned_sales_data GROUP BY product_sku) t)
        THEN 'Above Average'
        ELSE 'Below Average'
    END as performance_category
    
FROM cleaned_sales_data
GROUP BY product_sku, category;

-- ============================================
-- PART 4: Create daily sales aggregation
-- ============================================

DROP TABLE IF EXISTS daily_sales_summary;

CREATE TABLE daily_sales_summary AS
SELECT 
    order_date,
    TO_CHAR(order_date, 'Day') as day_name,
    COUNT(DISTINCT transaction_id) as num_transactions,
    COUNT(DISTINCT customer_id) as unique_customers,
    SUM(quantity) as items_sold,
    ROUND(SUM(amount_usd), 2) as daily_revenue_usd,
    ROUND(AVG(amount_usd), 2) as avg_transaction_value,
    
    -- Running totals
    SUM(SUM(amount_usd)) OVER (ORDER BY order_date) as cumulative_revenue,
    
    -- Moving averages (7-day)
    ROUND(AVG(SUM(amount_usd)) OVER (
        ORDER BY order_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) as moving_avg_7day_revenue,
    
    -- Day-over-day growth
    LAG(SUM(amount_usd), 1) OVER (ORDER BY order_date) as previous_day_revenue,
    ROUND(
        ((SUM(amount_usd) - LAG(SUM(amount_usd), 1) OVER (ORDER BY order_date)) / 
         NULLIF(LAG(SUM(amount_usd), 1) OVER (ORDER BY order_date), 0)) * 100,
        2
    ) as day_over_day_growth_pct
    
FROM cleaned_sales_data
GROUP BY order_date;

-- ============================================
-- PART 5: Create data quality metrics table
-- ============================================

DROP TABLE IF EXISTS data_quality_metrics;

CREATE TABLE data_quality_metrics AS
WITH raw_metrics AS (
    SELECT 
        COUNT(*) as raw_record_count,
        COUNT(DISTINCT transaction_id) as raw_unique_transactions,
        COUNT(CASE WHEN customer_email IS NULL OR customer_email = 'NULL' THEN 1 END) as raw_missing_emails,
        COUNT(CASE WHEN currency IS NULL OR currency = '' THEN 1 END) as raw_missing_currency
    FROM raw_sales_data
),
cleaned_metrics AS (
    SELECT 
        COUNT(*) as cleaned_record_count,
        COUNT(DISTINCT transaction_id) as cleaned_unique_transactions,
        COUNT(CASE WHEN email_was_inferred = 'Y' THEN 1 END) as inferred_emails,
        COUNT(CASE WHEN quantity_was_adjusted = 'Y' THEN 1 END) as adjusted_quantities
    FROM cleaned_sales_data
)
SELECT 
    'Records Processed' as metric,
    raw_record_count as before_cleaning,
    cleaned_record_count as after_cleaning,
    raw_record_count - cleaned_record_count as difference,
    ROUND(((raw_record_count - cleaned_record_count)::NUMERIC / raw_record_count) * 100, 2) as change_pct
FROM raw_metrics, cleaned_metrics

UNION ALL

SELECT 
    'Unique Transactions',
    raw_unique_transactions,
    cleaned_unique_transactions,
    raw_unique_transactions - cleaned_unique_transactions,
    0
FROM raw_metrics, cleaned_metrics

UNION ALL

SELECT 
    'Missing Emails',
    raw_missing_emails,
    inferred_emails,
    raw_missing_emails - inferred_emails,
    ROUND(((raw_missing_emails - inferred_emails)::NUMERIC / NULLIF(raw_missing_emails, 0)) * 100, 2)
FROM raw_metrics, cleaned_metrics

UNION ALL

SELECT 
    'Data Completeness %',
    ROUND(((raw_record_count - raw_missing_emails - raw_missing_currency)::NUMERIC / raw_record_count) * 100, 2),
    ROUND(((cleaned_record_count)::NUMERIC / cleaned_record_count) * 100, 2),
    ROUND(((cleaned_record_count)::NUMERIC / cleaned_record_count) * 100, 2) - 
    ROUND(((raw_record_count - raw_missing_emails - raw_missing_currency)::NUMERIC / raw_record_count) * 100, 2),
    0
FROM raw_metrics, cleaned_metrics;

-- ============================================
-- PART 6: Generate executive summary
-- ============================================

SELECT '===== DATA PREPARATION PROJECT SUMMARY =====' as report;

-- Key Statistics
SELECT 
    CONCAT('Total Transactions Processed: ', COUNT(DISTINCT transaction_id)) as metric,
    CONCAT('Date Range: ', MIN(order_date), ' to ', MAX(order_date)) as value
FROM sales_fact
UNION ALL
SELECT 
    'Total Revenue (USD): ',
    CONCAT('$', TO_CHAR(SUM(amount_usd), '999,999,999.99'))
FROM sales_fact
UNION ALL
SELECT 
    'Unique Customers: ',
    CAST(COUNT(DISTINCT customer_id) AS VARCHAR)
FROM sales_fact
UNION ALL
SELECT 
    'Unique Products: ',
    CAST(COUNT(DISTINCT product_sku) AS VARCHAR)
FROM sales_fact
UNION ALL
SELECT 
    'Countries Served: ',
    CAST(COUNT(DISTINCT ship_country) AS VARCHAR)
FROM sales_fact;

-- Top Insights
SELECT '===== TOP INSIGHTS =====' as report;

WITH top_customer AS (
    SELECT customer_id, SUM(amount_usd) as total_spent
    FROM sales_fact
    GROUP BY customer_id
    ORDER BY total_spent DESC
    LIMIT 1
),
top_product AS (
    SELECT product_sku, SUM(amount_usd) as total_revenue
    FROM sales_fact
    GROUP BY product_sku
    ORDER BY total_revenue DESC
    LIMIT 1
),
top_country AS (
    SELECT ship_country, SUM(amount_usd) as total_revenue
    FROM sales_fact
    GROUP BY ship_country
    ORDER BY total_revenue DESC
    LIMIT 1
)
SELECT 
    'Top Customer: ' as metric,
    CONCAT(customer_id, ' ($', ROUND(total_spent, 2), ')') as value
FROM top_customer
UNION ALL
SELECT 
    'Top Product: ',
    CONCAT(product_sku, ' ($', ROUND(total_revenue, 2), ')')
FROM top_product
UNION ALL
SELECT 
    'Top Market: ',
    CONCAT(ship_country, ' ($', ROUND(total_revenue, 2), ')')
FROM top_country;

-- Data Quality Improvements
SELECT '===== DATA QUALITY IMPROVEMENTS =====' as report;

SELECT 
    metric,
    CONCAT('Before: ', before_cleaning, ' | After: ', after_cleaning, ' | Improvement: ', 
           CASE WHEN change_pct > 0 THEN '+' ELSE '' END, change_pct, '%') as details
FROM data_quality_metrics;

-- Success message
SELECT '===== CLEANING PROCESS COMPLETE =====' as status,
       'All data has been successfully cleaned, validated, and transformed for analysis.' as message;

-- Export instructions comment
-- To export the cleaned data:
-- COPY cleaned_sales_data TO '/path/to/cleaned_sales_data.csv' WITH CSV HEADER;
-- COPY sales_fact TO '/path/to/sales_fact.csv' WITH CSV HEADER;
-- COPY customer_summary TO '/path/to/customer_summary.csv' WITH CSV HEADER;
-- COPY product_performance TO '/path/to/product_performance.csv' WITH CSV HEADER;