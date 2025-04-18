/*
======================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
======================================================
Script purpose:
  This stored procedure performs the ETL (Extract, Transform, Load) process to
  populate the 'silver' schema tables from the 'bronze' schema.
  It performs the following actions:
  - Truncates the silver tables
  - Inserts transformed and cleansed data from Bronze tables into Silver tables

  Parameters:
    None.
    This stored procedure does not accept any parameter nor returns any values. 

  Usage example:
    EXEC silver.load_silver;
*/
CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_batch_time DATETIME, @end_batch_time DATETIME, @start_time DATETIME, @end_time DATETIME;
    BEGIN TRY
        SET @start_batch_time = GETDATE();
        PRINT '=======================================================';
        PRINT 'Loading Silver Layer';
        PRINT '=======================================================';

        PRINT '-------------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '-------------------------------------------------------';

        -- Loading silver.crm_cust_info
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;
        PRINT '>> Inserting Data into: silver.crm_cust_info';
        INSERT INTO silver.crm_cust_info (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            cst_key,
            LTRIM(RTRIM(cst_firstname)) AS cst_firstname,
            LTRIM(RTRIM(cst_lastname)) AS cst_lastname,
            CASE WHEN UPPER(LTRIM(RTRIM(cst_marital_status))) = 'S' THEN 'Single'
                WHEN UPPER(LTRIM(RTRIM(cst_marital_status))) = 'M' THEN 'Married'
                ELSE 'n/a' -- Standardize marital status values to readable format
            END AS cst_marital_status,
            CASE WHEN UPPER(LTRIM(RTRIM(cst_gndr))) = 'F' THEN 'Female'
                WHEN UPPER(LTRIM(RTRIM(cst_gndr))) = 'M' THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr, -- Standardize gender values to readable format
            cst_create_date
        FROM (
            SELECT
                *,
                ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) latest_rows
        WHERE flag_last = 1 -- Select the most recent record per customer
        SET @end_time = GETDATE();
		PRINT '';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------';
		PRINT '';

        -- Loading silver.crm_prd_info
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;
        PRINT '>> Inserting Data into: silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1,5), '-', '_') AS cat_id, -- Extract category ID
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key, -- Extract product key
            prd_nm,
            ISNULL(prd_cost, 0) AS prd_cost,
            CASE UPPER(LTRIM(RTRIM(prd_line)))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a' -- Map product line codes to readable format
            END AS prd_line,
            CAST (prd_start_dt AS DATE) AS prd_start_dt,
            CAST (
                DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt))
                AS DATE
            ) AS prd_end_dt -- Calculate end date as one day before the next start date
        FROM bronze.crm_prd_info
        SET @end_time = GETDATE();
		PRINT '';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------';
		PRINT '';

        -- Loading silver.crm_sales_details
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;
        PRINT '>> Inserting Data into: silver.crm_sales_details';
        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt, -- Handle incorrect dates and cast to dates
            CASE
                WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales, -- Recalculate sales if original value is missing or incorrect
            sls_quantity,
            CASE 
                WHEN sls_price IS NULL OR sls_price <= 0
                THEN sls_sales / NULLIF(sls_quantity, 0)
                ELSE sls_price -- Derive price if original value is invalid
            END AS sls_price
        FROM bronze.crm_sales_details
        SET @end_time = GETDATE();
		PRINT '';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------';
		PRINT '';

        PRINT '-------------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '-------------------------------------------------------';

        -- Loading silver.erp_cust_az12
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;
        PRINT '>> Inserting Data into: silver.erp_cust_az12';
        INSERT INTO silver.erp_cust_az12 (
            cid,
            bdate,
            gen
        )
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- Remove 'NAS' prefix if present 
                ELSE cid
            END AS cid,
            CASE WHEN bdate > GETDATE() THEN NULL -- Set future birth dates to NULL
                ELSE bdate
            END AS bdate,
            CASE WHEN gen = 'M' OR gen = 'Male' THEN 'Male'
                WHEN UPPER(LTRIM(RTRIM(gen))) IN ('M', 'Male') THEN 'Male'
                WHEN UPPER(LTRIM(RTRIM(gen))) IN ('F', 'Female') THEN 'Female'
                ELSE 'n/a'
            END AS gen -- Standardize gender values and handle unknown cases
        FROM bronze.erp_cust_az12
        SET @end_time = GETDATE();
		PRINT '';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------';
		PRINT '';

        -- Loading silver.erp_loc_a101
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;
        PRINT '>> Inserting Data into: silver.erp_loc_a101';
        INSERT INTO silver.erp_loc_a101 (
            cid,
            cntry
        )
        SELECT
        REPLACE(cid, '-', '') AS cid,
        CASE WHEN UPPER(LTRIM(RTRIM(cntry))) IN ('US', 'USA') THEN 'United States'
            WHEN UPPER(LTRIM(RTRIM(cntry))) = 'DE' THEN 'Germany'
            WHEN UPPER(LTRIM(RTRIM(cntry))) = '' OR cntry IS NULL THEN 'n/a'
            ELSE cntry
        END AS cntry -- Standardize and handle missing or blank country codes
        FROM bronze.erp_loc_a101
        SET @end_time = GETDATE();
		PRINT '';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------';
		PRINT '';

        -- Loading silver.erp_px_cat_g1v2
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;
        PRINT '>> Inserting Data into: silver.erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
        id,
        cat,
        subcat,
        maintenance
        FROM bronze.erp_px_cat_g1v2
        SET @end_time = GETDATE();
		PRINT '';
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
		PRINT '>> ---------------------------';
		PRINT '';
        SET @end_batch_time = GETDATE();
        PRINT '=======================================================';
        PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(second, @start_batch_time, @end_batch_time) AS NVARCHAR) + ' seconds';
        PRINT '=======================================================';
    END TRY
	BEGIN CATCH
		PRINT '=======================================================';
		PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		PRINT 'Error in procedure: ' + OBJECT_NAME(@@PROCID);
		PRINT 'Error message: ' + ERROR_MESSAGE();
		PRINT 'Error number: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error line: ' + CAST(ERROR_LINE() AS NVARCHAR);
		PRINT 'Error severity: ' + CAST(ERROR_SEVERITY() AS NVARCHAR);
		PRINT 'Error state: ' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '=======================================================';
	END CATCH
END
