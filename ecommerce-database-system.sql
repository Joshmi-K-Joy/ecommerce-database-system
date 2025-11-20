-- Full E-Commerce Project SQL
-- File: ecommerce_full_project.sql
-- Contains: schema, indexes, triggers, views, sample data, analytics queries, stored procedures
-- Database: ecommerce_db

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db;
USE ecommerce_db;

-- ========================
-- SCHEMA
-- ========================

-- Users
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(15) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE addresses (
    address_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    house_no VARCHAR(100),
    street VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    country VARCHAR(50) DEFAULT 'India',
    address_type ENUM('Home','Office') DEFAULT 'Home',
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Categories & Products
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255)
);

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    brand VARCHAR(100),
    price DECIMAL(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL
);

CREATE TABLE product_images (
    image_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    image_url VARCHAR(1024) NOT NULL,
    is_primary TINYINT(1) DEFAULT 0,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

CREATE TABLE inventory (
    product_id INT PRIMARY KEY,
    stock INT DEFAULT 0,
    reserved INT DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- Cart
CREATE TABLE cart (
    cart_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE cart_items (
    cart_item_id INT AUTO_INCREMENT PRIMARY KEY,
    cart_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cart_id) REFERENCES cart(cart_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
    UNIQUE KEY uk_cart_product (cart_id, product_id)
);

-- Orders
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    address_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(12,2) NOT NULL,
    shipping_amount DECIMAL(10,2) DEFAULT 0,
    status ENUM('Pending','Processing','Shipped','Delivered','Cancelled','Refunded') DEFAULT 'Pending',
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    FOREIGN KEY (address_id) REFERENCES addresses(address_id) ON DELETE SET NULL,
    INDEX idx_orders_user_time (user_id, order_date)
);

CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    qty INT NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL,
    total_price DECIMAL(12,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE RESTRICT,
    INDEX idx_order_product (order_id, product_id)
);

CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    payment_method ENUM('UPI','Card','NetBanking','COD') NOT NULL,
    payment_status ENUM('INITIATED','SUCCESS','FAILED','REFUNDED') DEFAULT 'INITIATED',
    amount DECIMAL(12,2) NOT NULL,
    paid_at TIMESTAMP NULL,
    gateway_response JSON,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    INDEX idx_payment_order (order_id)
);

CREATE TABLE shipments (
    shipment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    carrier VARCHAR(100),
    tracking_number VARCHAR(200),
    shipped_at TIMESTAMP NULL,
    delivered_at TIMESTAMP NULL,
    status VARCHAR(50) DEFAULT 'NOT_SHIPPED',
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- Reviews & Analytics
CREATE TABLE reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    user_id INT NOT NULL,
    rating TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    title VARCHAR(255),
    body TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_review_product (product_id)
);

CREATE TABLE product_views (
    view_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    user_id INT,
    session_id VARCHAR(255),
    viewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_pv_product_time (product_id, viewed_at)
);

CREATE TABLE product_search_logs (
    search_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    query_text VARCHAR(500),
    result_count INT,
    searched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_search_text (query_text(100)),
    INDEX idx_search_time (searched_at)
);

-- ========================
-- INDEXES for performance (additional)
-- ========================
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_inventory_stock ON inventory(stock);

-- ========================
-- TRIGGERS
-- ========================
DELIMITER $$
CREATE TRIGGER trg_order_item_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  -- decrement stock and reserved when an order item is created
  UPDATE inventory
  SET stock = GREATEST(stock - NEW.qty, 0),
      reserved = GREATEST(reserved - NEW.qty, 0),
      last_updated = NOW()
  WHERE product_id = NEW.product_id;
END$$
DELIMITER ;

-- ========================
-- STORED PROCEDURES (example)
-- ========================
DELIMITER $$
CREATE PROCEDURE sp_create_order_from_cart(IN in_cart_id INT, IN in_user_id INT, OUT out_order_id INT)
BEGIN
  DECLARE v_total DECIMAL(12,2) DEFAULT 0;
  START TRANSACTION;
    SELECT SUM(ci.qty * ci.unit_price) INTO v_total
    FROM cart_items ci
    WHERE ci.cart_id = in_cart_id;

    IF v_total IS NULL THEN
      SET out_order_id = NULL;
      ROLLBACK;
      LEAVE proc_end;
    END IF;

    INSERT INTO orders (user_id, total_amount, shipping_amount, order_date)
    VALUES (in_user_id, v_total, 0, NOW());
    SET out_order_id = LAST_INSERT_ID();

    INSERT INTO order_items (order_id, product_id, qty, unit_price, total_price)
    SELECT out_order_id, product_id, quantity, unit_price, quantity*unit_price FROM cart_items WHERE cart_id = in_cart_id;

    DELETE FROM cart_items WHERE cart_id = in_cart_id;
  COMMIT;
  proc_end: BEGIN END;
END$$
DELIMITER ;

-- ========================
-- VIEWS (analytics)
-- ========================
CREATE OR REPLACE VIEW vw_best_selling_30d AS
SELECT p.product_id, p.product_name, COALESCE(SUM(oi.qty),0) AS total_qty_sold, COALESCE(SUM(oi.total_price),0) AS revenue
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_date >= NOW() - INTERVAL 30 DAY
  AND o.status IN ('Processing','Shipped','Delivered')
GROUP BY p.product_id, p.product_name
ORDER BY total_qty_sold DESC;

CREATE OR REPLACE VIEW vw_revenue_per_category AS
SELECT c.category_id, c.category_name AS category_name, COALESCE(SUM(oi.total_price),0) AS revenue, COUNT(DISTINCT o.order_id) as orders_count
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status IN ('Processing','Shipped','Delivered')
GROUP BY c.category_id, c.category_name
ORDER BY revenue DESC;

-- ========================
-- SAMPLE DATA
-- ========================
-- Users
INSERT INTO users (full_name, email, phone, password_hash) VALUES
('Rahul Sharma', 'rahul@gmail.com', '9876543210', 'pass123'),
('Anjali Gupta', 'anjali@gmail.com', '9876501234', 'pass123'),
('Vikram Singh', 'vikram@gmail.com', '9812345678', 'pass123');

-- Addresses
INSERT INTO addresses (user_id, house_no, street, city, state, pincode, address_type) VALUES
(1, '101', 'MG Road', 'Bengaluru', 'Karnataka', '560001', 'Home'),
(2, '22B', 'Park Street', 'Kolkata', 'West Bengal', '700016', 'Office'),
(3, '78', 'Marine Drive', 'Mumbai', 'Maharashtra', '400001', 'Home');

-- Categories
INSERT INTO categories (category_name, description) VALUES
('Mobiles', 'Smartphones and accessories'),
('Laptops', 'Computers and laptops'),
('Fashion', 'Clothes and accessories');

-- Products
INSERT INTO products (category_id, product_name, brand, price, description) VALUES
(1, 'iPhone 14', 'Apple', 79999.00, 'Latest Apple iPhone'),
(1, 'Samsung Galaxy S23', 'Samsung', 69999.00, 'Flagship Samsung phone'),
(2, 'MacBook Air M1', 'Apple', 89999.00, 'Apple laptop'),
(3, 'Men T-Shirt', 'HRX', 999.00, 'Cotton T-shirt');

-- Product Images
INSERT INTO product_images (product_id, image_url, is_primary) VALUES
(1, 'https://example.com/iphone14.jpg', 1),
(2, 'https://example.com/galaxy_s23.jpg', 1),
(3, 'https://example.com/macbook_air.jpg', 1),
(4, 'https://example.com/tshirt.jpg', 1);

-- Inventory
INSERT INTO inventory (product_id, stock, reserved) VALUES
(1,50,0),
(2,40,0),
(3,20,0),
(4,200,0);

-- Cart & Cart Items (for demo)
INSERT INTO cart (user_id, created_at) VALUES (1, NOW()), (2, NOW());
INSERT INTO cart_items (cart_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 79999.00),
(1, 2, 1, 69999.00),
(2, 4, 2, 999.00);

-- Orders & Order Items
INSERT INTO orders (user_id, address_id, total_amount, shipping_amount, status) VALUES
(1,1,79999.00,0,'Delivered'),
(1,1,169998.00,0,'Delivered'),
(2,2,999.00,0,'Delivered'),
(3,3,89999.00,0,'Shipped');

INSERT INTO order_items (order_id, product_id, qty, unit_price, total_price) VALUES
(1,1,1,79999.00,79999.00),
(2,1,1,79999.00,79999.00),
(2,2,1,69999.00,69999.00),
(3,4,1,999.00,999.00),
(4,3,1,89999.00,89999.00);

-- Payments
INSERT INTO payments (order_id, payment_method, payment_status, amount, paid_at) VALUES
(1,'Card','SUCCESS',79999.00,NOW()),
(2,'Card','SUCCESS',169998.00,NOW()),
(3,'COD','SUCCESS',999.00,NOW()),
(4,'UPI','INITIATED',89999.00,NULL);

-- Shipments
INSERT INTO shipments (order_id, carrier, tracking_number, shipped_at, status) VALUES
(1,'BlueDart','BD123',NOW(),'Delivered'),
(2,'FedEx','FD456',NOW(),'Delivered'),
(4,'DHL','DH789',NOW(),'Shipped');

-- Reviews
INSERT INTO reviews (product_id, user_id, rating, title, body) VALUES
(1,1,5,'Excellent','Excellent phone!'),
(2,2,4,'Good','Very good'),
(3,3,5,'Fast Laptop','Super fast laptop'),
(4,1,3,'Okay','Average quality');

-- Product Views
INSERT INTO product_views (product_id, user_id, session_id) VALUES
(1,1,'sess1'),
(1,2,'sess2'),
(1,3,'sess3'),
(2,1,'sess1'),
(3,2,'sess2');

-- Product Search Logs
INSERT INTO product_search_logs (user_id, query_text, result_count) VALUES
(1,'iPhone',10),
(1,'Apple',8),
(2,'Samsung S23',5),
(3,'Laptop',12),
(3,'MacBook',4),
(1,'iPhone',10);

-- ========================
-- ANALYTICS QUERIES (examples)
-- ========================

-- 1) Best-selling products (all time by qty)
-- Top 10 by quantity sold
SELECT p.product_id, p.product_name, COALESCE(SUM(oi.qty),0) AS qty_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.status IN ('Processing','Shipped','Delivered')
GROUP BY p.product_id, p.product_name
ORDER BY qty_sold DESC
LIMIT 10;

-- 2) Revenue per category
SELECT c.category_id, c.category_name, COALESCE(SUM(oi.total_price),0) AS revenue
FROM categories c
LEFT JOIN products p ON p.category_id = c.category_id
LEFT JOIN order_items oi ON oi.product_id = p.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.status IN ('Processing','Shipped','Delivered')
GROUP BY c.category_id, c.category_name
ORDER BY revenue DESC;

-- 3) User order history with items (replace :user_id)
-- Example for user_id = 1
SELECT o.order_id, o.order_date, o.status, o.total_amount, oi.order_item_id, oi.product_id, p.product_name, oi.qty, oi.unit_price, oi.total_price
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.user_id = 1
ORDER BY o.order_date DESC, oi.order_item_id;

-- 4) Most viewed products (last 30 days)
SELECT p.product_id, p.product_name, COUNT(*) AS views
FROM product_views pv
JOIN products p ON pv.product_id = p.product_id
WHERE pv.viewed_at >= NOW() - INTERVAL 30 DAY
GROUP BY p.product_id, p.product_name
ORDER BY views DESC
LIMIT 20;

-- 5) Most searched queries
SELECT query_text, COUNT(*) AS freq
FROM product_search_logs
GROUP BY query_text
ORDER BY freq DESC
LIMIT 20;

-- 6) Combine views and sales (last 30 days)
SELECT p.product_id, p.product_name,
  COALESCE(pv.views,0) AS views_last_30d,
  COALESCE(sales.qty_sold,0) AS qty_sold_last_30d
FROM products p
LEFT JOIN (
  SELECT product_id, COUNT(*) AS views
  FROM product_views
  WHERE viewed_at >= NOW() - INTERVAL 30 DAY
  GROUP BY product_id
) pv ON p.product_id = pv.product_id
LEFT JOIN (
  SELECT oi.product_id, SUM(oi.qty) AS qty_sold
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  WHERE o.order_date >= NOW() - INTERVAL 30 DAY
    AND o.status IN ('Processing','Shipped','Delivered')
  GROUP BY oi.product_id
) sales ON p.product_id = sales.product_id
ORDER BY qty_sold_last_30d DESC, views_last_30d DESC
LIMIT 50;

-- 7) Average rating per product
SELECT p.product_id, p.product_name, AVG(r.rating) AS avg_rating, COUNT(r.review_id) AS reviews_count
FROM products p
LEFT JOIN reviews r ON p.product_id = r.product_id
GROUP BY p.product_id, p.product_name
ORDER BY avg_rating DESC;

-- 8) Revenue trend (monthly) - last 6 months
SELECT DATE_FORMAT(o.order_date, '%Y-%m') AS year_month, SUM(o.total_amount) AS revenue
FROM orders o
WHERE o.status IN ('Processing','Shipped','Delivered')
  AND o.order_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY year_month
ORDER BY year_month;

-- ========================
-- END OF FILE
-- ========================
