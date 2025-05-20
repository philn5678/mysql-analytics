SELECT
    DATE(order_purchase_timestamp) AS purchase_date,
    AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)) 
        AS avg_delivery_time
FROM orders
WHERE order_purchase_timestamp >= '2017-06-01' 
  AND order_purchase_timestamp <= '2018-06-30'
  AND order_delivered_customer_date IS NOT NULL
GROUP BY DATE(order_purchase_timestamp)
ORDER BY purchase_date;