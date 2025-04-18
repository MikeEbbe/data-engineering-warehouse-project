/*
======================================================
Quality Checks
======================================================
Script purpose:
    This scripts peforms various quality checks for
    data consistency, accuracy, and standardization
    across the 'silver' schema. It include checks for:
    - NULL or duplicate primary keys
    - Unwanted spaces in string fields
    - Data standardization and consistency
    - Invalid date ranges and orders
    - Data consistency between related fields

Usage notes:
    - Run these checks after loading the Silver layer.
    - Investigate and resolve any discrepancies found
      during the checks.
======================================================
*/

-- ============================================
-- Checking 'silver.crm_cust_info'
-- ============================================
-- Check for NULLs or duplicates in Primary Key
-- Expectation: No results
SELECT
    cst_id,
    COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for unwanted spaces
-- Expectation: No results
SELECT
    cst_key
FROM silver.crm_cust_info
WHERE cst_key != LTRIM(RTRIM(cst_key));

-- Data Standardization & Consistency
SELECT DISTINCT
    cst_marital_status
FROM silver.crm_cust_info;

-- ============================================
-- Checking 'silver.crm_prd_info'
-- ============================================
-- Check for NULLs or duplicates in Primary Key
-- Expectation: No results
SELECT
    prd_id,
    COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- Check for unwanted spaces
-- Expectation: No results
SELECT
    prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != LTRIM(RTRIM(prd_nm));

-- Check for NULLS or negative numbers
-- Expectation: No results
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- Data Standardization & Consistency
SELECT DISTINCT
    prd_line
FROM silver.crm_prd_info;

-- Check for Invalid Date Orders (Start Date > End Date)
-- Expected: No results
SELECT
    *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- ============================================
-- Checking 'silver.crm_sales_details'
-- ============================================
-- Check for Invalid Dates
-- Expectation: No invalid dates
SELECT
    NULLIF(sls_due_dt, 0) sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0
    OR LEN(sls_due_dt) != 8
    OR sls_due_dt > 20500101
    OR sls_due_dt < 19000101;

-- Check for Invalid Order Dates (Order Date > Shipping Date/Due Date)
-- Expectation: No results
SELECT
*
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt
    OR sls_order_dt > sls_due_dt;

-- Check Data Consistency: Sales = Quantity * Price
-- Expectation: No results
SELECT DISTINCT
    sls_sales,
    sls_quantity,
    sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
    OR sls_sales IS NULL
    OR sls_quantity IS NULL
    OR sls_price IS NULL
    OR sls_sales <= 0
    OR sls_quantity <= 0
    OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- ============================================
-- Checking 'silver.erp_cust_az12'
-- ============================================
-- Identify out-of-range Dates
-- Expectation: Birth dates between 1924-01-01 and Today
SELECT DISTINCT
    bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
    OR bdate > GETDATE();

-- Data Standardization & Consistency
SELECT DISTINCT 
    gen 
FROM silver.erp_cust_az12;

-- ============================================
-- Checking 'silver.erp_loc_a101'
-- ============================================
-- Data Standardization & Consistency
SELECT DISTINCT 
    cntry 
FROM silver.erp_loc_a101
ORDER BY cntry;

-- ============================================
-- Checking 'silver.erp_px_cat_g1v2'
-- ============================================
-- Check for Unwanted Spaces
-- Expectation: No results
SELECT 
    * 
FROM silver.erp_px_cat_g1v2
WHERE cat != LTRIM(RTRIM(cat))
   OR subcat != LTRIM(RTRIM(subcat)) 
   OR maintenance != LTRIM(RTRIM(maintenance));

-- Data Standardization & Consistency
SELECT DISTINCT 
    maintenance 
FROM silver.erp_px_cat_g1v2;
