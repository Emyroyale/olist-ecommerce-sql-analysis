-- Olist Brazilian E-Commerce: analysis queries
-- Research question: which product categories and sellers drive the most
-- revenue, and does late delivery measurably hurt customer review scores?
--
-- Run against olist.db (build with build_database.py). All queries filter
-- to order_status = 'delivered' so revenue and delivery-timing figures only
-- reflect orders that actually completed.

-- ============================================================
-- Query 1: Monthly revenue trend with month-over-month growth
-- ============================================================
-- Business question: How is revenue trending month over month, and where
-- did growth accelerate or stall?
--
-- Revenue = sum of order_items.price (freight excluded -- freight is a
-- pass-through shipping cost, not product revenue).
-- Uses a window function (LAG) to compute % change vs. the prior month.

WITH monthly_revenue AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
        ROUND(SUM(oi.price), 2)                        AS revenue,
        COUNT(DISTINCT o.order_id)                     AS orders
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
)
SELECT
    order_month,
    revenue,
    orders,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
        / LAG(revenue) OVER (ORDER BY order_month),
        1
    ) AS pct_change_vs_prior_month
FROM monthly_revenue
ORDER BY order_month;


-- ============================================================
-- Query 2: Top 10 product categories by revenue
-- ============================================================
-- Business question: Which product categories generate the most revenue --
-- and do the highest-revenue categories also have the happiest customers?
--
-- Joins order_items -> products -> category_translation to get English
-- category names (the raw column is Portuguese). Also reports each
-- category's average review score, computed from its own CTE to avoid
-- fan-out from the one-to-many order_items/order_reviews join.

WITH category_revenue AS (
    SELECT
        COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown') AS category,
        SUM(oi.price)             AS revenue,
        COUNT(*)                  AS items_sold
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN category_translation ct ON ct.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY category
),
category_reviews AS (
    SELECT
        COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown') AS category,
        AVG(r.review_score) AS avg_review_score
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN category_translation ct ON ct.product_category_name = p.product_category_name
    JOIN order_reviews r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY category
)
SELECT
    cr.category,
    ROUND(cr.revenue, 2)       AS revenue,
    cr.items_sold,
    ROUND(crev.avg_review_score, 2) AS avg_review_score
FROM category_revenue cr
JOIN category_reviews crev ON crev.category = cr.category
ORDER BY cr.revenue DESC
LIMIT 10;


-- ============================================================
-- Query 3: Delivery delay vs. customer review score
-- ============================================================
-- Business question: Does a late delivery measurably hurt the customer's
-- review score, and how much of our order volume is actually affected?
--
-- delay_days > 0 means the order arrived after its estimated delivery date.
-- Buckets orders with CASE WHEN, then averages review_score per bucket.
-- This is the headline finding: operational performance (did it arrive on
-- time) measured against the customer-experience metric (review score).

WITH delivery AS (
    SELECT
        o.order_id,
        CAST(julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date) AS INTEGER) AS delay_days
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
),
bucketed AS (
    SELECT
        d.order_id,
        r.review_score,
        CASE
            WHEN d.delay_days <= -7 THEN '1. Early (7+ days)'
            WHEN d.delay_days <= 0  THEN '2. On time'
            WHEN d.delay_days <= 7  THEN '3. Late (1-7 days)'
            ELSE                         '4. Very late (8+ days)'
        END AS delivery_bucket
    FROM delivery d
    JOIN order_reviews r ON r.order_id = d.order_id
)
SELECT
    delivery_bucket,
    COUNT(*)                        AS num_orders,
    ROUND(AVG(review_score), 2)     AS avg_review_score,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM bucketed
GROUP BY delivery_bucket
ORDER BY delivery_bucket;


-- ============================================================
-- Query 4: Top 10 sellers by revenue, ranked, with order count and review score
-- ============================================================
-- Business question: Which sellers generate the most revenue, and does
-- being a top earner also mean delivering a good customer experience?
--
-- Demonstrates RANK() alongside aggregation -- useful for "top N per group"
-- style questions. HAVING filters out sellers with too few orders to trust
-- their average score.

WITH seller_stats AS (
    SELECT
        oi.seller_id,
        s.seller_state,
        SUM(oi.price)        AS revenue,
        COUNT(DISTINCT oi.order_id) AS num_orders,
        AVG(r.review_score)  AS avg_review_score
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    JOIN sellers s ON s.seller_id = oi.seller_id
    JOIN order_reviews r ON r.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, s.seller_state
    HAVING COUNT(DISTINCT oi.order_id) >= 20
)
SELECT
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
    seller_id,
    seller_state,
    ROUND(revenue, 2) AS revenue,
    num_orders,
    ROUND(avg_review_score, 2) AS avg_review_score
FROM seller_stats
ORDER BY revenue_rank
LIMIT 10;
