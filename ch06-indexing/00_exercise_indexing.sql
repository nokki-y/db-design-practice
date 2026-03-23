-- ============================================================
-- 第6章 演習: インデックス設計とパフォーマンス
-- テーマ: ECサイトの商品検索・注文管理システム
-- ============================================================
--
-- あなたはECサイトのDB設計を担当しています。
-- 以下の4テーブルに対して、ビジネス要件を満たすインデックスを設計してください。
--
-- データ規模の想定:
--   - 商品(products): 10万件
--   - 注文(orders): 1,000万件
--   - 注文明細(order_items): 3,000万件
--   - 顧客(customers): 100万人
--
-- ビジネス要件（頻出クエリ）:
--   A. 商品検索: カテゴリで絞り込み、価格帯で絞り込み、商品名で前方一致検索
--   B. 注文履歴: 特定顧客の注文を日付の新しい順に表示
--   C. 売上集計: 指定期間の注文を集計（日別・月別）
--   D. 在庫管理: 在庫数が一定以下の商品を抽出
-- ============================================================

-- 顧客
CREATE TABLE customers (
    customer_id   SERIAL PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    prefecture    VARCHAR(10),           -- 都道府県（47種類）
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 商品
CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    product_name  VARCHAR(200) NOT NULL,
    category      VARCHAR(50) NOT NULL,  -- 大カテゴリ（20種類）
    subcategory   VARCHAR(50) NOT NULL,  -- 小カテゴリ（200種類）
    price         INTEGER NOT NULL,
    stock_qty     INTEGER NOT NULL DEFAULT 0,
    is_published  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 注文
CREATE TABLE orders (
    order_id      SERIAL PRIMARY KEY,
    customer_id   INTEGER NOT NULL REFERENCES customers(customer_id),
    order_date    DATE NOT NULL,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending',
        -- 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled'
    total_amount  INTEGER NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 注文明細
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id      INTEGER NOT NULL REFERENCES orders(order_id),
    product_id    INTEGER NOT NULL REFERENCES products(product_id),
    quantity      INTEGER NOT NULL,
    unit_price    INTEGER NOT NULL
);

-- ============================================================
-- サンプルデータ
-- ============================================================

INSERT INTO customers (name, email, prefecture) VALUES
    ('山田太郎', 'yamada@example.com', '東京都'),
    ('佐藤花子', 'sato@example.com', '大阪府'),
    ('鈴木一郎', 'suzuki@example.com', '東京都'),
    ('高橋美咲', 'takahashi@example.com', '北海道'),
    ('田中健太', 'tanaka@example.com', '福岡県');

INSERT INTO products (product_name, category, subcategory, price, stock_qty, is_published) VALUES
    ('ワイヤレスイヤホン Pro',   '家電',     'オーディオ',    15000, 150, TRUE),
    ('USB-C ハブ 7in1',         '家電',     'PC周辺機器',    4500,   3, TRUE),
    ('有機コーヒー豆 500g',      '食品',     '飲料',          1800, 200, TRUE),
    ('ランニングシューズ X',     'スポーツ', 'シューズ',     12000,   0, TRUE),
    ('PostgreSQL実践入門',       '書籍',     '技術書',        3200,  50, TRUE),
    ('ヨガマット 6mm',           'スポーツ', 'フィットネス',  2500,  80, TRUE),
    ('有機抹茶パウダー 100g',    '食品',     '飲料',          2200,  15, FALSE),
    ('ノイズキャンセリングヘッドホン', '家電', 'オーディオ',  25000,  30, TRUE);

INSERT INTO orders (customer_id, order_date, status, total_amount) VALUES
    (1, '2024-01-15', 'delivered',  15000),
    (1, '2024-03-20', 'delivered',   6300),
    (2, '2024-02-10', 'delivered',  12000),
    (3, '2024-03-01', 'shipped',     4500),
    (3, '2024-03-25', 'pending',     1800),
    (4, '2024-01-08', 'delivered',  27500),
    (4, '2024-03-15', 'cancelled',  15000),
    (5, '2024-02-28', 'delivered',   5700);

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    (1, 1, 1, 15000),
    (2, 3, 2,  1800),
    (2, 5, 1,  3200),
    (3, 4, 1, 12000),
    (4, 2, 1,  4500),
    (5, 3, 1,  1800),
    (6, 1, 1, 15000),
    (6, 8, 1, 25000),
    (7, 1, 1, 15000),
    (8, 6, 1,  2500),
    (8, 5, 1,  3200);

-- ============================================================
-- 演習問題
-- ============================================================
--
-- ■ Q1: インデックス設計の基礎
--   以下の各クエリに対して、どの列にインデックスを貼るべきか答えよ。
--   また「なぜその列か」をカーディナリティの観点から説明せよ。
--
--   (a) 要件A: 商品をカテゴリで絞り込む
--       SELECT * FROM products WHERE category = '家電' AND is_published = TRUE;
--
--   (b) 要件B: 特定顧客の注文を日付順に取得する
--       SELECT * FROM orders WHERE customer_id = 123 ORDER BY order_date DESC;
--
--   (c) 要件D: 在庫が5個以下の公開中商品を抽出する
--       SELECT * FROM products WHERE stock_qty <= 5 AND is_published = TRUE;
--
-- ■ Q2: インデックスが効かないケース
--   以下のSQLにはインデックスが効かない問題がある。
--   それぞれ何が問題か指摘し、インデックスが効くように書き換えよ。
--
--   (a) SELECT * FROM products WHERE UPPER(product_name) = 'USB-C ハブ 7IN1';
--
--   (b) SELECT * FROM orders WHERE order_date BETWEEN '2024-01-01' AND '2024-03-31'
--       OR status = 'pending';
--
--   (c) SELECT * FROM products WHERE product_name LIKE '%イヤホン%';
--
--   (d) SELECT * FROM orders WHERE TO_CHAR(order_date, 'YYYY-MM') = '2024-03';
--
-- ■ Q3: 複合インデックスの設計
--   要件A「カテゴリで絞り込み → 価格帯で絞り込み → 商品名で前方一致検索」を
--   1つの複合インデックスで対応したい。
--
--   (a) どの列をどの順序で複合インデックスにすべきか？その理由は？
--   (b) 以下の3つのクエリのうち、そのインデックスが効くものと効かないものはどれか？
--       1) SELECT * FROM products WHERE category = '家電' AND price BETWEEN 1000 AND 5000;
--       2) SELECT * FROM products WHERE price BETWEEN 1000 AND 5000;
--       3) SELECT * FROM products WHERE category = '家電' AND product_name LIKE 'ワイヤレス%';
--
-- ■ Q4: インデックスを貼るべきでないケース
--   以下のケースでインデックスが効果的でない（または不要な）理由を説明せよ。
--
--   (a) productsテーブル（10万件）のis_published列（TRUE/FALSEの2値）
--   (b) 全商品を価格順に一覧表示するクエリ（10万件全件取得）
--   (c) 月に1回だけ実行されるバッチ処理の集計クエリ
--
-- ■ Q5: 第5章との接続
--   第5章で学んだ非正規化と、第6章で学んだインデックスは
--   どちらもパフォーマンス改善の手段である。
--   「まずインデックスを検討し、それでもダメなら非正規化」という
--   判断基準を、Q1〜Q4の具体例を使って説明せよ。
-- ============================================================
