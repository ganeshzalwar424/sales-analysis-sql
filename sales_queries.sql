
 Sales Analysis Queries (PostgreSQL)
 Business rule: revenue counts only 'Completed' orders

 
 
-- Q1. Total revenue, total orders, and average order value
SELECT
    COUNT(DISTINCT o.order_id)  AS total_orders,
    SUM(oi.quantity * p.price)      AS total_revenue,
    ROUND(SUM(oi.quantity * p.price)
          / COUNT(DISTINCT o.order_id), 2)   AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.status = 'Completed';
 
 
-- Q2. Revenue by product category, with share of total
SELECT
    p.category,
    SUM(oi.quantity * p.price) AS revenue,
    ROUND(100.0 * SUM(oi.quantity * p.price)
          / SUM(SUM(oi.quantity * p.price)) OVER (), 1) AS pct_of_total
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.status = 'Completed'
GROUP BY p.category
ORDER BY revenue DESC;
 
 
-- Q3. Top 3 best-selling products by revenue
SELECT
    p.product_name,
    SUM(oi.quantity)            AS units_sold,
    SUM(oi.quantity * p.price)  AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.status = 'Completed'
GROUP BY p.product_name
ORDER BY revenue DESC
LIMIT 3;
 
 
-- Q4. Monthly revenue with month-over-month growth (CTE + LAG)
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::date AS month,
        SUM(oi.quantity * p.price)              AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.status = 'Completed'
    GROUP BY 1
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / LAG(revenue) OVER (ORDER BY month), 1) AS mom_growth_pct
FROM monthly
ORDER BY month;
 
 
-- Q5. Running (cumulative) revenue by month
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::date AS month,
        SUM(oi.quantity * p.price)              AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.status = 'Completed'
    GROUP BY 1
)
SELECT
    month,
    revenue,
    SUM(revenue) OVER (ORDER BY month) AS running_total
FROM monthly
ORDER BY month;
 
 
-- Q6. Customer ranking by lifetime spend (RANK window function)
SELECT
    c.customer_name,
    c.city,
    COUNT(DISTINCT o.order_id)  AS orders_placed,
    SUM(oi.quantity * p.price)  AS total_spent,
    RANK() OVER (ORDER BY SUM(oi.quantity * p.price) DESC) AS spend_rank
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.status = 'Completed'
GROUP BY c.customer_name, c.city
ORDER BY spend_rank;
 
 
-- Q7. Repeat customers (placed more than one completed order)
SELECT
    c.customer_name,
    COUNT(*) AS completed_orders
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
WHERE o.status = 'Completed'
GROUP BY c.customer_name
HAVING COUNT(*) > 1
ORDER BY completed_orders DESC;
 
 
-- Q8. Customers who never completed an order (LEFT JOIN + NULL check)
SELECT
    c.customer_id,
    c.customer_name,
    c.city
FROM customers c
LEFT JOIN orders o
       ON o.customer_id = c.customer_id
      AND o.status = 'Completed'
WHERE o.order_id IS NULL;
 
 
-- Q9. Each customer's first order date and days until their second order
WITH ranked AS (
    SELECT
        customer_id,
        order_date,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS order_num
    FROM orders
    WHERE status = 'Completed'
)
SELECT
    c.customer_name,
    MAX(CASE WHEN r.order_num = 1 THEN r.order_date END) AS first_order,
    MAX(CASE WHEN r.order_num = 2 THEN r.order_date END) AS second_order,
    MAX(CASE WHEN r.order_num = 2 THEN r.order_date END)
      - MAX(CASE WHEN r.order_num = 1 THEN r.order_date END) AS days_between
FROM ranked r
JOIN customers c ON c.customer_id = r.customer_id
GROUP BY c.customer_name
ORDER BY c.customer_name;
 
 
-- Q10. Cancellation and return rate by order status
SELECT
    status,
    COUNT(*) AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM orders
GROUP BY status
ORDER BY orders DESC;
 
