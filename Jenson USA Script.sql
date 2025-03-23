-- Find the total number of products sold by each store along with the store name.
SELECT 
    s.store_name,
    SUM(oi.quantity) AS products_sold
FROM
    stores s
    JOIN orders o ON s.store_id = o.store_id
    JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY 
    s.store_name;

-- Calculate the cumulative sum of quantities sold for each product over time.
WITH product_orders AS (
    SELECT 
        p.product_name,
        o.order_date,
        oi.quantity
    FROM 
        products p
    INNER JOIN order_items oi ON p.product_id = oi.product_id
    INNER JOIN orders o ON oi.order_id = o.order_id
)
SELECT 
    product_name,
    order_date,
    quantity,
    SUM(quantity) OVER (PARTITION BY product_name ORDER BY order_date) AS cumulative_quantity
FROM 
    product_orders
ORDER BY 
    product_name, order_date;

-- Find the product with the highest total sales (quantity * price) for each category.
WITH sales_summary AS (
    SELECT 
        c.category_name, 
        p.product_name, 
        SUM(oi.quantity * oi.list_price) AS sales
    FROM 
        categories c 
        JOIN products p ON c.category_id = p.category_id
        JOIN order_items oi ON oi.product_id = p.product_id
    GROUP BY 
        c.category_name, 
        p.product_name
)
SELECT * 
FROM (
    SELECT 
        *, 
        DENSE_RANK() OVER (PARTITION BY category_name ORDER BY sales DESC) AS rnk 
    FROM 
        sales_summary
) AS ranked_products
WHERE rnk = 1;

-- Find the customer who spent the most money on orders.
SELECT 
    c.customer_id, 
    CONCAT(c.first_name, ' ', c.last_name) AS customer_full_name,
    SUM(oi.quantity * oi.list_price) AS total_sales
FROM 
    customers c 
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY 
    c.customer_id, 
    CONCAT(c.first_name, ' ', c.last_name)
ORDER BY 
    total_sales DESC 
LIMIT 1;

-- Find the highest-priced product for each category name.
SELECT * 
FROM (
    SELECT 
        c.category_name, 
        p.product_name, 
        p.list_price, 
        DENSE_RANK() OVER (PARTITION BY c.category_name ORDER BY p.list_price DESC) AS rnk
    FROM 
        categories c 
        JOIN products p ON c.category_id = p.category_id
) AS ranked_products
WHERE rnk = 1;

-- Find the total number of orders placed by each customer per store.
SELECT 
    c.customer_id, 
    c.first_name, 
    s.store_name, 
    COUNT(o.order_id) AS order_count
FROM 
    customers c 
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    JOIN stores s ON s.store_id = o.store_id
GROUP BY 
    c.customer_id, 
    c.first_name, 
    s.store_name;

-- Find the names of staff members who have not made any sales.
SELECT 
    st.staff_id, 
    CONCAT(st.first_name, ' ', st.last_name) AS fullname, o.order_id
FROM staffs st
LEFT JOIN orders o ON st.staff_id = o.staff_id 
WHERE o.order_id IS NULL
ORDER BY st.staff_id;

-- Find the top 3 most sold products in terms of quantity.
SELECT 
    p.product_id, 
    p.product_name, 
    SUM(oi.quantity) AS total_quantity
FROM 
    products p
    JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY 
    p.product_id, 
    p.product_name
ORDER BY 
    total_quantity DESC
LIMIT 3;

-- Find the median value of the price list.  
WITH a AS (
    SELECT 
        list_price,
        ROW_NUMBER() OVER(ORDER BY list_price) rn,
        COUNT(*) OVER() n 
    FROM products
)
SELECT 
    CASE 
        WHEN MOD(n,2) = 0 THEN (SELECT AVG(list_price) FROM a WHERE rn IN ((n/2), (n/2)+1))
        ELSE (SELECT list_price FROM a WHERE rn = ((n+1)/2))
    END AS median
FROM a LIMIT 1;

-- List all products that have never been ordered (use EXISTS).
SELECT p.product_id, p.product_name
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
);

-- List the names of staff members who have made more sales than the average number of sales by all staff members.
WITH staff_sales AS (
    SELECT 
        st.staff_id,
        st.first_name,
        COALESCE(SUM(oi.quantity * oi.list_price), 0) AS total_sales
    FROM staffs st
    LEFT JOIN orders o USING (staff_id)
    LEFT JOIN order_items oi USING (order_id)
    GROUP BY st.staff_id, st.first_name
)
SELECT *
FROM staff_sales
WHERE total_sales > (SELECT AVG(total_sales) FROM staff_sales);

-- Identify the customers who have ordered all types of products (i.e., from every category).
SELECT c.customer_id,
       c.first_name,
       COUNT(oi.product_id) AS total_orders
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
GROUP BY c.customer_id, c.first_name
HAVING COUNT(DISTINCT p.category_id) = (SELECT COUNT(*) FROM categories);
