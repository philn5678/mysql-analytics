-- 3. Operational Efficiency Questions
-- Q: "How accurate are our delivery estimates, and which states have the worst variances?"
-- Why valuable: Highlights areas needing logistics improvement.

SELECT 
    c.customer_state,
    AVG(DATEDIFF(o.order_estimated_delivery_date, o.order_delivered_customer_date)) AS avg_delivery_variance,
    COUNT(*) AS order_count
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY avg_delivery_variance DESC;


-- Q: "Which product categories have the highest profit margins when factoring in shipping costs?"
-- Why valuable: Identifies most profitable products to prioritize.
SELECT 
    t.product_category_name_english,
    SUM(oi.price) AS total_revenue,
    SUM(oi.freight_value) AS total_shipping_cost,
    (SUM(oi.price) - SUM(oi.freight_value)) / SUM(oi.price) AS profit_margin
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_translation t on t.product_category_name = p.product_category_name
GROUP BY 1
HAVING SUM(oi.price) > 1000  -- Filter for meaningful categories
ORDER BY profit_margin DESC;

SELECT 
    t.product_category_name_english,
    COUNT(DISTINCT oi.order_id) AS order_count,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(SUM(oi.freight_value), 2) AS total_shipping_cost,
    ROUND(SUM(oi.price) - SUM(oi.freight_value), 2) AS gross_profit,
    ROUND(
        (SUM(oi.price) - SUM(oi.freight_value)) / 
        NULLIF(SUM(oi.price), 0) * 100,  -- Avoid division by zero
    2) AS profit_margin_pct,
    ROUND(SUM(oi.price) / NULLIF(COUNT(DISTINCT oi.order_id), 0), 2) AS avg_order_value,
    COUNT(DISTINCT oi.product_id) AS unique_products
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id 
JOIN product_category_translation t on t.product_category_name = p.product_category_name -- LEFT JOIN in case some products are missing
GROUP BY p.product_category_name
HAVING COUNT(DISTINCT oi.order_id) > 50  -- Filter for meaningful categories
   AND SUM(oi.price) > 1000  -- Minimum revenue threshold
ORDER BY profit_margin_pct DESC
LIMIT 20;
