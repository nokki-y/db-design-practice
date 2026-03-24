-- ============================================================
-- Step 1（続き）: テストデータ生成
-- ============================================================
-- PostgreSQL の generate_series() と random() を使い、
-- 外部ツールなしでSQLだけで大量データを投入する。
--
-- 【実行方法】
--   psql -h localhost -p 5555 -U postgres -d db_design -f 02_generate_data.sql
--
-- 【所要時間の目安】
--   数分程度（マシンスペックによる）
-- ============================================================

-- ============================================================
-- カテゴリ（20件）
-- ============================================================
INSERT INTO perf_categories (category_name)
VALUES
    ('家電'), ('書籍'), ('食品'), ('衣類'), ('スポーツ'),
    ('ゲーム'), ('音楽'), ('家具'), ('文房具'), ('コスメ'),
    ('ペット用品'), ('DIY工具'), ('カー用品'), ('ベビー用品'), ('ガーデニング'),
    ('キッチン用品'), ('健康食品'), ('旅行用品'), ('楽器'), ('アウトドア');

-- ============================================================
-- 顧客（1万件）
-- ============================================================
INSERT INTO perf_customers (customer_name, email, prefecture)
SELECT
    '顧客_' || g.id,
    'user' || g.id || '@example.com',
    (ARRAY[
        '北海道','青森県','岩手県','宮城県','秋田県','山形県','福島県',
        '茨城県','栃木県','群馬県','埼玉県','千葉県','東京都','神奈川県',
        '新潟県','富山県','石川県','福井県','山梨県','長野県',
        '岐阜県','静岡県','愛知県','三重県','滋賀県','京都府','大阪府',
        '兵庫県','奈良県','和歌山県','鳥取県','島根県','岡山県','広島県',
        '山口県','徳島県','香川県','愛媛県','高知県','福岡県',
        '佐賀県','長崎県','熊本県','大分県','宮崎県','鹿児島県','沖縄県'
    ])[1 + (random() * 46)::int]
FROM generate_series(1, 10000) AS g(id);

-- ============================================================
-- 商品（1,000件）
-- ============================================================
INSERT INTO perf_products (product_name, category_id, unit_price)
SELECT
    '商品_' || g.id,
    1 + (random() * 19)::int,          -- category_id: 1〜20
    (100 + (random() * 9900)::int)     -- 100円〜10,000円
FROM generate_series(1, 1000) AS g(id);

-- ============================================================
-- 注文（100万件）
-- ============================================================
-- 過去3年分の注文をランダムな日付で生成
INSERT INTO perf_orders (customer_id, order_date)
SELECT
    1 + (random() * 9999)::int,                                     -- customer_id: 1〜10,000
    '2023-01-01'::date + (random() * 1095)::int                     -- 2023-01-01〜2025-12-31
FROM generate_series(1, 1000000) AS g(id);

-- ============================================================
-- 注文明細（約300万件）
-- ============================================================
-- 各注文に1〜5件の明細をランダムに生成
-- 方法: 各注文に対して1〜5のランダムな行数を生成
-- 100万注文 × 平均3件 = 約300万件を効率的に生成
-- generate_series で明細行を直接生成し、order_id を割り当てる
INSERT INTO perf_order_items (order_id, product_id, quantity, unit_price)
SELECT
    sub.order_id,
    sub.product_id,
    sub.quantity,
    p.unit_price
FROM (
    SELECT
        1 + (random() * 999999)::int AS order_id,
        1 + (random() * 999)::int AS product_id,
        1 + (random() * 4)::int AS quantity
    FROM generate_series(1, 3000000) AS g(id)
) sub
JOIN perf_products p ON p.product_id = sub.product_id;

-- ============================================================
-- データ件数確認
-- ============================================================
SELECT 'perf_categories' AS table_name, COUNT(*) AS row_count FROM perf_categories
UNION ALL
SELECT 'perf_customers', COUNT(*) FROM perf_customers
UNION ALL
SELECT 'perf_products', COUNT(*) FROM perf_products
UNION ALL
SELECT 'perf_orders', COUNT(*) FROM perf_orders
UNION ALL
SELECT 'perf_order_items', COUNT(*) FROM perf_order_items
ORDER BY table_name;

-- ============================================================
-- 統計情報を更新（EXPLAIN の精度向上のため）
-- ============================================================
ANALYZE perf_categories;
ANALYZE perf_customers;
ANALYZE perf_products;
ANALYZE perf_orders;
ANALYZE perf_order_items;
