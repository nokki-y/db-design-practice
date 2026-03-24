-- ============================================================
-- Step 4: 効果的な非正規化（集計サマリーテーブル）
-- ============================================================
-- 全件集計クエリ（Q1）に対して、集計結果を事前に持つ
-- サマリーテーブルを作成し、パフォーマンスを比較する。
--
-- 【実行方法】
--   psql -h localhost -p 5555 -U postgres -d db_design
--   \timing on
--   \i 05_schema_denormalized.sql
--
-- 【非正規化の方針】
--   「行を横に広げる」のではなく、「読む行数を減らす」設計をする。
--   300万件の明細を毎回集計する代わりに、集計結果（720行）を
--   事前に持っておくことで、読み取りを劇的に高速化する。
--
-- 【トレードオフ】
--   注文の追加・変更・削除のたびにサマリーテーブルも更新が必要。
--   リアルタイム性が求められる場合はトリガーやバッチ処理の設計が必要になる。
-- ============================================================

-- ============================================================
-- Q1用: 月別・カテゴリ別の集計サマリーテーブル
-- ============================================================
-- 300万件 → 720行（36ヶ月 × 20カテゴリ）

DROP TABLE IF EXISTS perf_monthly_category_sales;

CREATE TABLE perf_monthly_category_sales AS
SELECT
    TO_CHAR(o.order_date, 'YYYY-MM') AS year_month,
    c.category_name,
    SUM(oi.quantity * oi.unit_price) AS total_sales,
    COUNT(DISTINCT o.order_id) AS order_count
FROM perf_order_items oi
JOIN perf_orders o ON o.order_id = oi.order_id
JOIN perf_products p ON p.product_id = oi.product_id
JOIN perf_categories c ON c.category_id = p.category_id
GROUP BY TO_CHAR(o.order_date, 'YYYY-MM'), c.category_name;

ANALYZE perf_monthly_category_sales;

-- データ件数確認
SELECT COUNT(*) AS summary_rows FROM perf_monthly_category_sales;

-- テーブルサイズ比較
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(oid)) AS total_size
FROM pg_class
WHERE relname LIKE 'perf_%'
  AND relkind = 'r'
ORDER BY pg_total_relation_size(oid) DESC;

-- ============================================================
-- Q1: 月別・カテゴリ別の売上集計（集計サマリーテーブル版）
-- ============================================================
-- 720行を読むだけ。JOINも集計も不要。

EXPLAIN ANALYZE
SELECT
    year_month,
    category_name,
    total_sales,
    order_count
FROM perf_monthly_category_sales
ORDER BY year_month, total_sales DESC;
