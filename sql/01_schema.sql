-- Olist Brazilian E-Commerce: schema
-- Mirrors the relational structure of the source dataset:
-- orders <-> customers, orders <-> order_items <-> products/sellers,
-- orders <-> payments, orders <-> reviews.

CREATE TABLE customers (
    customer_id             TEXT PRIMARY KEY,
    customer_unique_id      TEXT,
    customer_zip_code_prefix TEXT,
    customer_city           TEXT,
    customer_state          TEXT
);

CREATE TABLE orders (
    order_id                      TEXT PRIMARY KEY,
    customer_id                   TEXT REFERENCES customers(customer_id),
    order_status                  TEXT,
    order_purchase_timestamp      TEXT,
    order_approved_at             TEXT,
    order_delivered_carrier_date  TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

CREATE TABLE sellers (
    seller_id             TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city           TEXT,
    seller_state          TEXT
);

CREATE TABLE products (
    product_id                TEXT PRIMARY KEY,
    product_category_name     TEXT,
    product_name_lenght       REAL,
    product_description_lenght REAL,
    product_photos_qty        REAL,
    product_weight_g          REAL,
    product_length_cm         REAL,
    product_height_cm         REAL,
    product_width_cm          REAL
);

CREATE TABLE category_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

CREATE TABLE order_items (
    order_id            TEXT REFERENCES orders(order_id),
    order_item_id       INTEGER,
    product_id          TEXT REFERENCES products(product_id),
    seller_id           TEXT REFERENCES sellers(seller_id),
    shipping_limit_date TEXT,
    price               REAL,
    freight_value       REAL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id             TEXT REFERENCES orders(order_id),
    payment_sequential   INTEGER,
    payment_type         TEXT,
    payment_installments INTEGER,
    payment_value        REAL,
    PRIMARY KEY (order_id, payment_sequential)
);

-- Note: review_id is NOT unique in the source data (827 of ~100k rows reuse
-- an existing review_id -- likely re-submitted/updated reviews). It is kept
-- as a plain column rather than a primary key for that reason; see README.
CREATE TABLE order_reviews (
    review_id               TEXT,
    order_id                TEXT REFERENCES orders(order_id),
    review_score            INTEGER,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TEXT,
    review_answer_timestamp TEXT
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_order_items_seller ON order_items(seller_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_reviews_order ON order_reviews(order_id);
CREATE INDEX idx_reviews_review_id ON order_reviews(review_id);
CREATE INDEX idx_payments_order ON order_payments(order_id);
