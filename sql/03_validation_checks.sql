-- 03_validation_checks.sql
-- Purpose: Validate data quality after cleaning process
-- Author: Data Portfolio Project
-- Date: 2024

-- ============================================
-- VALIDATION TEST 1: Check for NULL values in critical fields
-- ============================================

SELECT 
    'NULL Check' as test_name,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASSED ✓'
        ELSE CONCAT('FAILED ✗ - Found ', COUNT(*), ' records with NULL values')
    END as test_result
FROM cleaned_sales_data
WHERE transaction_id IS NULL 
   OR customer_id IS NULL 
   OR customer_email IS NULL 
   OR order_date IS NULL 
   OR amount_usd IS NULL;

-- ============================================
-- VALIDATION TEST 2: Verify no duplicate transaction_ids
-- ============================================

SELECT 
    'Duplicate Check' as test_name,
    CASE 
        WHEN MAX(count) = 1 THEN 'PASSED ✓'
        ELSE CONCAT('FAILED ✗ - Found ', SUM(CASE WHEN count > 1 THEN 1 ELSE 0 END), ' duplicate transaction IDs')
    END as test_result
FROM (
    SELECT transaction_id, COUNT(*) as count
    FROM cleaned_sales_data
    GROUP BY transaction_id
) t;

-- ============================================
-- VALIDATION TEST 3: Validate email format
-- ============================================

SELECT 
    'Email Format Check' as test_name,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASSED ✓'
        ELSE CONCAT('FAILED ✗ - Found ', COUNT(*), ' invalid email formats')
    END as test_result
FROM cleaned_sales_data
WHERE customer_email NOT LIKE '%@%.%'
   OR customer_email LIKE '%@'
   OR customer_email LIKE '@%'
   OR LENGTH(customer_email) < 5;

-- ============================================
-- VALIDATION TEST 4: Verify dates are within reasonable range
-- ============================================

SELECT 
    'Date Range Check' as test_name,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASSED ✓'
        ELSE CONCAT('FAILED ✗ - Found ', COUNT(*), ' dates outside valid range')
    END as test_result
FROM cleaned_sales_data
WHERE order_date < '2024-01-01'::DATE 
   OR order_date > '2024-12-31'::DATE;

-- ============================================
-- VALIDATION TEST 5: Check for negative or zero amounts
-- ============================================

SELECT 
    'Amount Validation' as test_name,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASSED ✓'
        ELSE CONCAT('FAILED ✗ - Found ', COUNT(*), ' records with invalid amounts')
    END as test_result
FROM cleaned_sales_data
WHERE amount_usd <= 0 
   OR amount_usd > 100000;  -- Assuming no single transaction > $100k

-- ============================================
-- VALIDATION TEST 6: Verify quantity values are positive
-- ============================================

SELECT 
    'Quantity Check' as test_name,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASSED ✓'
        ELSE CONCAT('FAILED ✗ - Found ', COUNT(*), ' records with invalid quantities')
    END as test_result
FROM cleaned_sales_data
WHERE quantity <= 0 
   OR quantity > 100;

-- ============================================
-- VALIDATION TEST 7: Check country standardization
-- ============================================

WITH country_check AS (
    SELECT 
        ship_country,
        COUNT(*) as count
    FROM cleaned_sales_data
    WHERE ship_country IN (
        'United States', 'United Kingdom', 'Canada', 'Germany', 
        'France', 'Spain', 'Italy', 'Netherlands', 'Belgium', 
        'Australia', 'Japan', 'South Korea', 'India', 'Mexico'
    )
    GROUP BY ship_country
)
SELECT 
    'Country Standardization' as test_name,
    CASE 
        WHEN COUNT(DISTINCT ship_country) <= 20 THEN 'PASSED ✓'
        ELSE CONCAT('WARNING - ', COUNT(DISTINCT ship_country), ' unique country values (expected ~15)')
    END as test_result
FROM cleaned_sales_data;

-- ============================================
-- VALIDATION TEST 8: Currency conversion check
-- ============================================

SELECT 
    'Currency Tracking' as test_name,
    CASE 
        WHEN COUNT(*) = COUNT(original_currency) THEN 'PASSED ✓'
        ELSE CONCAT('WARNING - ', COUNT(*) - COUNT(original_currency), ' records missing original currency')
    END as test_result
FROM cleaned_sales_data;

-- ============================================
-- VALIDATION TEST 9: Data completeness score
-- ============================================

WITH completeness AS (
    SELECT 
        COUNT(*) as total_records,
        SUM(CASE WHEN transaction_id IS NOT NULL THEN 1 ELSE 0 END) as complete_transaction_id,
        SUM(CASE WHEN customer_email IS NOT NULL THEN 1 ELSE 0 END) as complete_email,
        SUM(CASE WHEN category != 'Uncategorized' THEN 1 ELSE 0 END) as complete_category,
        SUM(CASE WHEN email_was_inferred = 'N' THEN 1 ELSE 0 END) as original_emails
    FROM cleaned_sales_data
)
SELECT 
    'Data Completeness Score' as test_name,
    CONCAT(
        ROUND(
            ((complete_transaction_id + complete_email + original_emails)::NUMERIC / 
             (total_records * 3)) * 100, 
            2
        ), 
        '%'
    ) as test_result
FROM completeness;

-- ============================================
-- VALIDATION TEST 10: Statistical outlier check
-- ============================================

WITH stats AS (
    SELECT 
        AVG(amount_usd) as mean_amount,
        STDDEV(amount_usd) as stddev_amount
    FROM cleaned_sales_data
),
outliers AS (
    SELECT COUNT(*) as outlier_count
    FROM cleaned_sales_data
    CROSS JOIN stats
    WHERE amount_usd > (mean_amount + 3 * stddev_amount)
       OR amount_usd < (mean_amount - 3 * stddev_amount)
)
SELECT 
    'Statistical Outliers' as test_name,
    CASE 
        WHEN outlier_count = 0 THEN 'PASSED ✓'
        ELSE CONCAT('INFO - Found ', outlier_count, ' statistical outliers (>3 std dev)')
    END as test_result
FROM outliers;

-- ============================================
-- SUMMARY: Consolidate all validation results
-- ============================================

CREATE TEMPORARY TABLE validation_results AS
WITH all_tests AS (
    -- Test 1: NULL values
    SELECT 1 as test_order, 'Critical Fields NULL Check' as test_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END as status,
        COUNT(*) as issue_count
    FROM cleaned_sales_data
    WHERE transaction_id IS NULL OR customer_id IS NULL OR customer_email IS NULL
    
    UNION ALL
    
    -- Test 2: Duplicates
    SELECT 2, 'Duplicate Transaction IDs',
        CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END,
        COUNT(*)
    FROM (
        SELECT transaction_id FROM cleaned_sales_data
        GROUP BY transaction_id HAVING COUNT(*) > 1
    ) t
    
    UNION ALL
    
    -- Test 3: Email format
    SELECT 3, 'Email Format Validation',
        CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END,
        COUNT(*)
    FROM cleaned_sales_data
    WHERE customer_email NOT LIKE '%@%.%'
    
    UNION ALL
    
    -- Test 4: Amount validation
    SELECT 4, 'Amount Range Validation',
        CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END,
        COUNT(*)
    FROM cleaned_sales_data
    WHERE amount_usd <= 0 OR amount_usd > 100000
    
    UNION ALL
    
    -- Test 5: Quantity validation
    SELECT 5, 'Quantity Validation',
        CASE WHEN COUNT(*) = 0 THEN 'PASSED' ELSE 'FAILED' END,
        COUNT(*)
    FROM cleaned_sales_data
    WHERE quantity <= 0 OR quantity > 100
)
SELECT 
    test_order,
    test_name,
    status,
    issue_count,
    CASE 
        WHEN status = 'PASSED' THEN '✓'
        ELSE '✗'
    END as symbol
FROM all_tests
ORDER BY test_order;

-- Display validation summary
SELECT 
    test_name,
    status,
    CASE 
        WHEN issue_count = 0 THEN 'No issues found'
        ELSE CONCAT(issue_count, ' issues found')
    END as details,
    symbol
FROM validation_results
ORDER BY test_order;

-- Overall validation score
SELECT 
    CONCAT(
        'Overall Validation Score: ',
        ROUND(
            (SUM(CASE WHEN status = 'PASSED' THEN 1 ELSE 0 END)::NUMERIC / COUNT(*)) * 100,
            1
        ),
        '% (',
        SUM(CASE WHEN status = 'PASSED' THEN 1 ELSE 0 END),
        '/',
        COUNT(*),
        ' tests passed)'
    ) as validation_summary
FROM validation_results;