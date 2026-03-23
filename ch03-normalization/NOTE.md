# 第3章: 論理設計と正規化 — 学習ノート

## 演習の題材

「オンライン書店の注文管理」の非正規形テーブル（`orders_raw`）を、段階的に正規化する。

## 関数従属性の洗い出し

データを観察して、以下の関数従属性を発見した。

```
{order_id}    → {order_date, customer_id}
{customer_id} → {customer_name, customer_email, pref_code}
{pref_code}   → {pref_name}
```

※ カンマ区切り列（book_ids等）は1NF違反を解消してから改めて考える必要がある。

---

## 第1正規形（1NF）— スカラ値の原則

**ルール: 1つのセルには1つの値しか入れない**

### 問題の特定

以下の列がカンマ区切りで複数の値を持っている（スカラ値違反）：
- `book_ids`, `book_titles`, `book_prices`, `publisher_codes`, `publisher_names`

### 解決方法の検討

カンマ区切りを解消する方法として3つ考えた：

1. **列持ち**（book_id_1, book_id_2, book_id_3...） → 上限が決まってしまうのでNG
2. **行持ち**（1行1書籍に展開） → これが正解
3. **JSON型** → PostgreSQLのjsonbで扱えるが、関数従属性の管理やJOINができなくなるため、正規化の目的とは相反する。「構造化データはテーブル、非構造化データはJSON」が使い分けの基準。

### 1NFの結果

カンマ区切りを行持ちに展開し、書籍情報を別テーブルに分離した。

```
注文テーブル（order_id, order_date, customer_id, customer_name, customer_email, pref_code, pref_name）
注文明細テーブル（order_id, book_id）  ← 複合主キー
書籍テーブル（book_id, book_title, book_price, publisher_code, publisher_name）
```

**ここで詰まった。** `order_id` を主キーにすると、1つの注文に複数の書籍を紐づけられない。order_idだけでは複数行になってしまい主キーとして機能しない。
- 解決策: **注文テーブル**と**注文明細テーブル**の2つに分ける。1つの注文に複数の書籍が紐づく「1:Nの関係」を、中間テーブル（明細テーブル）で表現する。
- 注文明細テーブルの主キーは `{order_id, book_id}` の複合主キー。order_id単体でもbook_id単体でも一意にならないが、2つの組み合わせで1行が特定できる。
- ECサイトのレシートに例えると、ヘッダー（日付・顧客）と明細行（商品ごとの行）の関係。この比喩で腹落ちした。

### 1NF解消後に見えた関数従属性

カンマ区切りを解消すると、書籍に関する関数従属性が見えてくる：

```
{book_id}         → {book_title, book_price, publisher_code}
{publisher_code}  → {publisher_name}
```

---

## 第2正規形（2NF）— 部分関数従属の解消

**ルール: 複合主キーの「一部」だけに従属する列を別テーブルに分離する**

### 何が部分関数従属か

1NFの時点で、注文テーブルの主キーは `{order_id}` だが、そこに顧客情報がすべて入っている状態。
また書籍テーブルにも `publisher_name` が `publisher_code` だけで決まる状態がある。

ここでのポイント: 部分関数従属は「複合主キーの一部で決まる列がある」こと。
注文テーブルの `customer_id → {customer_name, customer_email, pref_code, pref_name}` は、
order_idとは無関係にcustomer_idだけで決まるので、顧客テーブルとして切り出す。

### 2NFの結果

```
注文テーブル（order_id, order_date, customer_id）
注文明細テーブル（order_id, book_id）
顧客テーブル（customer_id, customer_name, customer_email, pref_code, pref_name）
書籍テーブル（book_id, book_title, book_price, publisher_code, publisher_name）
```

顧客情報を切り出したことで、田中太郎が何回注文しても名前・メールの重複が発生しなくなった。

---

## 第3正規形（3NF）— 推移的関数従属の解消

**ルール: 主キー → 非キー列A → 非キー列B という「2段階の従属」を解消する**

### 何が推移的関数従属か

2NFの時点で2箇所ある：

1. **顧客テーブル内**: `{customer_id} → {pref_code} → {pref_name}`
   - customer_idが決まればpref_codeが決まり、pref_codeが決まればpref_nameが決まる
   - pref_nameはcustomer_idに直接従属しているのではなく、pref_codeを経由して間接的に従属している
   - → **都道府県テーブル**を分離

2. **書籍テーブル内**: `{book_id} → {publisher_code} → {publisher_name}`
   - book_idが決まればpublisher_codeが決まり、publisher_codeが決まればpublisher_nameが決まる
   - → **出版社テーブル**を分離

### 3NFの結果（最終形）

| テーブル | 主キー | 列 |
|---|---|---|
| 注文 | order_id | order_date, customer_id |
| 注文明細 | order_id, book_id | （複合主キーのみ） |
| 顧客 | customer_id | customer_name, customer_email, pref_code |
| 都道府県 | pref_code | pref_name |
| 書籍 | book_id | book_title, book_price, publisher_code |
| 出版社 | publisher_code | publisher_name |

---

## 正規化の段階まとめ

```
非正規形    orders_raw（カンマ区切り、全部入り1テーブル）
   ↓ 1NF: スカラ値違反を解消（行持ちに展開、注文明細・書籍テーブル分離）
3テーブル   注文 / 注文明細 / 書籍
   ↓ 2NF: 部分関数従属を解消（顧客テーブル分離）
4テーブル   注文 / 注文明細 / 顧客 / 書籍
   ↓ 3NF: 推移的関数従属を解消（都道府県・出版社テーブル分離）
6テーブル   注文 / 注文明細 / 顧客 / 都道府県 / 書籍 / 出版社
```
