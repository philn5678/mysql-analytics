-- Pre-calculate max order date
WITH max_order_date AS (
    SELECT MAX(order_purchase_timestamp) AS max_date 
    FROM orders 
    WHERE order_status = 'delivered'
),

-- RFM Base
rfm_base AS (
    SELECT
        c.customer_unique_id,
        DATEDIFF((SELECT max_date FROM max_order_date), MAX(o.order_purchase_timestamp)) AS recency,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price + COALESCE(oi.freight_value, 0)) AS monetary,
        c.customer_state,
        c.customer_city
    FROM customer c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_state, c.customer_city
),

-- RFM Scores
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM rfm_base
),

-- Final segments
customer_segments AS (
    SELECT
        *,
        CASE
            WHEN r_score = 5 AND f_score = 5 AND m_score = 5 THEN 'Champions'
            WHEN r_score >= 4 AND f_score >= 4 THEN 'Loyal Customers'
            WHEN r_score = 5 AND frequency = 1 THEN 'New Customers'
            WHEN r_score <= 2 AND m_score >= 4 THEN 'At Risk (High Value)'
            WHEN r_score <= 2 THEN 'Hibernating'
            ELSE 'Potential Loyalists'
        END AS segment,
        ROUND(monetary / NULLIF(frequency, 0), 2) AS avg_order_value
    FROM rfm_scores
),

-- First purchase
first_purchase AS (
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_purchase_date
    FROM customer c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
),

-- Avg review
avg_review AS (
    SELECT 
        c.customer_unique_id,
        ROUND(AVG(r.review_score), 2) AS avg_review_score
    FROM customer c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_reviews r ON o.order_id = r.order_id
    GROUP BY c.customer_unique_id
),

-- Payment preference
payment_pref AS (
    SELECT customer_unique_id, payment_type
    FROM (
        SELECT 
            c.customer_unique_id,
            op.payment_type,
            COUNT(*) AS cnt,
            ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY COUNT(*) DESC) AS rn
        FROM customer c
        JOIN orders o ON c.customer_id = o.customer_id
        JOIN order_payments op ON o.order_id = op.order_id
        GROUP BY c.customer_unique_id, op.payment_type
    ) ranked
    WHERE rn = 1
),

-- Top 3 categories
top_categories AS (
    SELECT customer_unique_id, 
           GROUP_CONCAT(product_category_name ORDER BY cnt DESC SEPARATOR ', ') AS top_categories
    FROM (
        SELECT 
            c.customer_unique_id,
            p.product_category_name,
            COUNT(*) AS cnt,
            ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id, p.product_category_name ORDER BY COUNT(*) DESC) AS rn
        FROM customer c
        JOIN orders o ON c.customer_id = o.customer_id
        JOIN order_items oi ON o.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        GROUP BY c.customer_unique_id, p.product_category_name
    ) ranked
    GROUP BY customer_unique_id
)

-- Final SELECT
SELECT 
    cs.*,
    fp.first_purchase_date,
    ar.avg_review_score,
    pp.payment_type AS preferred_payment_method,
    tc.top_categories,
    concat(r_score,f_score,m_score) as rfm_score
FROM customer_segments cs
LEFT JOIN first_purchase fp ON cs.customer_unique_id = fp.customer_unique_id
LEFT JOIN avg_review ar ON cs.customer_unique_id = ar.customer_unique_id
LEFT JOIN payment_pref pp ON cs.customer_unique_id = pp.customer_unique_id
LEFT JOIN top_categories tc ON cs.customer_unique_id = tc.customer_unique_id



-- total customer per purchase freqency
WITH customer_purchase_counts AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS purchase_count
    FROM 
        orders o
    JOIN 
        customer c ON o.customer_id = c.customer_id
    WHERE 
        o.order_status = 'delivered'  -- Only count completed orders
    GROUP BY 
        c.customer_unique_id
)

SELECT 
    purchase_count AS Frequency,
    COUNT(customer_unique_id) AS total_customers
FROM 
    customer_purchase_counts
GROUP BY 
    purchase_count
ORDER BY 
    purchase_count;
