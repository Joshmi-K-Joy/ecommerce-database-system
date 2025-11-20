# 📦 E-Commerce Database Project

This project is a fully designed **E-Commerce Database System** similar to Amazon/Flipkart, built using **MySQL 8.0**.
It includes complete SQL schema, sample data, views, triggers, indexing, and analytical queries.



##  **Project Overview**

The database supports core e-commerce functionalities including:

* User Management
* Product Catalog (categories, products, images)
* Inventory Tracking
* Cart & Checkout
* Orders & Order Items
* Payments
* Delivery Tracking
* Reviews & Ratings
* Product Views & Search Logs
* Analytical Insights (Best sellers, revenue stats, trends)



##  **Database Architecture**

### Main Modules

1. **Users & Addresses**
2. **Product Catalog**
3. **Inventory**
4. **Cart Management**
5. **Orders & Order Items**
6. **Payments**
7. **Delivery Tracking**
8. **Reviews**
9. **Analytics Logging (Views + Searches)**

### Key Concepts Used

* Primary & Foreign Keys
* Constraints & Indexing
* Normalized schema
* Views
* Triggers
* Stored Procedures
* Analytical SQL Queries




##  **Analytics Queries Included**

The SQL file already contains major analysis such as:

* Best-selling products
* Revenue per category
* Monthly revenue trends
* Average rating per product
* Most viewed products
* Most searched keywords
* User order history
* Inventory low-stock reports



##  **Sample Queries**

###  Get Best-Selling Products

```sql
SELECT p.product_name, SUM(oi.quantity) AS total_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_id
ORDER BY total_sold DESC;
```

###  Revenue per Category

```sql
SELECT c.category_name, SUM(oi.quantity * oi.price) AS revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON p.category_id = c.category_id
GROUP BY c.category_name
ORDER BY revenue DESC;
```

---

##  **ERD Overview**

```
Users → Addresses  
Users → Cart → Cart Items  
Users → Orders → Order Items → Products  
Orders → Payments  
Orders → Delivery Tracking  
Products → Reviews  
Products → Inventory  
Products → Product Views  
Search Logs (User searches)
```
