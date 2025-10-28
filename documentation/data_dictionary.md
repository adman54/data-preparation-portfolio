# Data Dictionary
## Cleaned E-Commerce Sales Dataset

### Table: cleaned_sales_data

This table contains the cleaned and standardized e-commerce transaction data ready for analysis.

| Column Name | Data Type | Description | Example | Constraints |
|------------|-----------|-------------|---------|-------------|
| **transaction_id** | VARCHAR(50) | Unique identifier for each transaction | TRX_001 | PRIMARY KEY, NOT NULL |
| **customer_id** | VARCHAR(50) | Unique identifier for each customer | CUST_1001 | NOT NULL |
| **customer_email** | VARCHAR(100) | Customer email address (inferred if missing) | john.doe@gmail.com | NOT NULL, Valid email format |
| **product_sku** | VARCHAR(50) | Stock keeping unit for product identification | PROD_ABC123 | NOT NULL |
| **quantity** | INTEGER | Number of items purchased (adjusted if invalid) | 2 | NOT NULL, > 0, ≤ 100 |
| **amount_usd** | DECIMAL(10,2) | Transaction amount in USD (converted from original currency) | 1234.56 | NOT NULL, > 0 |
| **original_currency** | VARCHAR(10) | Original currency code before conversion | EUR | NOT NULL |
| **order_date** | DATE | Date of transaction (standardized to ISO format) | 2024-03-15 | NOT NULL, Valid date |
| **ship_country** | VARCHAR(100) | Standardized shipping destination country | United States | NOT NULL |
| **payment_method** | VARCHAR(50) | Payment method used for transaction | Credit Card | NOT NULL |
| **category** | VARCHAR(50) | Product category (Uncategorized if missing) | Electronics | NOT NULL |
| **email_was_inferred** | CHAR(1) | Flag indicating if email was generated | Y/N | NOT NULL |
| **quantity_was_adjusted** | CHAR(1) | Flag indicating if quantity was corrected | Y/N | NOT NULL |

---

### Table: sales_fact

Enhanced fact table with derived dimensions and metrics for analytical queries.

| Column Name | Data Type | Description | Example |
|------------|-----------|-------------|---------|
| **transaction_id** | VARCHAR(50) | Unique transaction identifier | TRX_001 |
| **customer_id** | VARCHAR(50) | Customer identifier | CUST_1001 |
| **product_sku** | VARCHAR(50) | Product identifier | PROD_ABC123 |
| **order_date** | DATE | Transaction date | 2024-03-15 |
| **order_year** | INTEGER | Year extracted from order_date | 2024 |
| **order_quarter** | INTEGER | Quarter (1-4) | 1 |
| **order_month** | INTEGER | Month (1-12) | 3 |
| **order_week** | INTEGER | Week of year (1-52) | 11 |
| **order_month_name** | VARCHAR(20) | Full month name | March |
| **order_day_name** | VARCHAR(20) | Full day name | Friday |
| **day_type** | VARCHAR(10) | Weekend or Weekday | Weekday |
| **quantity** | INTEGER | Items purchased | 2 |
| **amount_usd** | DECIMAL(10,2) | Transaction amount in USD | 1234.56 |
| **total_amount_usd** | DECIMAL(10,2) | quantity × amount_usd | 2469.12 |
| **customer_email** | VARCHAR(100) | Customer email | john.doe@gmail.com |
| **ship_country** | VARCHAR(100) | Shipping country | United States |
| **payment_method** | VARCHAR(50) | Payment type | Credit Card |
| **category** | VARCHAR(50) | Product category | Electronics |
| **original_currency** | VARCHAR(10) | Pre-conversion currency | USD |
| **transaction_size** | VARCHAR(20) | Size classification based on amount | Large |
| **region** | VARCHAR(50) | Geographic region grouping | North America |
| **processed_at** | TIMESTAMP | When record was processed | 2024-04-25 10:30:00 |

#### Transaction Size Categories
- **Small**: < $50
- **Medium**: $50 - $249.99
- **Large**: $250 - $999.99
- **Enterprise**: ≥ $1000

#### Region Mappings
- **North America**: United States, Canada, Mexico
- **Europe**: UK, Germany, France, Spain, Italy, Netherlands, Belgium
- **Asia**: Japan, South Korea, India
- **Oceania**: Australia
- **Other**: All other countries

---

### Table: customer_summary

Aggregated customer metrics for segmentation and analysis.

| Column Name | Data Type | Description | Example |
|------------|-----------|-------------|---------|
| **customer_id** | VARCHAR(50) | Unique customer identifier | CUST_1001 |
| **customer_email** | VARCHAR(100) | Primary email address | john.doe@gmail.com |
| **total_transactions** | INTEGER | Number of transactions | 3 |
| **unique_products_purchased** | INTEGER | Distinct products bought | 2 |
| **unique_categories_purchased** | INTEGER | Distinct categories | 2 |
| **total_items_purchased** | INTEGER | Sum of all quantities | 5 |
| **total_spent_usd** | DECIMAL(10,2) | Lifetime value in USD | 5924.34 |
| **avg_transaction_value** | DECIMAL(10,2) | Average purchase amount | 1974.78 |
| **first_purchase_date** | DATE | Initial transaction date | 2024-03-15 |
| **last_purchase_date** | DATE | Most recent transaction | 2024-04-06 |
| **customer_lifetime_days** | INTEGER | Days between first and last purchase | 22 |
| **primary_shipping_country** | VARCHAR(100) | Most frequent ship destination | United States |
| **preferred_payment_method** | VARCHAR(50) | Most used payment type | Credit Card |
| **customer_segment** | VARCHAR(20) | Frequency-based classification | Regular |
| **days_since_last_purchase** | INTEGER | Recency metric | 19 |
| **purchase_frequency** | INTEGER | Total transaction count | 3 |
| **monetary_quintile** | INTEGER | Spending rank (1-5, 5=highest) | 4 |

#### Customer Segments
- **One-time**: 1 transaction
- **Occasional**: 2-3 transactions
- **Regular**: 4-6 transactions
- **Frequent**: 7+ transactions

---

### Table: product_performance

Product-level metrics and rankings.

| Column Name | Data Type | Description | Example |
|------------|-----------|-------------|---------|
| **product_sku** | VARCHAR(50) | Product identifier | PROD_ABC123 |
| **category** | VARCHAR(50) | Product category | Electronics |
| **times_ordered** | INTEGER | Transaction count | 4 |
| **unique_customers** | INTEGER | Distinct buyers | 3 |
| **total_quantity_sold** | INTEGER | Units sold | 7 |
| **total_revenue_usd** | DECIMAL(10,2) | Revenue generated | 4567.89 |
| **avg_selling_price** | DECIMAL(10,2) | Mean price | 1141.97 |
| **min_selling_price** | DECIMAL(10,2) | Lowest price | 234.00 |
| **max_selling_price** | DECIMAL(10,2) | Highest price | 2340.00 |
| **price_volatility** | DECIMAL(10,2) | Standard deviation of price | 456.78 |
| **revenue_rank** | INTEGER | Rank by total revenue | 1 |
| **popularity_rank** | INTEGER | Rank by order frequency | 1 |
| **performance_category** | VARCHAR(20) | Above/Below Average | Above Average |

---

### Table: daily_sales_summary

Daily aggregated metrics with trend analysis.

| Column Name | Data Type | Description | Example |
|------------|-----------|-------------|---------|
| **order_date** | DATE | Calendar date | 2024-03-15 |
| **day_name** | VARCHAR(20) | Day of week | Friday |
| **num_transactions** | INTEGER | Daily transaction count | 2 |
| **unique_customers** | INTEGER | Distinct daily customers | 2 |
| **items_sold** | INTEGER | Total units sold | 3 |
| **daily_revenue_usd** | DECIMAL(10,2) | Total daily revenue | 2124.56 |
| **avg_transaction_value** | DECIMAL(10,2) | Mean transaction amount | 1062.28 |
| **cumulative_revenue** | DECIMAL(10,2) | Running total revenue | 2124.56 |
| **moving_avg_7day_revenue** | DECIMAL(10,2) | 7-day rolling average | 1543.21 |
| **previous_day_revenue** | DECIMAL(10,2) | Prior day's revenue | NULL/1890.00 |
| **day_over_day_growth_pct** | DECIMAL(5,2) | Daily growth percentage | 12.4 |

---

### Table: data_quality_metrics

Before/after metrics showing cleaning impact.

| Column Name | Data Type | Description | Example |
|------------|-----------|-------------|---------|
| **metric** | VARCHAR(100) | Quality measure name | Records Processed |
| **before_cleaning** | INTEGER | Pre-cleaning value | 40 |
| **after_cleaning** | INTEGER | Post-cleaning value | 35 |
| **difference** | INTEGER | Change in value | -5 |
| **change_pct** | DECIMAL(5,2) | Percentage change | -12.5 |

---

## Data Quality Flags

### email_was_inferred
- **Y**: Email was missing and generated using pattern customer_{id}@inferred.com
- **N**: Original email present (possibly with minor corrections like adding .com)

### quantity_was_adjusted
- **Y**: Original quantity was ≤0 or >100 and was adjusted
- **N**: Original quantity was valid

---

## Business Rules Applied

1. **Currency Conversion**: All amounts converted to USD for consistency
2. **Date Standardization**: All dates in ISO 8601 format (YYYY-MM-DD)
3. **Email Validation**: All emails follow pattern: username@domain.extension
4. **Quantity Limits**: Valid range 1-100 items per transaction
5. **Country Normalization**: Standardized to full country names
6. **Category Assignment**: NULL categories become "Uncategorized"

---

## Usage Notes

- **Inferred Data**: Check quality flags to identify cleaned vs. original data
- **Currency**: Use original_currency field to identify source currency
- **Time Series**: Use order_date for temporal analysis
- **Customer Analysis**: Use customer_summary for segmentation
- **Product Analysis**: Use product_performance for SKU insights
- **Trend Analysis**: Use daily_sales_summary for time-based patterns

---

## Update Frequency
- This represents a point-in-time cleaning of historical data
- For production use, implement real-time validation rules
- Recommend daily quality checks on new data

---

*Last Updated: 2024*  
*Version: 1.0*  
*Contact: Data Portfolio Project*