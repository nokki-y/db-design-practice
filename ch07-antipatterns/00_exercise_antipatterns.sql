-- ============================================================
-- 第7章 演習: 論理設計のアンチパターンを見抜け
-- ============================================================
--
-- 【背景】
-- あなたはオンライン学習プラットフォーム「LearnHub」の開発チームに
-- 途中参加しました。既存メンバーが設計したデータベースを引き継いだところ、
-- 運用上さまざまな問題が報告されています。
--
-- 以下のテーブル定義を読み、論理設計上のアンチパターンを特定してください。
--
-- 【問1】
-- 下記のテーブル群には、書籍で紹介された論理設計のアンチパターンが
-- 少なくとも5つ含まれています。
-- それぞれについて以下を答えてください。
--
--   (a) どのテーブルの、どの部分がアンチパターンか
--   (b) アンチパターンの名前（書籍の分類に基づく）
--   (c) 運用上どのような問題が起きるか（具体的なシナリオで）
--
-- 【問2】
-- 特定したアンチパターンのうち、最も修正の優先度が高いと思うものを
-- 1つ選び、修正後のテーブル定義（CREATE TABLE文）を書いてください。
-- なぜそれを最優先としたか、理由も説明してください。
--
-- ============================================================

-- ----------------------------------------------------------
-- コード管理テーブル
-- ----------------------------------------------------------
-- 「コード値が散らばるのは管理しづらい」という理由で、
-- 前任者がすべてのコード値を1つのテーブルにまとめた。
CREATE TABLE codes (
    code_type   VARCHAR(20)  NOT NULL,  -- 'course_level', 'user_role', 'payment_method' 等
    code_value  VARCHAR(10)  NOT NULL,  -- '01', '02', '03' 等
    code_name   VARCHAR(100) NOT NULL,  -- コードの表示名
    PRIMARY KEY (code_type, code_value)
);

INSERT INTO codes VALUES
  ('course_level',   '01', '初級'),
  ('course_level',   '02', '中級'),
  ('course_level',   '03', '上級'),
  ('user_role',      '01', '受講者'),
  ('user_role',      '02', '講師'),
  ('user_role',      '03', '管理者'),
  ('payment_method', '01', 'クレジットカード'),
  ('payment_method', '02', '銀行振込'),
  ('payment_method', '03', 'コンビニ払い'),
  ('pay_status',     '01', '未払い'),
  ('pay_status',     '02', '支払済'),
  ('pay_status',     '03', '返金済');

-- ----------------------------------------------------------
-- 講師テーブル
-- ----------------------------------------------------------
CREATE TABLE instructors (
    instructor_name  VARCHAR(100) PRIMARY KEY,  -- 講師名をPKにしている
    email            VARCHAR(200) NOT NULL,
    profile_text     TEXT
);

INSERT INTO instructors VALUES
  ('田中太郎', 'tanaka@example.com', 'Python歴10年'),
  ('佐藤花子', 'sato@example.com',   'データサイエンティスト'),
  ('鈴木一郎', 'suzuki@example.com', 'Webエンジニア');

-- ----------------------------------------------------------
-- コーステーブル
-- ----------------------------------------------------------
CREATE TABLE courses (
    course_id       VARCHAR(20) PRIMARY KEY,
    course_name     VARCHAR(200) NOT NULL,
    instructor_name VARCHAR(100) NOT NULL REFERENCES instructors(instructor_name),
    level_code      VARCHAR(10)  NOT NULL,    -- codes テーブルの course_level を参照（FK制約なし）
    tags            VARCHAR(500),             -- タグをカンマ区切りで格納: 'Python,機械学習,初心者向け'
    price           INTEGER      NOT NULL
);

INSERT INTO courses VALUES
  ('CS001', 'Python入門',           '田中太郎', '01', 'Python,プログラミング,初心者向け',    5000),
  ('CS002', 'データ分析実践',        '佐藤花子', '02', 'Python,データ分析,pandas',           12000),
  ('CS003', 'Web開発マスター',       '鈴木一郎', '03', 'JavaScript,React,Web開発',          15000),
  ('CS004', '機械学習入門',          '佐藤花子', '01', 'Python,機械学習,AI,初心者向け',       8000);

-- ----------------------------------------------------------
-- 受講履歴テーブル（2024年）
-- ----------------------------------------------------------
-- 「年度が変わるとデータが増えて遅くなる」という理由で、
-- 前任者が年度ごとにテーブルを分割した。
CREATE TABLE enrollments_2024 (
    enrollment_id   SERIAL PRIMARY KEY,
    user_name       VARCHAR(100) NOT NULL,
    course_id       VARCHAR(20)  NOT NULL REFERENCES courses(course_id),
    enrolled_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    score           INTEGER               -- 通常は受講スコア（0-100）を格納
);

INSERT INTO enrollments_2024 (user_name, course_id, enrolled_at, score) VALUES
  ('山田次郎', 'CS001', '2024-04-01 10:00:00', 85),
  ('高橋美咲', 'CS002', '2024-05-15 14:30:00', 72),
  ('伊藤健太', 'CS001', '2024-06-01 09:00:00', NULL),
  ('山田次郎', 'CS003', '2024-07-20 11:00:00', 90);

-- ----------------------------------------------------------
-- 受講履歴テーブル（2025年）
-- ----------------------------------------------------------
CREATE TABLE enrollments_2025 (
    enrollment_id   SERIAL PRIMARY KEY,
    user_name       VARCHAR(100) NOT NULL,
    course_id       VARCHAR(20)  NOT NULL REFERENCES courses(course_id),
    enrolled_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    score           INTEGER               -- ★ 2025年度からscoreカラムの用途を変更:
                                          --   受講スコアではなく「満足度（1-5）」を格納する運用に変わった
);

INSERT INTO enrollments_2025 (user_name, course_id, enrolled_at, score) VALUES
  ('山田次郎', 'CS004', '2025-01-10 10:00:00', 4),
  ('高橋美咲', 'CS001', '2025-02-20 13:00:00', 5),
  ('伊藤健太', 'CS003', '2025-03-05 16:00:00', 3),
  ('木村由美', 'CS002', '2025-04-01 09:30:00', 4);
