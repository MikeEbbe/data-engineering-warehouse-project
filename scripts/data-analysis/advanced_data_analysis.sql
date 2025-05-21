-- ============================================================================
-- ADVANCED DATA ANALYSIS
-- ============================================================================

-- =========================
-- Change-over-Time (Trends)
-- =========================
-- Analyze how a measure evolve over time.
-- This helps track trends and intentifies seasonality in your data.

-- Analyze sales performance over time
SELECT
	DATETRUNC(month, order_date) AS order_month,
	SUM(sales_amount) AS total_sales,
	COUNT(DISTINCT customer_key) AS total_customers,
	SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY order_month

-- =========================
-- Cumulative analysis
-- =========================
-- Aggregate the data progressively over time.
-- Helps understand whether our business is growing or declining.

-- Calculate the total sales per month
WITH sales_per_month AS (
SELECT
	DATETRUNC(year, order_date) AS order_year,
	SUM(sales_amount) AS total_sales,
	AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(year, order_date)
)

-- The running total of sales over time, and moving average of prices over time
SELECT
	order_year,
	total_sales,
	SUM(total_sales) OVER (ORDER BY order_year) AS running_total_sales,
	avg_price,
	AVG(avg_price) OVER (ORDER BY order_year) AS moving_avg_price
FROM sales_per_month
ORDER BY order_year

-- =========================
-- Performance analysis
-- =========================
-- Compare a current value to a target value.
-- Helps measure success and compare performance.

-- Analyze the yearly performance of products by comparing each product's sales
-- to both its average sales performance and the previous years' sales.
WITH yearly_sales_per_product AS (
	-- Yearly sales per product
	SELECT
		YEAR(s.order_date) AS order_year,
		p.product_name,
		SUM(s.sales_amount) AS total_sales
	FROM gold.fact_sales AS s
	LEFT JOIN gold.dim_products AS p
	ON p.product_key = s.product_key
	WHERE order_date IS NOT NULL
	GROUP BY YEAR(s.order_date), p.product_name
)
-- Final query with performance segmentation
SELECT
	order_year,
	product_name,
	total_sales,
	-- Average sales performance
	AVG(total_sales) OVER (PARTITION BY product_name) AS avg_sales,
	total_sales - AVG(total_sales) OVER (PARTITION BY product_name) AS diff_avg,
	CASE WHEN total_sales - AVG(total_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
		WHEN total_sales - AVG(total_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
		ELSE 'Avg'
	END AS avg_change,
	-- Year-over-Year performance
	LAG(total_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS last_year_sales,
	total_sales - LAG(total_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_last_year,
	CASE WHEN total_sales - LAG(total_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
		WHEN total_sales - LAG(total_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
		ELSE 'No change'
	END AS last_year_change
FROM yearly_sales_per_product
ORDER BY product_name, order_year

-- =========================
-- Part-to-Whole analysis
-- =========================
-- Analyze how an individual part is performing compared to the overall.
-- Allows you to understand which category has the greatest impact on the business.

-- Which categories contribute the most to the overall sales?
WITH sales_per_cat AS (
SELECT
	p.category,
	SUM(s.sales_amount) AS cat_sales
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_products AS p
ON s.product_key = p.product_key
GROUP BY p.category
)
-- Final query with contribution calculation
SELECT
	category,
	cat_sales,
	SUM(cat_sales) OVER () AS total_sales,
	CONCAT(ROUND(CAST(cat_sales AS FLOAT) / SUM(cat_sales) OVER () * 100, 1), '%') AS contribution
FROM sales_per_cat
ORDER BY cat_sales DESC

-- =========================
-- Data segmentation
-- =========================
-- Group the data based on a specific range.
-- Helps understand the correlation between two measures.
-- Helpful for when dimensions alone don't contain enough information to analyze on.

-- Segment products into cost ranges and count how many products fall into each segment.
WITH products_segmented_by_cost AS (
	SELECT
		product_name,
		cost,
		CASE
			WHEN cost < 100 THEN 'Below 100'
			WHEN cost BETWEEN 100 AND 500 THEN '100-500'
			WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
			ELSE 'Above 1000'
		END AS cost_range
	FROM gold.dim_products
)
-- Final query that counts the amount per segment
SELECT
	cost_range,
	COUNT(product_name) AS amount_per_segment
FROM products_segmented_by_cost
GROUP BY cost_range
ORDER BY amount_per_segment DESC

/*
Group customers into three segments based on their spending behaviour:
	- VIP: Customers with at least 12 months of history and spending more than €5000.
	- Regular: Customers with at least 12 months of history but spending €5000 or less.
	- New: Customers with a lifespin less of 12 months.
And find the total number of customers per group.
*/
-- Calculate customer lifespan and total spending
WITH spending_behaviour AS (
	SELECT
		c.customer_key,
		MIN(order_date) AS first_order_date,
		MAX(order_date) AS last_order_date,
		DATEDIFF(month, MIN(order_date), MAX(order_date)) AS months_active, -- months of history
		SUM(s.sales_amount) AS spent -- spendings
	FROM gold.dim_customers AS c
	LEFT JOIN gold.fact_sales AS s
	ON c.customer_key = s.customer_key
	GROUP BY c.customer_key
),
-- Assign segments based on lifespan and spending
segmented_customers AS (
	SELECT
		customer_key,
		CASE
			WHEN months_active >= 12 AND spent > 5000 THEN 'VIP'
			WHEN months_active >= 12 AND spent <= 5000 THEN 'Regular'
			ELSE 'New'
		END AS segment
	FROM spending_behaviour AS sb
)
-- Count customers per segment
SELECT
	segment,
	COUNT(customer_key) AS customers_per_segment
FROM segmented_customers
GROUP BY segment
ORDER BY customers_per_segment DESC
