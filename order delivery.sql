WITH top_cities AS (
    SELECT 
        c.customer_city,
        COUNT(o.order_id) AS order_count
    FROM orders o
    JOIN customer c ON o.customer_id = c.customer_id
    GROUP BY c.customer_city
    ORDER BY order_count DESC
    LIMIT 10
)

SELECT 
    c.customer_city,
    c.customer_state,
    COUNT(o.order_id) AS total_orders,
    -- Approval time (purchase to approval)
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp, o.order_approved_at)), 2) AS avg_approval_days,
    
    -- Processing time (approval to carrier handoff)
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_approved_at, o.order_delivered_carrier_date)), 2) AS avg_processing_days,
    
    -- Transit time (carrier handoff to delivery)
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_delivered_carrier_date, o.order_delivered_customer_date)), 2) AS avg_transit_days,
    
    -- Total delivery time (purchase to delivery)
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date)), 2) AS avg_total_delivery_days,
    
    -- Estimated delivery time (purchase to estimated delivery)
    ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_delivered_customer_date, o.order_estimated_delivery_date)), 2) AS avg_estimated_delivery_days,
    
    -- Actual vs estimated delivery difference
    ROUND(AVG(
        TIMESTAMPDIFF(DAY, o.order_delivered_customer_date, o.order_estimated_delivery_date)
    ), 2) AS avg_days_early_or_late,
    
    -- On-time performance (delivery vs estimated)
    ROUND(AVG(CASE 
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1
        ELSE 0
    END) * 100, 2) AS on_time_percentage
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
JOIN top_cities tc ON c.customer_city = tc.customer_city
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_approved_at IS NOT NULL
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_city, c.customer_state
ORDER BY total_orders DESC;


SELECT
    DATE(o.order_purchase_timestamp) AS purchase_date,
	ROUND(AVG(TIMESTAMPDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date)), 2) AS avg_total_delivery_days
FROM orders o
WHERE order_purchase_timestamp >= '2017-06-01' AND order_purchase_timestamp <= '2018-06-30'
GROUP BY DATE(order_purchase_timestamp)
order by purchase_date ;


-- KPIs for delivery 
/* average delivery time, on time delivery rates, Late Delivery Variance, total sellers and total customers
*/
SELECT -- on time delivery rates
    ROUND(100 * SUM(CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 1 ELSE 0 END) / 
          COUNT(*), 2) AS on_time_delivery_rate
FROM orders
WHERE order_status = 'delivered';

SELECT  -- average delivery time 
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 2) AS avg_delivery_days
FROM orders;

SELECT -- Late Delivery Variance 
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date)), 2) AS avg_late_days
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date > order_estimated_delivery_date;
  
  SELECT 
    c.customer_state,
    COUNT(*) AS total_orders,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 2) AS avg_delivery_days,
    ROUND(100 * SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 1 ELSE 0 END) / 
          COUNT(*), 2) AS late_delivery_rate
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY late_delivery_rate DESC;

select count(distinct seller_id) as sellers
from sellers;


select count(distinct customer_unique_id) as customers
from customer;

SELECT 
    'on_time_delivery_rate' AS metric_name,
    ROUND(100 * SUM(CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 1 ELSE 0 END) / 
          COUNT(*), 2) AS metric_value,
    '%' AS unit
FROM orders
WHERE order_status = 'delivered'

UNION ALL

SELECT 
    'avg_delivery_days',
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 2),
    'days'
FROM orders
WHERE order_status = 'delivered'

UNION ALL

SELECT 
    'avg_late_days',
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date)), 2),
    'days'
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date > order_estimated_delivery_date

UNION ALL

SELECT 
    'total_sellers',
    COUNT(DISTINCT seller_id),
    'sellers'
   
FROM sellers

UNION ALL

SELECT 
    'total_customers',
    COUNT(DISTINCT customer_unique_id),
    'customers'
FROM customer;