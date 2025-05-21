/*
===========================================================================================
Product report
===========================================================================================
Purpose:
	- This report consolidates key product metrics and behaviours

Highlights:
	1. Gathers essential fields such as product name, category, subcategory, and cost.
	2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers
	3. Aggregates product-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- months active (lifespan)
	4. Calculates valuable KPI's:
		- recency (months since last order)
		- average order value
		- average monthly spendings
===========================================================================================
*/

IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
	DROP VIEW gold.report_products;
GO

CREATE VIEW gold.report_products AS

/*------------------------------------------------------------------------------
1) Base query: Retrieves core columns from tables
------------------------------------------------------------------------------*/
WITH base_query AS (
	SELECT
		p.product_key,
		product_id,
		product_number,
		product_name,
		customer_key,
		category,
		subcategory,
		cost,
		order_number,
		order_date,
		sales_amount,
		quantity
	FROM gold.fact_sales AS s
	LEFT JOIN gold.dim_products AS p
	ON s.product_key = p.product_key
	WHERE s.order_date IS NOT NULL
),
/*------------------------------------------------------------------------------
2) Product aggregations: Summarizes key metrics at the product level
------------------------------------------------------------------------------*/
aggregated_product_metrics AS (
	SELECT
		product_key,
		product_name,
		category,
		subcategory,
		cost,
		COUNT(DISTINCT order_number) AS total_orders,
		COUNT(DISTINCT customer_key) AS total_customers,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		COUNT(product_key) AS total_products,
		MAX(order_date) AS last_order,
		DATEDIFF(month, MIN(order_date), MAX(order_date)) AS months_active,
		ROUND(CAST(SUM(sales_amount) AS FLOAT) / SUM(quantity), 1) AS avg_selling_price
	FROM base_query
	GROUP BY product_key, product_name, category, subcategory, cost
)
/*------------------------------------------------------------------------------
3) Final report: Builds a detailed report with product segmentations
------------------------------------------------------------------------------*/
SELECT
	product_key,
	product_name,
	category,
	subcategory,
	cost,
	months_active,
	last_order,
	-- Compute recency (months since last order)
	DATEDIFF(month, last_order, GETDATE()) AS months_since_last_order,
	total_orders,
	total_quantity,
	total_products,
	total_sales,
	total_customers,
	avg_selling_price,
	-- Compute average order revenue
	CASE WHEN total_orders = 0 THEN 0
		 ELSE total_sales / total_orders
	END AS avg_order_revenue,
	-- Compute average monthly revenue
	CASE WHEN months_active = 0 THEN total_sales
		 ELSE total_sales / months_active
	END AS avg_monthly_revenue,
	-- Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers
	CASE WHEN total_sales > 150000 THEN 'High-Performer'
		 WHEN total_sales BETWEEN 50000 AND 150000 THEN 'Mid-Range'
		 ELSE 'Low-Performer'
	END AS segment
FROM aggregated_product_metrics
