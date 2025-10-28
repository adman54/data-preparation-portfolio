-- 02_cleaning_pipeline.sql
-- Purpose: Main data cleaning and transformation pipeline
-- Author: Data Portfolio Project
-- Date: 2024

-- ============================================
-- STEP 1: Create staging table with proper data types
-- ============================================

DROP TABLE IF EXISTS staging_sales_data;

CREATE TABLE staging_sales_data AS
WITH 
-- ============================================
-- CTE 1: Clean and parse amount values
-- ============================================
amount_cleaned AS (
    SELECT 
        *,
        -- Remove currency symbols and clean amount
        CAST(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            REGEXP_REPLACE(amount, '[$€£¥]', ''), -- Remove currency symbols
                            ',', ''),                               -- Remove commas
                        '^\((.*)\)$', '-\1'),                      -- Convert (123) to -123
                    '^\s+|\s+$', ''),                              -- Trim spaces
                '([0-9]+),([0-9]+)', '\1.\2')                     -- Fix European decimal notation
            AS DECIMAL(10,2)
        ) as amount_numeric,
        
        -- Identify currency from symbols or currency column
        CASE 
            WHEN amount LIKE '$%' THEN 'USD'
            WHEN amount LIKE '€%' THEN 'EUR'
            WHEN amount LIKE '£%' THEN 'GBP'
            WHEN amount LIKE '¥%' THEN 'JPY'
            WHEN currency IS NOT NULL AND currency != '' THEN UPPER(currency)
            ELSE 'USD'  -- Default to USD if no currency identified
        END as currency_detected
    FROM raw_sales_data
),

-- ============================================
-- CTE 2: Standardize dates to YYYY-MM-DD format
-- ============================================
dates_standardized AS (
    SELECT 
        *,
        CASE 
            -- Handle MM/DD/YYYY format
            WHEN order_date ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN 
                TO_DATE(order_date, 'MM/DD/YYYY')
            
            -- Handle DD-MM-YYYY format
            WHEN order_date ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN 
                TO_DATE(order_date, 'DD-MM-YYYY')
            
            -- Handle YYYY/MM/DD format
            WHEN order_date ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}$' THEN 
                TO_DATE(order_date, 'YYYY/MM/DD')
            
            -- Handle YYYY-MM-DD format (already standard)
            WHEN order_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 
                TO_DATE(order_date, 'YYYY-MM-DD')
            
            -- Handle DD/MM/YYYY format (assuming non-US format for dates like 31/03/2024)
            WHEN order_date ~ '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' AND 
                 CAST(SPLIT_PART(order_date, '/', 1) AS INTEGER) > 12 THEN
                TO_DATE(order_date, 'DD/MM/YYYY')
            
            ELSE NULL
        END as order_date_clean
    FROM amount_cleaned
),

-- ============================================
-- CTE 3: Convert all amounts to USD
-- ============================================
currency_converted AS (
    SELECT 
        *,
        -- Using approximate exchange rates (as of March 2024)
        -- In production, this would come from a rates table
        CASE currency_detected
            WHEN 'USD' THEN amount_numeric
            WHEN 'EUR' THEN amount_numeric * 1.08  -- 1 EUR = 1.08 USD
            WHEN 'GBP' THEN amount_numeric * 1.26  -- 1 GBP = 1.26 USD
            WHEN 'JPY' THEN amount_numeric * 0.0067 -- 1 JPY = 0.0067 USD
            WHEN 'CAD' THEN amount_numeric * 0.74  -- 1 CAD = 0.74 USD
            ELSE amount_numeric  -- Default to no conversion
        END as amount_usd
    FROM dates_standardized
),

-- ============================================
-- CTE 4: Clean email addresses
-- ============================================
emails_cleaned AS (
    SELECT 
        *,
        CASE 
            -- Handle NULL or 'NULL' string
            WHEN customer_email IS NULL OR customer_email = 'NULL' OR customer_email = '' THEN
                CONCAT('customer_', customer_id, '@inferred.com')
            
            -- Add .com to incomplete emails
            WHEN customer_email LIKE '%@gmail' THEN CONCAT(customer_email, '.com')
            WHEN customer_email LIKE '%@yahoo' THEN CONCAT(customer_email, '.com')
            WHEN customer_email LIKE '%@hotmail' THEN CONCAT(customer_email, '.com')
            WHEN customer_email LIKE '%@outlook' THEN CONCAT(customer_email, '.com')
            
            -- Handle emails ending with @
            WHEN customer_email LIKE '%@' THEN CONCAT(customer_email, 'domain.com')
            
            -- Handle missing domain extension
            WHEN customer_email NOT LIKE '%@%.%' AND customer_email LIKE '%@%' THEN 
                CONCAT(customer_email, '.com')
            
            -- Keep valid emails as is
            ELSE LOWER(customer_email)
        END as email_clean
    FROM currency_converted
),

-- ============================================
-- CTE 5: Standardize country names
-- ============================================
countries_standardized AS (
    SELECT 
        *,
        CASE UPPER(TRIM(ship_country))
            WHEN 'USA' THEN 'United States'
            WHEN 'US' THEN 'United States'
            WHEN 'U.S.' THEN 'United States'
            WHEN 'U.S.A.' THEN 'United States'
            WHEN 'UNITED STATES' THEN 'United States'
            WHEN 'UNITED STATES OF AMERICA' THEN 'United States'
            WHEN 'AMERICA' THEN 'United States'
            
            WHEN 'UK' THEN 'United Kingdom'
            WHEN 'ENGLAND' THEN 'United Kingdom'
            WHEN 'SCOTLAND' THEN 'United Kingdom'
            WHEN 'UNITED KINGDOM' THEN 'United Kingdom'
            
            WHEN 'CA' THEN 'Canada'
            WHEN 'CANADA' THEN 'Canada'
            
            WHEN 'DE' THEN 'Germany'
            WHEN 'DEUTSCHLAND' THEN 'Germany'
            WHEN 'GERMANY' THEN 'Germany'
            
            WHEN 'FR' THEN 'France'
            WHEN 'FRANCE' THEN 'France'
            
            WHEN 'ES' THEN 'Spain'
            WHEN 'ESPANA' THEN 'Spain'
            WHEN 'SPAIN' THEN 'Spain'
            
            WHEN 'IT' THEN 'Italy'
            WHEN 'ITALY' THEN 'Italy'
            
            WHEN 'NL' THEN 'Netherlands'
            WHEN 'NETHERLANDS' THEN 'Netherlands'
            
            WHEN 'BE' THEN 'Belgium'
            WHEN 'BELGIQUE' THEN 'Belgium'
            WHEN 'BELGIUM' THEN 'Belgium'
            
            WHEN 'AU' THEN 'Australia'
            WHEN 'AUS' THEN 'Australia'
            WHEN 'AUSTRALIA' THEN 'Australia'
            
            WHEN 'JP' THEN 'Japan'
            WHEN 'JAPAN' THEN 'Japan'
            
            WHEN 'KR' THEN 'South Korea'
            WHEN 'SOUTH KOREA' THEN 'South Korea'
            
            WHEN 'IN' THEN 'India'
            WHEN 'INDIA' THEN 'India'
            
            WHEN 'MX' THEN 'Mexico'
            WHEN 'MÉXICO' THEN 'Mexico'
            WHEN 'MEXICO' THEN 'Mexico'
            
            ELSE INITCAP(ship_country)  -- Capitalize properly for other countries
        END as country_clean
    FROM emails_cleaned
),

-- ============================================
-- CTE 6: Clean quantity and category fields
-- ============================================
fields_cleaned AS (
    SELECT 
        *,
        -- Clean quantity: convert negatives to positive, handle outliers
        CASE 
            WHEN quantity IS NULL OR quantity = '' THEN 1
            WHEN CAST(quantity AS INTEGER) <= 0 THEN 1
            WHEN CAST(quantity AS INTEGER) > 100 THEN 1  -- Cap unrealistic quantities
            ELSE CAST(quantity AS INTEGER)
        END as quantity_clean,
        
        -- Standardize category names
        CASE 
            WHEN category IS NULL OR category = '' THEN 'Uncategorized'
            WHEN UPPER(category) = 'HOME' THEN 'Home & Garden'
            WHEN UPPER(category) = 'TOYS & GAMES' THEN 'Toys'
            ELSE category
        END as category_clean
    FROM countries_standardized
),

-- ============================================
-- CTE 7: Remove duplicates (keep first occurrence)
-- ============================================
deduplicated AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY transaction_id 
            ORDER BY 
                CASE WHEN email_clean LIKE '%@%.%' THEN 0 ELSE 1 END,  -- Prefer complete emails
                order_date_clean  -- Then earliest date
        ) as row_num
    FROM fields_cleaned
)

-- ============================================
-- Final SELECT: Create cleaned dataset
-- ============================================
SELECT 
    transaction_id,
    customer_id,
    email_clean as customer_email,
    product_sku,
    quantity_clean as quantity,
    ROUND(amount_usd, 2) as amount_usd,
    currency_detected as original_currency,
    order_date_clean as order_date,
    country_clean as ship_country,
    payment_method,
    category_clean as category,
    -- Add data quality flags for transparency
    CASE 
        WHEN customer_email IS NULL OR customer_email = 'NULL' THEN 'Y' 
        ELSE 'N' 
    END as email_was_inferred,
    CASE 
        WHEN quantity != quantity_clean::VARCHAR THEN 'Y' 
        ELSE 'N' 
    END as quantity_was_adjusted,
    CASE 
        WHEN row_num > 1 THEN 'Y' 
        ELSE 'N' 
    END as is_duplicate
FROM deduplicated
WHERE row_num = 1;  -- Keep only first occurrence of duplicates

-- ============================================
-- Create final cleaned table
-- ============================================

DROP TABLE IF EXISTS cleaned_sales_data;

CREATE TABLE cleaned_sales_data AS
SELECT 
    transaction_id,
    customer_id,
    customer_email,
    product_sku,
    quantity,
    amount_usd,
    original_currency,
    order_date,
    ship_country,
    payment_method,
    category,
    email_was_inferred,
    quantity_was_adjusted
FROM staging_sales_data
WHERE is_duplicate = 'N';

-- ============================================
-- Display cleaning results summary
-- ============================================

WITH cleaning_stats AS (
    SELECT 
        (SELECT COUNT(*) FROM raw_sales_data) as raw_count,
        (SELECT COUNT(*) FROM cleaned_sales_data) as cleaned_count,
        (SELECT COUNT(*) FROM staging_sales_data WHERE is_duplicate = 'Y') as duplicates_removed,
        (SELECT COUNT(*) FROM cleaned_sales_data WHERE email_was_inferred = 'Y') as emails_inferred,
        (SELECT COUNT(*) FROM cleaned_sales_data WHERE quantity_was_adjusted = 'Y') as quantities_adjusted
)
SELECT 
    'Raw Records' as metric,
    raw_count as value
FROM cleaning_stats
UNION ALL
SELECT 'Cleaned Records', cleaned_count FROM cleaning_stats
UNION ALL
SELECT 'Duplicates Removed', duplicates_removed FROM cleaning_stats
UNION ALL
SELECT 'Emails Inferred', emails_inferred FROM cleaning_stats
UNION ALL
SELECT 'Quantities Adjusted', quantities_adjusted FROM cleaning_stats;

-- Comments on cleaning decisions:
-- 1. Currency Conversion: Used fixed exchange rates for demonstration (production would use daily rates table)
-- 2. Missing Emails: Created placeholder emails using customer_id to maintain referential integrity
-- 3. Negative Quantities: Converted to 1 as likely data entry errors
-- 4. Extreme Quantities (>100): Capped at 1 to handle obvious errors (99999)
-- 5. Duplicates: Kept record with most complete email and earliest date
-- 6. Default Currency: Used USD when no currency information available
-- 7. Missing Categories: Labeled as 'Uncategorized' rather than NULL for easier analysis