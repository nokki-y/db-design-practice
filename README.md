# db-design-practice

「達人に学ぶDB設計徹底指南書 第2版」（ミック著、翔泳社、2024年）で学んだ理論を、自分の手で実践するための演習リポジトリ。

書籍の内容をそのまま写すのではなく、独自の題材に対して正規化やアンチパターンの検討を行い、設計力を身につけることを目的とする。

## 環境

- PostgreSQL 16（Docker Compose で起動）

```bash
docker compose up -d

# 接続
PGPASSWORD=postgres psql -h localhost -p 5555 -U postgres -d db_design
```

## ディレクトリ構成

```
ch03-normalization/    # 第3章: 論理設計と正規化
```

章は必要に応じて追加していく。

## 参考文献

- ミック『達人に学ぶDB設計徹底指南書 第2版』翔泳社、2024年
