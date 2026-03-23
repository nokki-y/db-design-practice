-- ============================================================
-- 第5章 演習: 正規化と非正規化のトレードオフ
-- テーマ: オンライン学習プラットフォーム
-- ============================================================
--
-- あなたはオンライン学習プラットフォームのDB設計を担当しています。
-- 以下は正規化された5つのテーブルです。
--
-- ビジネス要件:
--   1. 「コース一覧画面」では、各コースの受講者数と平均評価を表示する
--   2. 「受講履歴画面」では、ユーザーごとに受講したコースのカテゴリ名・コース名・進捗率を表示する
--   3. 「カテゴリ別集計」では、カテゴリごとの総受講者数と総売上を表示する
--
-- データ規模の想定:
--   - ユーザー: 50万人
--   - コース: 5,000件
--   - カテゴリ: 50件
--   - 受講記録: 500万件（1ユーザー平均10コース受講）
--   - レビュー: 200万件
-- ============================================================

-- カテゴリ
CREATE TABLE categories (
    category_id   SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
);

-- 講師
CREATE TABLE instructors (
    instructor_id SERIAL PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    bio           TEXT
);

-- コース
CREATE TABLE courses (
    course_id     SERIAL PRIMARY KEY,
    category_id   INTEGER NOT NULL REFERENCES categories(category_id),
    instructor_id INTEGER NOT NULL REFERENCES instructors(instructor_id),
    title         VARCHAR(200) NOT NULL,
    price         INTEGER NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 受講記録
CREATE TABLE enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    user_id       INTEGER NOT NULL,
    course_id     INTEGER NOT NULL REFERENCES courses(course_id),
    enrolled_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    progress_pct  INTEGER NOT NULL DEFAULT 0,  -- 進捗率 0-100
    UNIQUE(user_id, course_id)
);

-- レビュー
CREATE TABLE reviews (
    review_id     SERIAL PRIMARY KEY,
    user_id       INTEGER NOT NULL,
    course_id     INTEGER NOT NULL REFERENCES courses(course_id),
    rating        INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment       TEXT,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, course_id)
);

-- ============================================================
-- サンプルデータ
-- ============================================================

INSERT INTO categories (category_name) VALUES
    ('プログラミング'), ('データサイエンス'), ('デザイン');

INSERT INTO instructors (name, bio) VALUES
    ('田中太郎', 'Web開発歴15年'),
    ('佐藤花子', 'データ分析の専門家'),
    ('鈴木一郎', 'UIデザイナー');

INSERT INTO courses (category_id, instructor_id, title, price) VALUES
    (1, 1, 'Python入門',           3000),
    (1, 1, 'Webアプリ開発実践',     5000),
    (2, 2, 'SQL基礎',              2500),
    (2, 2, '機械学習入門',          4500),
    (3, 3, 'Figmaマスター',         3500);

INSERT INTO enrollments (user_id, course_id, progress_pct) VALUES
    (1, 1, 100), (1, 2,  60), (1, 3, 30),
    (2, 1,  80), (2, 4,  45),
    (3, 2,  20), (3, 3, 100), (3, 5, 70),
    (4, 1, 100), (4, 5,  50),
    (5, 3,  90), (5, 4,  10);

INSERT INTO reviews (user_id, course_id, rating, comment) VALUES
    (1, 1, 5, '非常にわかりやすい'),
    (1, 3, 4, 'SQL苦手だったけど理解できた'),
    (2, 1, 4, '初心者に優しい'),
    (3, 3, 5, '実務で使える内容'),
    (3, 5, 3, 'もう少し深い内容が欲しい'),
    (4, 1, 5, '最高のコース'),
    (5, 3, 4, '丁寧な説明');

-- ============================================================
-- 演習問題
-- ============================================================
--
-- ■ Q1: コース一覧画面
--   要件: 各コースの「受講者数」と「平均評価」を表示する。
--   (a) この要件を正規化されたテーブルのまま実現するには、
--       どのテーブルをJOINして何を集約する必要があるか？
--   (b) 500万件のenrollments・200万件のreviewsに対して
--       このクエリを画面表示のたびに実行することの問題点は何か？
--   (c) 非正規化で解決するとしたら、どのテーブルにどんな列を追加するか？
--       その場合、データ整合性をどう担保するか？
--
-- ■ Q2: 受講履歴画面
--   要件: ユーザーごとに受講したコースの「カテゴリ名」「コース名」「進捗率」を表示する。
--   (a) 正規化されたままのSQLではどんなJOINが必要か？
--   (b) このクエリのパフォーマンス上のボトルネックはどこか？
--   (c) 非正規化するとしたらどうするか？そのメリット・デメリットは？
--
-- ■ Q3: カテゴリ別集計
--   要件: カテゴリごとの「総受講者数」と「総売上」を表示する。
--   (a) 正規化されたままのSQLではどんなJOIN・集約が必要か？
--   (b) 非正規化で解決するとしたらどんな方法があるか？
--   (c) 書籍で紹介された「サマリデータの冗長保持」をこの題材に適用するとどうなるか？
--
-- ■ Q4: 総合判断
--   上記Q1〜Q3を踏まえて、このシステム全体として
--   「どこを非正規化すべきか」「どこは正規化のままでよいか」を判断し、
--   その理由を説明せよ。
-- ============================================================
