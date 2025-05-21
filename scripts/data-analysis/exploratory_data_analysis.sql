-- ============================================================================
-- EXPLORATORY DATA ANALYSIS (EDA)
-- ============================================================================
-- Columns can be divided into 'dimensions' and 'measures'.
-- If the column's data type is NOT a number, then it is a dimension.
-- If it is a number, and it makes sense to aggregate it, then it is a measure.

-- Explore all objects in the database
SELECT * FROM INFORMATION_SCHEMA.TABLES

-- Explore all columns in the database
SELECT * FROM INFORMATION_SCHEMA.COLUMNS
--WHERE TABLE_NAME = 'dim_customers' -- specify a table

-- ======================
-- Dimensions exploration
-- ======================
-- Explore all countries our customers come from
SELECT DISTINCT
	country
FROM gold.dim_customers

-- Explore all categories
SELECT DISTINCT
	category,
	subcategory,
	product_name
FROM gold.dim_products
ORDER BY 1, 2, 3

-- ======================
-- Date exploration
-- ======================
-- Order date analysis
SELECT
	MIN(order_date) AS first_order_date,
	MAX(order_date) AS last_order_date,
	DATEDIFF(year, MIN(order_date), MAX(order_date)) AS years_of_difference
FROM gold.fact_sales

-- Oldest and youngest customers
SELECT
	DATEDIFF(year, MIN(birth_date), GETDATE()) AS oldest_customer,
	DATEDIFF(year, MAX(birth_date), GETDATE()) AS youngest_customer
FROM gold.dim_customers

-- ======================
-- Measures exploration
-- ======================
-- Focus on the big numbers that matter the most to our business.

-- Generate a report that shows all key metrics of the business
SELECT 'Total Sales' AS measure_name, SUM(sales_amount) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity' AS measure_name, SUM(quantity) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Average Price' AS measure_name, AVG(price) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Nr. Orders' AS measure_name, COUNT(DISTINCT order_number) AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Nr. Products' AS measure_name, COUNT(product_key) AS measure_value FROM gold.dim_products
UNION ALL
SELECT 'Total Nr. Customers' AS measure_name, COUNT(customer_key) AS measure_value FROM gold.dim_customers

-- ======================
-- Magnitude analysis
-- ======================
-- Combine any measure by dimension

-- Total total customers by countries
SELECT
	country,
	COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC

-- Total total customers by gender
SELECT
	gender,
	COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY gender
ORDER BY total_customers DESC

-- Total total products by category
SELECT
	category,
	COUNT(product_key) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC

-- Average cost by category
SELECT
	category,
	AVG(cost) AS avg_cost
FROM gold.dim_products
GROUP BY category
ORDER BY avg_cost DESC

-- Total revenue by category
SELECT
	p.category,
	SUM(s.sales_amount) AS total_revenue
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_products AS p ON s.product_key = p.product_key
GROUP BY category
ORDER BY total_revenue DESC

-- Total revenue by customer
SELECT
	c.customer_key,
	c.first_name,
	c.last_name,
	SUM(sales_amount) AS total_revenue
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_customers AS c ON s.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC

-- Total quantity by country
SELECT
	SUM(quantity) AS total_sold_items,
	c.country
FROM gold.fact_sales AS s
JOIN gold.dim_customers AS c ON s.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_sold_items DESC

-- Total revenue by gender
SELECT
	gender,
	SUM(sales_amount) AS total_revenue
FROM gold.fact_sales AS s
JOIN gold.dim_customers AS c ON s.customer_key = c.customer_key
GROUP BY gender
ORDER BY total_revenue DESC

-- ======================
-- Ranking analysis
-- ======================
-- Order the values of dimensions by measure to identify the top and bottom N performers.

-- The 5 products that generate the highest revenue
SELECT TOP 5
	p.product_name,
	SUM(sales_amount) AS total_revenue
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_products AS p ON s.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC

-- Alternative solution
SELECT *
FROM(
	SELECT
		p.product_name,
		SUM(s.sales_amount) AS total_revenue,
		RANK () OVER (ORDER BY SUM(s.sales_amount) DESC) AS ranked_products
	FROM gold.fact_sales AS s
	LEFT JOIN gold.dim_products AS p ON s.product_key = p.product_key
	GROUP BY product_name
) AS t
WHERE ranked_products <= 5

-- The 5 products that perform the worst in terms of sales
SELECT TOP 5
	p.product_name,
	SUM(sales_amount) AS total_revenue
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_products AS p ON s.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue

-- The top 10 customers who have generated to highest revenue.
SELECT TOP 10
	c.customer_key,
	c.first_name,
	c.last_name,
	SUM(sales_amount) AS total_revenue
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_customers AS c ON s.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC

-- The 3 customers with the fewest orders placed
SELECT *
FROM(
	SELECT
		c.customer_key,
		c.first_name,
		c.last_name,
		COUNT(DISTINCT order_number) AS amount_of_orders,
		ROW_NUMBER () OVER (ORDER BY COUNT(DISTINCT order_number)) AS ranked_amount
	FROM gold.dim_customers AS c
	LEFT JOIN gold.fact_sales AS s ON c.customer_key = s.customer_key
	GROUP BY c.customer_key, c.first_name, c.last_name
) AS t
WHERE ranked_amount <= 3
