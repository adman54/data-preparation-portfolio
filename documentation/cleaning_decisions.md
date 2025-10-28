# Data Cleaning Decisions Documentation

## Overview
This document details the rationale behind each data cleaning decision made in the e-commerce sales data preparation project. Each decision was made to balance data quality, business logic, and analytical requirements.

## 1. Currency Standardization

### Decision
Convert all amounts to USD using fixed exchange rates.

### Rationale
- **Problem**: Revenue was recorded in multiple currencies (USD, EUR, GBP, JPY, CAD) without consistent labeling
- **Impact**: 30% of transactions had non-USD currencies
- **Solution**: Applied conversion rates as of March 2024:
  - EUR to USD: 1.08
  - GBP to USD: 1.26
  - JPY to USD: 0.0067
  - CAD to USD: 0.74

### Alternative Considered
Using historical daily exchange rates - rejected due to complexity for this demonstration project.

### Code Reference
```sql
-- See 02_cleaning_pipeline.sql, lines 85-95
CASE currency_detected
    WHEN 'USD' THEN amount_numeric
    WHEN 'EUR' THEN amount_numeric * 1.08
    -- etc.
END as amount_usd
```

---

## 2. Missing Email Addresses

### Decision
Generate placeholder emails using pattern: `customer_{customer_id}@inferred.com`

### Rationale
- **Problem**: 30% of records had NULL or invalid email addresses
- **Impact**: Would lose customer tracking and segmentation capability
- **Solution**: Created trackable placeholder that:
  - Maintains referential integrity
  - Clearly identifies inferred vs. actual emails
  - Allows for future matching if real emails obtained

### Alternative Considered
Dropping records with missing emails - rejected as it would lose 30% of transaction data.

### Business Impact
Enables complete customer journey tracking while transparently flagging data quality issues.

---

## 3. Duplicate Transaction Handling

### Decision
Keep the first occurrence with the most complete email address.

### Rationale
- **Problem**: 15% of transactions were duplicated due to system errors
- **Pattern Identified**: Duplicates occurred primarily during 2-4 AM maintenance windows
- **Solution Priority**:
  1. Keep record with valid email format
  2. Then keep earliest timestamp
  3. Flag all removed duplicates for audit trail

### Code Reference
```sql
ROW_NUMBER() OVER (
    PARTITION BY transaction_id 
    ORDER BY 
        CASE WHEN email_clean LIKE '%@%.%' THEN 0 ELSE 1 END,
        order_date_clean
) as row_num
```

---

## 4. Negative and Zero Quantities

### Decision
Convert all negative and zero quantities to 1.

### Rationale
- **Problem**: Found quantities of -1, -2, -5, and 0
- **Analysis**: These appear to be data entry errors, not returns
- **Evidence**: Negative quantities had positive payment amounts
- **Solution**: Default to minimum valid quantity (1)

### Alternative Considered
Flagging as returns - rejected because payment data contradicted this interpretation.

---

## 5. Extreme Quantity Values

### Decision
Cap quantities above 100 to 1.

### Rationale
- **Problem**: Found quantities of 999 and 99999
- **Analysis**: Statistical outliers (>3 standard deviations)
- **Context**: Product types and amounts suggested single-item purchases
- **Solution**: Treat as data entry errors, default to 1

### Business Impact
Prevents inventory and demand forecasting distortions.

---

## 6. Date Format Standardization

### Decision
Convert all dates to ISO 8601 format (YYYY-MM-DD).

### Rationale
- **Problem**: Mixed formats: MM/DD/YYYY, DD-MM-YYYY, YYYY/MM/DD
- **Ambiguity**: Dates like 03/04/2024 could be March 4 or April 3
- **Solution Logic**:
  - If day value > 12, assume DD/MM format
  - Otherwise, assume MM/DD format (US standard)
  - Convert all to ISO format for consistency

### Validation
All cleaned dates fall within expected range (2024-03-15 to 2024-04-23).

---

## 7. Country Name Standardization

### Decision
Map all country variations to standard names.

### Rationale
- **Problem**: Same country had multiple representations
  - US, USA, U.S., United States, America → "United States"
  - UK, England, Scotland → "United Kingdom"
- **Solution**: Created comprehensive mapping table
- **Result**: Reduced from 25+ variations to 14 standard countries

### Business Impact
Enables accurate geographic analysis and shipping cost calculations.

---

## 8. Missing Category Handling

### Decision
Replace NULL categories with "Uncategorized" rather than dropping.

### Rationale
- **Problem**: 5% of records had missing categories
- **Analysis**: These were valid transactions in all other aspects
- **Solution**: Explicit "Uncategorized" label for transparency

### Alternative Considered
Inferring category from product_sku patterns - rejected due to insufficient pattern reliability.

---

## 9. Amount Parsing

### Decision
Handle multiple amount formats including negative notation.

### Rationale
- **Formats Found**:
  - Currency symbols: $1,234.56
  - European notation: 1.234,56
  - Negative as parentheses: (123.45)
  - Thousands separators: 2,340.00
- **Solution**: Sequential regex replacements to normalize

### Validation
All amounts converted successfully with reasonable ranges ($0.01 to $10,000).

---

## 10. Incomplete Email Completion

### Decision
Add domain extensions to incomplete emails.

### Rationale
- **Problem**: Emails like "john@gmail" missing .com
- **Pattern**: Clear provider identification without extension
- **Solution**: Append appropriate domain extension
- **Providers Handled**: gmail, yahoo, hotmail, outlook

---

## Data Quality Flags

### Decision
Add explicit flags for all inferred or modified data.

### Rationale
- **Transparency**: Users should know which data was cleaned vs. original
- **Audit Trail**: Compliance and debugging requirements
- **Flags Added**:
  - `email_was_inferred`: Y/N
  - `quantity_was_adjusted`: Y/N
  - `is_duplicate`: Y/N (before removal)

---

## Summary Statistics

### Before Cleaning
- Total Records: 40
- Unique Transactions: 35
- Missing Emails: 12 (30%)
- Multiple Date Formats: 4 types
- Duplicate Records: 5 (12.5%)
- Invalid Quantities: 6 (15%)

### After Cleaning
- Total Records: 35
- Unique Transactions: 35
- Missing Emails: 0 (all resolved)
- Date Format: 1 (ISO 8601)
- Duplicate Records: 0
- Invalid Quantities: 0

### Data Completeness Improvement
- **Before**: 67%
- **After**: 94%
- **Improvement**: +40% relative increase

---

## Lessons Learned

1. **System Integration Issues**: Duplicates clustered around maintenance windows suggest system synchronization problems
2. **Data Entry Training**: High rate of format inconsistencies indicates need for better validation at entry point
3. **Geographic Standardization**: Implementing dropdown lists would prevent country name variations
4. **Currency Tracking**: Should be mandatory field with standardized ISO codes

## Recommendations for Production

1. Implement real-time data validation rules
2. Create automated daily exchange rate updates
3. Add data quality monitoring dashboard
4. Establish email verification service integration
5. Create standardized reference tables for countries, currencies, and categories

---

*This documentation demonstrates the thought process behind data cleaning decisions, showing both technical skills and business acumen required for effective data preparation.*