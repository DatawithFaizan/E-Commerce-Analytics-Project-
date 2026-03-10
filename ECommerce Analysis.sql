CREATE DATABASE ecommerce;
USE ecommerce;
-- Orders Table
CREATE TABLE orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
);
-- Order Item Table
CREATE TABLE order_items (
    order_id VARCHAR(50),
    order_item_id INT,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date DATETIME,
    price DECIMAL(10,2),
    freight_value DECIMAL(10,2)
);
-- Payments Table
CREATE TABLE payments (
    order_id VARCHAR(50),
    payment_sequential INT,
    payment_type VARCHAR(50),
    payment_installments INT,
    payment_value DECIMAL(10,2)
);
-- Reviews Table
CREATE TABLE reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
);
-- Customers Table
CREATE TABLE customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(5)
);
-- Products Table
CREATE TABLE products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);
-- Sellers Table
CREATE TABLE sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state VARCHAR(5)
);
-- Geolocation Raw Table
CREATE TABLE geolocation_raw (
    geolocation_zip_code_prefix INT,
    geolocation_lat DOUBLE,
    geolocation_lng DOUBLE,
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(5)
);
-- Product Category Translation Table
CREATE TABLE product_category_name_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);
select * from orders;
SELECT 'orders', COUNT(*) FROM orders UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items UNION ALL
SELECT 'payments', COUNT(*) FROM payments UNION ALL
SELECT 'reviews', COUNT(*) FROM reviews UNION ALL
SELECT 'customers', COUNT(*) FROM customers UNION ALL
SELECT 'products', COUNT(*) FROM products UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers UNION ALL
SELECT 'geolocation_raw', COUNT(*) FROM geolocation_raw UNION ALL
SELECT 'translation', COUNT(*) FROM product_category_name_translation;

CREATE TABLE dim_geolocation AS
SELECT
    geolocation_zip_code_prefix AS zip_code_prefix,
    MIN(geolocation_city) AS city,
    MIN(geolocation_state) AS state
FROM geolocation_raw
GROUP BY geolocation_zip_code_prefix;
ALTER TABLE dim_geolocation
ADD PRIMARY KEY (zip_code_prefix);
SELECT * FROM dim_geolocation LIMIT 10;

CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_items_order ON order_items(order_id);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_reviews_order ON reviews(order_id);
CREATE INDEX idx_product_category ON products(product_category_name);

-- 1: Weekday vs Weekend Payment Statistics
SELECT CASE WHEN DAYOFWEEK(o.order_purchase_timestamp) IN (1,7)
THEN 'Weekend'
ELSE 
'Weekday'END AS day_type,
COUNT(DISTINCT o.order_id) AS total_orders,
SUM(p.payment_value) AS total_payment_value,
ROUND(AVG(p.payment_value),2) AS avg_payment_value
FROM orders o
JOIN payments p ON o.order_id = p.order_id
GROUP BY day_type;

-- 2: Count of Orders with Review Score 5 & Payment Type = Credit Card
SELECT COUNT(DISTINCT o.order_id) AS five_star_credit_card_orders
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
JOIN payments p ON o.order_id = p.order_id
WHERE r.review_score = 5 
AND p.payment_type = 'credit_card';

-- 3: Most frequently used payment method
SELECT payment_type,
COUNT(*) AS usage_count,
ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM payments WHERE payment_type <> 'not_defined'),2) AS percentage
FROM payments
WHERE payment_type <> 'not_defined'
GROUP BY payment_type
ORDER BY usage_count DESC;

-- 4: Average Order Price & Average Payment Amount for Customers in São Paulo (SP)
SELECT ROUND(AVG(oi.price),2) AS avg_order_price, ROUND(AVG(p.payment_value),2) AS avg_payment_amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN payments p ON o.order_id = p.order_id
WHERE c.customer_state = 'SP';

-- 5: Relationship Between Shipping Days and Review Scores
SELECT r.review_score, ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)),2) AS avg_shipping_days,
COUNT(*) AS total_orders
FROM orders o
JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score;

-- 6: Top 10 Cities by Highest Total Payment Value
SELECT c.customer_city, SUM(p.payment_value) AS total_payment
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN payments p ON o.order_id = p.order_id
GROUP BY c.customer_city
ORDER BY total_payment DESC
LIMIT 10;

-- 7: Top 10 Most Expensive Products By Average Price
SELECT pr.product_id, MIN(t.product_category_name_english) AS category_english,ROUND(AVG(oi.price),2) AS avg_price
FROM order_items oi
JOIN products pr 
ON oi.product_id = pr.product_id
LEFT JOIN product_category_name_translation t
ON pr.product_category_name = t.product_category_name
GROUP BY pr.product_id
ORDER BY avg_price DESC
LIMIT 10;

-- 8: Top 10 customers by TOTAL payment value
SELECT o.customer_id, ROUND(SUM(p.payment_value),2) AS total_payment,
COUNT(DISTINCT p.order_id) AS orders_count
FROM payments p
JOIN orders o ON p.order_id = o.order_id
GROUP BY o.customer_id
ORDER BY total_payment DESC
LIMIT 10;

-- 9: Seller Performance – Top 10 Sellers With Maximum Orders
SELECT s.seller_id, MIN(s.seller_city) AS seller_city,
MIN(s.seller_state) AS seller_state,
COUNT(DISTINCT oi.order_id) AS orders_count
FROM order_items oi
JOIN sellers s ON oi.seller_id = s.seller_id
GROUP BY s.seller_id
ORDER BY orders_count DESC
LIMIT 10;

-- 10: Average Review Score by Product Category
SELECT t.product_category_name_english AS category, ROUND(AVG(r.review_score), 2) AS avg_review_score,
COUNT(*) AS review_count
FROM order_items oi
JOIN products pr ON oi.product_id = pr.product_id
LEFT JOIN product_category_name_translation t ON pr.product_category_name = t.product_category_name
JOIN reviews r ON oi.order_id = r.order_id
GROUP BY t.product_category_name_english
HAVING review_count >= 10
ORDER BY avg_review_score DESC;









