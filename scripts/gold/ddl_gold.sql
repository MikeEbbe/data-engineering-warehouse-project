/*
================================
DDL Script: Create Gold Views
================================
Script purpose:
	This script creates views in the Gold Layer in the data warehouse.
  	The Gold Layer represents the final dimension and fact tables (Star Schema).

    Each view performs transformations and combines data from the Silver Layer
    to produce a clean, enriched and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting
*/

-- ====================================
-- Create Dimension: gold.dim_customers
-- ====================================
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
    DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key, -- Surrogate key
    ci.cst_id AS customer_id,
    ci.cst_key AS customer_number,
    ci.cst_firstname AS first_name,
    ci.cst_lastname AS last_name,
    la.cntry as country,
    ci.cst_marital_status as marital_status,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM is the primary source for gender
        ELSE COALESCE(ca.gen, 'n/a') -- Fallback to ERP data
    END AS gender,
    ca.bdate as birth_date,
    ci.cst_create_date AS create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
    ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 la
    ON ci.cst_key = la.cid;
GO

-- ====================================
-- Create Dimension: gold.dim_products
-- ====================================
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
    DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pi.prd_start_dt, pi.prd_key) AS product_key, -- Surrogate key
    pi.prd_id AS product_id,
    pi.prd_key AS product_number,
    pi.prd_nm AS product_name,
    pi.cat_id AS category_id,
    pcg.cat AS category,
    pcg.subcat AS subcategory,
    pcg.maintenance,
    pi.prd_cost AS cost,
    pi.prd_line AS product_line,
    pi.prd_start_dt AS start_date
FROM silver.crm_prd_info pi
LEFT JOIN silver.erp_px_cat_g1v2 pcg
    ON pi.cat_id = pcg.id
WHERE pi.prd_end_dt IS NULL; -- Filter out all historical data
GO

-- ====================================
-- Create Fact View: gold.fact_sales
-- ====================================
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
    DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num AS order_number,
    p.product_key,
    c.customer_key,
    sd.sls_order_dt AS order_date,
    sd.sls_ship_dt AS shipping_date,
    sd.sls_due_dt AS due_date,
    sd.sls_sales AS sales_amount,
    sd.sls_quantity AS quantity,
    sd.sls_price AS price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products p
    ON sd.sls_prd_key = p.product_number
LEFT JOIN gold.dim_customers c
    ON sd.sls_cust_id = c.customer_id;
GO
