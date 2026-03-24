-- ============================================================
-- Step 1: 正規化テーブル定義
-- ============================================================
-- ECサイトの注文データを第3正規形で設計したテーブル群。
-- このスキーマに大量データを投入し、JOINのコストを体感する。
--
-- 【実行方法】
--   psql -h localhost -p 5555 -U postgres -d db_design -f 01_schema_normalized.sql
-- ============================================================

-- 既存テーブルがあれば削除（再実行用）
DROP TABLE IF EXISTS perf_order_items CASCADE;
DROP TABLE IF EXISTS perf_orders CASCADE;
DROP TABLE IF EXISTS perf_products CASCADE;
DROP TABLE IF EXISTS perf_categories CASCADE;
DROP TABLE IF EXISTS perf_customers CASCADE;

-- ------------------------------------------------------------
-- カテゴリマスタ（20件）
-- ------------------------------------------------------------
CREATE TABLE perf_categories (
    category_id   SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL
);

-- ------------------------------------------------------------
-- 顧客（1万件）
-- ------------------------------------------------------------
CREATE TABLE perf_customers (
    customer_id   SERIAL PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email         VARCHAR(200) NOT NULL,
    prefecture    VARCHAR(10) NOT NULL
);

-- ------------------------------------------------------------
-- 商品（1,000件）
-- ------------------------------------------------------------
CREATE TABLE perf_products (
    product_id   SERIAL PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL,
    category_id  INT NOT NULL REFERENCES perf_categories(category_id),
    unit_price   NUMERIC(10, 0) NOT NULL
);

-- ------------------------------------------------------------
-- 注文（100万件）
-- ------------------------------------------------------------
CREATE TABLE perf_orders (
    order_id    SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES perf_customers(customer_id),
    order_date  DATE NOT NULL
);

-- ------------------------------------------------------------
-- 注文明細（約300万件 ※1注文あたり平均3商品）
-- ------------------------------------------------------------
CREATE TABLE perf_order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id      INT NOT NULL REFERENCES perf_orders(order_id),
    product_id    INT NOT NULL REFERENCES perf_products(product_id),
    quantity      INT NOT NULL,
    unit_price    NUMERIC(10, 0) NOT NULL  -- 注文時点の価格を保持
);
