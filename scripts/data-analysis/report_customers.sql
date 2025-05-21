/*
===========================================================================================
Customer report
===========================================================================================
Purpose:
	- This report consolidates key customer metrics and behaviours

Highlights:
	1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Aggregates customer-level metrics:
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

IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
	DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS

/*------------------------------------------------------------------------------
1) Base query: Retrieves core columns from tables
------------------------------------------------------------------------------*/
WITH base_query AS (
	SELECT
		s.order_number,
		s.product_key,
		s.order_date,
		s.sales_amount,
		s.quantity,
		c.customer_key,
		c.customer_number,
		CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
		DATEDIFF(year, c.birth_date, GETDATE()) AS age
	FROM gold.fact_sales AS s
	LEFT JOIN gold.dim_customers AS c
	ON s.customer_key = c.customer_key
	WHERE s.order_date IS NOT NULL
),
/*------------------------------------------------------------------------------
2) Customer aggregations: Summarizes key metrics at the customer level
------------------------------------------------------------------------------*/
customer_aggregation AS (
	SELECT
		customer_key,
		customer_number,
		customer_name,
		age,
		COUNT(DISTINCT order_number) AS total_orders,
		SUM(sales_amount) AS total_sales,
		SUM(quantity) AS total_quantity,
		COUNT(product_key) AS total_products,
		MAX(order_date) AS last_order_date,
		DATEDIFF(month, MIN(order_date), MAX(order_date)) AS months_active
	FROM base_query
	GROUP BY customer_key, customer_number, customer_name, age
)
/*------------------------------------------------------------------------------
3) Final report: Builds a detailed report with customer segmentations
------------------------------------------------------------------------------*/
SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE
		WHEN age < 20 THEN 'Under 20'
		WHEN age BETWEEN 20 AND 29 THEN '20-29'
		WHEN age BETWEEN 30 AND 39 THEN '30-39'
		WHEN age BETWEEN 40 AND 49 THEN '40-49'
		ELSE '50 and above'
	END AS age_group,
	CASE
		WHEN months_active >= 12 AND total_sales > 5000 THEN 'VIP'
		WHEN months_active >= 12 AND total_sales <= 5000 THEN 'Regular'
		ELSE 'New'
	END AS segment,
	last_order_date,
	-- Recency
	DATEDIFF(month, last_order_date, GETDATE()) AS months_since_last_order,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	months_active,
	-- Compute average order value
	CASE WHEN total_orders = 0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_value,
	-- Compute average monthly spendings
	CASE WHEN months_active = 0 THEN total_sales
		ELSE total_sales / months_active
	END AS avg_monthly_spendings
FROM customer_aggregation
