/*
===============================================================================
Gold Layer Reporting Views
===============================================================================

Purpose:
    Create reusable customer and product reporting views for downstream
    analytics and business intelligence.

Prerequisites:
    - gold.fact_sales
    - gold.dim_customers
    - gold.dim_products

Views:
    1. gold.report_customers
    2. gold.report_products
===============================================================================
*/

CREATE OR ALTER VIEW gold.report_customers
AS
WITH customer_metrics AS
(
    SELECT
        c.customer_key,
        c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS customer_age,
        SUM(s.sales_amount) AS total_spending,
        MIN(s.order_date) AS first_order,
        MAX(s.order_date) AS last_order,
        AVG(CAST(s.sales_amount AS DECIMAL(18, 2))) AS average_order_line_sales,
        COUNT(DISTINCT s.order_number) AS total_orders,
        SUM(s.quantity) AS total_quantity,
        COUNT(DISTINCT s.product_key) AS total_products,
        DATEDIFF(MONTH, MIN(s.order_date), MAX(s.order_date)) AS lifespan_months,
        DATEDIFF(MONTH, MAX(s.order_date), GETDATE()) AS months_since_last_order
    FROM gold.dim_customers AS c
    LEFT JOIN gold.fact_sales AS s
        ON c.customer_key = s.customer_key
    GROUP BY
        c.customer_key,
        c.customer_id,
        c.first_name,
        c.last_name,
        c.birthdate
)
SELECT
    customer_key,
    customer_id,
    customer_name,
    customer_age,
    CASE
        WHEN customer_age IS NULL THEN 'Unknown'
        WHEN customer_age <= 35 THEN 'Young'
        WHEN customer_age BETWEEN 36 AND 49 THEN 'Middle-aged'
        ELSE 'Older'
    END AS age_segment,
    total_spending,
    first_order,
    last_order,
    average_order_line_sales,
    total_orders,
    total_quantity,
    total_products,
    lifespan_months,
    months_since_last_order,
    CASE
        WHEN first_order IS NULL THEN 'NEW'
        WHEN lifespan_months >= 12 AND total_spending > 5000 THEN 'VIP'
        WHEN lifespan_months >= 12 AND total_spending <= 5000 THEN 'REGULAR'
        ELSE 'NEW'
    END AS customer_type
FROM customer_metrics;
GO

CREATE OR ALTER VIEW gold.report_products
AS
WITH product_metrics AS
(
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.product_cost,
        p.start_date,
        COUNT(DISTINCT s.customer_key) AS total_customers,
        COUNT(DISTINCT s.order_number) AS total_orders,
        SUM(s.quantity) AS total_quantity,
        SUM(s.sales_amount) AS total_revenue,
        MAX(s.order_date) AS last_sale_date
    FROM gold.dim_products AS p
    LEFT JOIN gold.fact_sales AS s
        ON p.product_key = s.product_key
    GROUP BY
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.product_cost,
        p.start_date
)
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    product_cost,
    total_customers,
    total_orders,
    total_quantity,
    total_revenue,
    DATEDIFF(MONTH, start_date, GETDATE()) AS product_lifespan_months,
    DATEDIFF(MONTH, last_sale_date, GETDATE()) AS months_since_last_sale,
    CASE
        WHEN total_revenue >= 30000 THEN 'HIGH Performer'
        WHEN total_revenue >= 5000 THEN 'MID-Range'
        ELSE 'Low-Performers'
    END AS product_segmentation,
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE CAST(total_revenue AS DECIMAL(18, 2)) / total_orders
    END AS average_order_revenue,
    CASE
        WHEN DATEDIFF(MONTH, start_date, GETDATE()) <= 0 THEN 0
        ELSE CAST(COALESCE(total_revenue, 0) AS DECIMAL(18, 2))
             / DATEDIFF(MONTH, start_date, GETDATE())
    END AS average_monthly_revenue
FROM product_metrics;
GO
