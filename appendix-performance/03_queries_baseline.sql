-- ============================================================
-- Step 2: ベースライン計測（インデックスなし）
-- ============================================================
-- 正規化テーブルに対して、典型的な集計クエリを実行し
-- インデックスなしの状態でのパフォーマンスを記録する。
--
-- 【実行方法】
--   psql -h localhost -p 5555 -U postgres -d db_design
--   \timing on
--   \i 03_queries_baseline.sql
--
-- 【計測のポイント】
--   - EXPLAIN ANALYZE は実際にクエリを実行して実測値を返す
--   - 「Execution Time」の値を NOTE.md に記録すること
--   - 複数回実行してキャッシュが温まった状態も確認するとよい
-- ============================================================

-- ============================================================
-- クエリ1: 月別・カテゴリ別の売上集計
-- ============================================================
-- 【特徴】 4テーブルJOIN + GROUP BY（全件集計）
-- 【WHEREなし】→ order_items 300万件を全件読む必要がある
-- 【インデックスが効かない理由】
--   WHERE句がないため、テーブル全体をスキャンする（Seq Scan）。
--   インデックスは「大量の行から少数を絞り込む」ときに効くが、
--   全件を読む集計ではオプティマイザがSeq Scanを選ぶ。
-- 【効果的な非正規化】
--   集計サマリーテーブルを事前に持てば300万件→720行に削減でき劇的に高速化。
--   → 05_schema_denormalized.sql で計測。
-- 【実務での想定】売上レポート、ダッシュボード

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
-- クエリ2: 特定顧客の注文履歴（直近1年）
-- ============================================================
-- 【特徴】 WHERE（customer_id = 42 AND order_date >= ...）で絞り込み + JOIN
-- 【選択性が高い】→ 100万注文のうち該当は約30件（0.003%）
-- 【インデックスが劇的に効く理由】
--   customer_id のインデックスで100万件 → 約100件に絞り込み、
--   さらに order_date でフィルタして約30件に。
--   次に order_id のインデックスで order_items を
--   Nested Loop（30回 × 数件）で効率的に取得。
--   → Seq Scan（全件走査）が完全に不要になる。
-- 【非正規化との差】
--   インデックスで十分高速なため、非正規化の追加メリットは小さい。
-- 【実務での想定】マイページの注文履歴、顧客詳細画面

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
-- クエリ3: 特定期間の売上集計（範囲検索）
-- ============================================================
-- 【特徴】 WHERE order_date BETWEEN ... AND ... で日付範囲を絞り込み + JOIN + 集計
-- 【選択性が中程度】→ 3年分のうち3ヶ月分 ≒ 約8%（100万注文のうち約8万件）
-- 【インデックスが「部分的に」効く理由】
--   order_date のインデックスで対象期間の注文を絞り込める。
--   ただしQ2（0.003%に絞り込み）と比べて選択率が高いため、
--   オプティマイザがIndex ScanとSeq Scanのどちらを選ぶかは
--   選択率次第。一般に全体の10〜20%以上を読む場合は
--   Seq Scanの方が効率的と判断されることがある。
-- 【実務での想定】四半期レポート、期間指定の売上分析

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
-- クエリ4: 特定都道府県の注文件数（カーディナリティの低い列での検索）
-- ============================================================
-- 【特徴】 WHERE prefecture = '東京都' でカーディナリティの低い列を絞り込み
-- 【選択性が低い】→ 47都道府県の1つ ≒ 約2%（1万顧客のうち約200人）
--   ただし1顧客あたり約100注文あるため、注文は約2万件、
--   明細は約6万件が対象になる。
-- 【インデックスの効きが「微妙」な理由】
--   カーディナリティ（値の種類数）が47しかない。
--   prefecture にインデックスを張っても、1つの値に対して
--   大量の行がヒットする。Q2（customer_id: 1万種類）と比べて
--   1値あたりのヒット数が多く、インデックスの効率が下がる。
--   それでもSeq Scanよりは速くなるかどうかが見どころ。
-- 【実務での想定】地域別の顧客分析、特定地域の売上確認

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
