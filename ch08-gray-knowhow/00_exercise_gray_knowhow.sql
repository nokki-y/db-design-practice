-- ============================================================
-- 第8章 演習: 論理設計のグレーノウハウ ─ 設計判断を問う
-- ============================================================
--
-- 【背景】
-- あなたは社内の勤怠・人事管理システム「WorkFlow」のDB設計レビューに
-- 参加しています。開発チームから複数の設計案が提出されており、
-- それぞれについて「どちらを採用すべきか」の判断を求められています。
--
-- 各問で提示される設計案を比較し、トレードオフを踏まえて
-- どちらが適切か判断してください。
--
-- ============================================================

-- ==========================================================
-- 【問1】代理キー vs 自然キー
-- ==========================================================
--
-- 社内の「資格マスタ」を設計しています。
-- 資格には国が定める「資格コード」（例: FE001, AP002）が存在しますが、
-- 過去に制度改定で資格コードが変更されたことがあります。
-- （例: 旧「SW001」→ 新「FE001」、試験内容はほぼ同一）
--
-- 2つの設計案が出ています。どちらを採用すべきですか？
-- 理由とともに答えてください。
--
-- ---- 案A: 自然キー（資格コードをPKにする） ----

CREATE TABLE certifications_plan_a (
    cert_code    CHAR(5)      NOT NULL PRIMARY KEY,  -- 国の資格コード
    cert_name    VARCHAR(100) NOT NULL,
    category     VARCHAR(50)  NOT NULL               -- 'IT', '会計', '法律' 等
);

-- ---- 案B: 代理キー + 自然キー ----

CREATE TABLE certifications_plan_b (
    cert_id      SERIAL       NOT NULL PRIMARY KEY,  -- 代理キー
    cert_code    CHAR(5)      NOT NULL UNIQUE,        -- 国の資格コード（一意制約）
    cert_name    VARCHAR(100) NOT NULL,
    category     VARCHAR(50)  NOT NULL
);


-- ==========================================================
-- 【問2】列持ち vs 行持ち
-- ==========================================================
--
-- 年に1回の人事異動に向けて、社員から「異動希望先」を収集します。
-- 人事規定により、希望は第1希望〜第3希望の最大3つまで提出でき、
-- この上限は変更の予定がありません。
-- 各希望には部署コードのみを記録します（希望理由等の属性はなし）。
-- 第1希望は必須、第2・第3希望は任意です。
--
-- 2つの設計案が出ています。どちらを採用すべきですか？
-- それぞれの利点・欠点を挙げた上で判断してください。
--
-- ---- 案A: 列持ち ----

CREATE TABLE transfer_requests_plan_a (
    employee_id    CHAR(8)  NOT NULL PRIMARY KEY,
    first_choice   CHAR(3)  NOT NULL,  -- 第1希望（必須）
    second_choice  CHAR(3),             -- 第2希望（任意）
    third_choice   CHAR(3)              -- 第3希望（任意）
);

-- ---- 案B: 行持ち ----

CREATE TABLE transfer_requests_plan_b (
    employee_id    CHAR(8)  NOT NULL,
    priority       INTEGER  NOT NULL CHECK (priority BETWEEN 1 AND 3),
    dept_code      CHAR(3)  NOT NULL,
    PRIMARY KEY (employee_id, priority)
);


-- ==========================================================
-- 【問3】アドホックな集計キー
-- ==========================================================
--
-- 以下の部署テーブルがあります。経営層から「事業部単位の人数集計が欲しい」
-- という要望が出ました。現状、事業部の情報はテーブルに存在しません。
--
-- 部署と事業部の対応関係:
--   営業部(D01), マーケティング部(D02) → ビジネス事業部
--   開発部(D03), インフラ部(D04)       → テクノロジー事業部
--   人事部(D05), 経理部(D06)           → コーポレート事業部
--
-- 3つの対応案が出ています。どれを採用すべきですか？
-- それぞれの利点・欠点を挙げた上で判断してください。

CREATE TABLE departments (
    dept_code    CHAR(3)      NOT NULL PRIMARY KEY,
    dept_name    VARCHAR(50)  NOT NULL
);

INSERT INTO departments VALUES
  ('D01', '営業部'),
  ('D02', 'マーケティング部'),
  ('D03', '開発部'),
  ('D04', 'インフラ部'),
  ('D05', '人事部'),
  ('D06', '経理部');

-- ---- 案A: 部署テーブルに集計キー列を追加 ----
--
-- ALTER TABLE departments ADD COLUMN division_code CHAR(2);
-- UPDATE departments SET division_code = '01' WHERE dept_code IN ('D01','D02');
-- UPDATE departments SET division_code = '02' WHERE dept_code IN ('D03','D04');
-- UPDATE departments SET division_code = '03' WHERE dept_code IN ('D05','D06');

-- ---- 案B: 事業部マスタを別テーブルとして作成し、FKで参照 ----
--
-- CREATE TABLE divisions (
--     division_code CHAR(2)     NOT NULL PRIMARY KEY,
--     division_name VARCHAR(50) NOT NULL
-- );
-- INSERT INTO divisions VALUES ('01','ビジネス事業部'),('02','テクノロジー事業部'),('03','コーポレート事業部');
-- ALTER TABLE departments ADD COLUMN division_code CHAR(2) REFERENCES divisions(division_code);

-- ---- 案C: ビューで対応（テーブルは変更しない） ----
--
-- CREATE VIEW dept_with_division AS
-- SELECT *,
--   CASE
--     WHEN dept_code IN ('D01','D02') THEN 'ビジネス事業部'
--     WHEN dept_code IN ('D03','D04') THEN 'テクノロジー事業部'
--     WHEN dept_code IN ('D05','D06') THEN 'コーポレート事業部'
--   END AS division_name
-- FROM departments;


-- ==========================================================
-- 【問4】多段ビューの危険性
-- ==========================================================
--
-- 以下の3つのビューが既存システムに存在しています。
-- 運用上の問題点を指摘し、どう改善すべきか答えてください。

CREATE TABLE employees (
    emp_id       CHAR(8)      NOT NULL PRIMARY KEY,
    emp_name     VARCHAR(100) NOT NULL,
    dept_code    CHAR(3)      NOT NULL REFERENCES departments(dept_code),
    hire_date    DATE         NOT NULL,
    salary       INTEGER      NOT NULL
);

INSERT INTO employees VALUES
  ('EMP00001', '加藤一郎',   'D01', '2015-04-01', 450000),
  ('EMP00002', '藤本恵',     'D01', '2018-04-01', 380000),
  ('EMP00003', '三島大輔',   'D03', '2020-04-01', 420000),
  ('EMP00004', '斉藤明美',   'D03', '2016-04-01', 460000),
  ('EMP00005', '田島誠',     'D05', '2019-04-01', 400000),
  ('EMP00006', '渡辺さくら', 'D06', '2021-04-01', 360000);

-- レベル1: 基本ビュー（勤続年数を計算）
CREATE VIEW v_emp_tenure AS
SELECT
    emp_id, emp_name, dept_code, hire_date, salary,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, hire_date)) AS tenure_years
FROM employees;

-- レベル2: v_emp_tenureの上にビューを重ねる（部署名を結合）
CREATE VIEW v_emp_detail AS
SELECT
    t.emp_id, t.emp_name, d.dept_name, t.hire_date, t.salary, t.tenure_years
FROM v_emp_tenure t
JOIN departments d ON t.dept_code = d.dept_code;

-- レベル3: v_emp_detailの上にさらにビューを重ねる（部署別集計）
CREATE VIEW v_dept_summary AS
SELECT
    dept_name,
    COUNT(*) AS emp_count,
    AVG(salary) AS avg_salary,
    AVG(tenure_years) AS avg_tenure
FROM v_emp_detail
GROUP BY dept_name;

-- 問: このビュー構成の問題点は何ですか？
--     また、どのように改善すべきですか？
