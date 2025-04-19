# Data Catalog
The Gold Layer is the business-level data representation, structured to support analytical and reporting use cases. It consist of **dimension views** and **fact views** for specific business metrics.

## gold.dim_customers
- Purpose: Stores customer details enriched with demographic and geographic data.
- Columns:

| Column Name     | Data Type    | Description                                                                           |
| --------------- | ------------ | ------------------------------------------------------------------------------------- |
| customer_key    | INT          | Surrogate key uniquely identifying each customer record in the dimension table.       |
| customer_id     | INT          | Unique numerical identifier assigned to each customer.                                |
| customer_number | INT          | Alphanumeric identifier representing the customer, used for tracking and referencing. |
| first_name      | NVARCHAR(50) | Alphanumeric first name of the customer.                                              |
| last_name       | NVARCHAR(50) | Alphanumeric last name of the customer.                                               |
| country         | NVARCHAR(50) | The customer's country of residence (e.g., 'Australia').                              |
| marital_status  | NVARCHAR(50) | The customer's marital status (e.g., 'Married', 'Single').                            |
| gender          | NVARCHAR(50) | The customer's gender (e.g., 'Male', 'Female', 'n/a').                                |
| birth_date      | DATE         | The customer's date of birth, formatted as YYYY-MM-DD (e.g., 1974-03-26).             |
| create_date     | DATE         | The date when the customer record was created in the system.                          |

## gold.dim_products
- Purpose: Provides product information enriched with category data.
- Columns:

| Column Name          | Data Type    | Description                                                                                                                      |
| -------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| product_key          | INT          | Surrogate key uniquely identifying each product record in the dimension table.                                                   |
| product_id           | INT          | Unique numerical identifier assigned to each product for internal tracking and referencing.                                      |
| product_number       | NVARCHAR(50) | Structured alphanumeric code representing the product, used for categorization and inventory.                                    |
| product_name         | NVARCHAR(50) | Descriptive name of the product, including key details such as type, color and size.                                             |
| category_id          | NVARCHAR(50) | Structured alphanumeric code representing the product's category, linking to its high-level classification.                      |
| category             | NVARCHAR(50) | High-level classification of the product (e.g., 'Bikes', 'Components') used to group related items.                              |
| subcategory          | NVARCHAR(50) | Low-level classification of the product within the category, specifying the product type (e.g., 'Mountain Bikes', 'Road Bikes'). |
| maintenance_required | NVARCHAR(50) | Indicates whether the product required maintenance (e.g., 'Yes', 'No').                                                          |
| cost                 | INT          | The cost or base price of the product, measured in monetary units.                                                               |
| product_line         | NVARCHAR(50) | The specific product line or series of which the product belongs to (e.g., 'Mountain', 'Road').                                  |
| start_date           | DATE         | The date when the product became available for sale or use.                                                                      |

## gold.fact_sales
- Purpose: Stores transactional sales data for analytical purposes.
- Columns:

| Column Name   | Data Type    | Description                                                                              |
| ------------- | ------------ | ---------------------------------------------------------------------------------------- |
| order_number  | NVARCHAR(50) | Unique alphanumeric identifier for each sales order (e.g., 'S043698').                   |
| product_key   | INT          | Surrogate key linking the order to the product dimension table.                          |
| customer_key  | INT          | Surrogate key linking the order to the customer dimension table.                         |
| order_date    | DATE         | The date when the order was placed.                                                      |
| shipping_date | DATE         | The date when the order was shipped to the customer.                                     |
| due_date      | DATE         | The date when the order payment was due.                                                 |
| sales_amount  | INT          | The total monetary value of the line item, in whole currency units (e.g., 50).           |
| quantity      | INT          | The number of product units ordered for the line item (e.g., 2).                         |
| price         | INT          | The price per unit of the product for the line item, in whole currency units (e.g., 25). |
