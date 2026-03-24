-- ============================================================
-- Step 3: インデックス追加 + 再計測
-- ============================================================
-- JOINやWHEREで使われるカラムにインデックスを追加し、
-- 同じクエリのパフォーマンスがどう変わるかを計測する。
--
-- 【実行方法】
--   psql -h localhost -p 5555 -U postgres -d db_design
--   \timing on
--   \i 04_add_indexes.sql
--
-- 【注意】
--   PRIMARY KEY には自動でインデックスが作成されているが、
--   外部キー（FK）には自動では作成されない。これがポイント。
-- ============================================================

-- ============================================================
-- Part A: インデックス作成
-- ============================================================

-- perf_order_items: 最も行数が多く効果が大きいテーブル
CREATE INDEX idx_order_items_order_id   ON perf_order_items(order_id);
CREATE INDEX idx_order_items_product_id ON perf_order_items(product_id);

-- perf_orders: customer_id での絞り込み、order_date での範囲検索
CREATE INDEX idx_orders_customer_id ON perf_orders(customer_id);
CREATE INDEX idx_orders_order_date  ON perf_orders(order_date);

-- perf_products: category_id でのJOIN
CREATE INDEX idx_products_category_id ON perf_products(category_id);

-- 統計情報を更新
ANALYZE perf_order_items;
ANALYZE perf_orders;
ANALYZE perf_products;

-- ============================================================
-- Part B: 同じクエリを再計測
-- ============================================================
-- ベースライン（03_queries_baseline.sql）と同じクエリを実行し、
-- Execution Time を比較する。

-- ============================================================
-- クエリ1: 月別・カテゴリ別の売上集計（再計測）
-- ============================================================

EXPLAIN ANALYZE
SELECT
    TO_CHAR(o.order_date, 'YYYY-MM') AS year_month,
    c.category_name,
    SUM(oi.quantity * oi.unit_price) AS total_sales,
    COUNT(DISTINCT o.order_id) AS order_count
FROM perf_order_items oi
JOIN perf_orders o ON o.order_id = oi.order_id
JOIN perf_products p ON p.product_id = oi.product_id
JOIN perf_categories c ON c.category_id = p.category_id
GROUP BY TO_CHAR(o.order_date, 'YYYY-MM'), c.category_name
ORDER BY year_month, total_sales DESC;

-- ============================================================
-- クエリ2: 特定顧客の注文履歴（再計測）
-- ============================================================

EXPLAIN ANALYZE
SELECT
    o.order_id,
    o.order_date,
    p.product_name,
    oi.quantity,
    oi.unit_price,
    oi.quantity * oi.unit_price AS subtotal
FROM perf_orders o
JOIN perf_order_items oi ON oi.order_id = o.order_id
JOIN perf_products p ON p.product_id = oi.product_id
WHERE o.customer_id = 42
  AND o.order_date >= '2025-01-01'
ORDER BY o.order_date DESC, o.order_id;

-- ============================================================
-- クエリ3: 特定期間の売上集計（範囲検索・再計測）
-- ============================================================

EXPLAIN ANALYZE
SELECT
    c.category_name,
    SUM(oi.quantity * oi.unit_price) AS total_sales,
    COUNT(DISTINCT o.order_id) AS order_count
FROM perf_orders o
JOIN perf_order_items oi ON oi.order_id = o.order_id
JOIN perf_products p ON p.product_id = oi.product_id
JOIN perf_categories c ON c.category_id = p.category_id
WHERE o.order_date BETWEEN '2025-04-01' AND '2025-06-30'
GROUP BY c.category_name
ORDER BY total_sales DESC;

-- ============================================================
-- クエリ4: 特定都道府県の注文件数（低カーディナリティ・再計測）
-- ============================================================
-- perf_customers.prefecture にもインデックスを追加
CREATE INDEX IF NOT EXISTS idx_customers_prefecture ON perf_customers(prefecture);
ANALYZE perf_customers;

EXPLAIN ANALYZE
SELECT
    cu.customer_id,
    cu.customer_name,
    COUNT(o.order_id) AS order_count,
    SUM(oi.quantity * oi.unit_price) AS total_sales
FROM perf_customers cu
JOIN perf_orders o ON o.customer_id = cu.customer_id
JOIN perf_order_items oi ON oi.order_id = o.order_id
WHERE cu.prefecture = '東京都'
GROUP BY cu.customer_id, cu.customer_name
ORDER BY total_sales DESC;
