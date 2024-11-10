- [mysql 分離方法](#mysql-分離方法)
  - [env.sh](#/home/isucon/env.sh)
  - [mysqld.cnf](#/etc/mysql/mysql.conf.d/mysqld.cnf)
- [my.cnf](#my.cnf)
  - [max connections](#max-connections)
  - [innodb buffer](#innodb-buffer)
- [もしも DB が MySQL ではなかった場合](#もしも-DB-が-MySQL-ではなかった場合)
  - [PostgreSQL → MySQL](#PostgreSQL-→-MySQL)
    - [1.データのエクスポート](#1.データのエクスポート)
    - [2.ダンプファイルの変換](#2.ダンプファイルの変換)
    - [3.MySQL にデータベースを作成](#3.MySQL-にデータベースを作成)
    - [4.ダンプファイルのインポート](#4.ダンプファイルのインポート)
    - [5.データの検証](#5.データの検証)
    - [6.アプリケーションの設定変更](#6.アプリケーションの設定変更)
    - [7.テスト](#7.テスト)
  - [SQLite → MySQL](#SQLite-→-MySQL)
    - [1.SQLite データベースのエクスポート](#1.SQLite-データベースのエクスポート)
    - [2.ダンプファイルの変換](#2.ダンプファイルの変換)
    - [3.MySQL にデータベースを作成](#3.MySQL-にデータベースを作成)
    - [4.ダンプファイルのインポート](#4.ダンプファイルのインポート)
    - [5.データの検証](#5.データの検証)
    - [6.アプリケーションの設定変更](#6.アプリケーションの設定変更)
    - [7.テスト](#7.テスト)
    - [8.バックアップ](#8.バックアップ)

## mysql 分離方法

### /home/isucon/env.sh

```sh
# 以下の設定を書き換えます
ISUCON13_MYSQL_DIALCONFIG_ADDRESS="192.168.0.13" # <- 引っ越し先のPIP
```

### /etc/mysql/mysql.conf.d/mysqld.cnf

```conf
# Instead of skip-networking the default is now to listen only on
# localhost which is more compatible and is not less secure.
bind-address		= 0.0.0.0 # <- 元は 127.0.0.1 を全許可に変更した
mysqlx-bind-address	= 0.0.0.0 # <- 元は 127.0.0.1 を全許可に変更した
```

### 分離先の mysql に接続して、ユーザー追加＆権限追加を行う

```mysql
CREATE USER 'isucon'@'%' IDENTIFIED BY 'isucon';
GRANT ALL PRIVILEGES ON *.* TO 'isucon'@'%';
FLUSH PRIVILEGES;
```

### isupipe-go と mysql を再起動する

```sh
sudo systemctl restart isupipe-go.service
sudo systemctl restart mysql.service
```

## /etc/mysql/my.cnf

### max connections

```conf
# /etc/mysql/mysql.conf.d/mysqld.cnf にあることが多い
[mysqld]
max_connections=10000  # <- connection の limit を更新
```

```shell
# クライアントに接続して反映を確認する
make mysql
show variables like "%max_connection%"; で確認
```

### innodb buffer

```conf
innodb_buffer_pool_size = 1GB # ディスクイメージをメモリ上にバッファさせる値をきめる設定値
innodb_flush_log_at_trx_commit = 2 # 1に設定するとトランザクション単位でログを出力するが 2 を指定すると1秒間に1回ログファイルに出力するようになる
innodb_flush_method = O_DIRECT # データファイル、ログファイルの読み書き方式を指定する(実験する価値はある)
```

## もしも DB が MySQL ではなかった場合

Cygnus に聞いて書いたものです。ダンプファイルの方言の変換は Cygnus を使用するなどすれば簡単にできるんじゃないかと思います。

### PostgreSQL → MySQL

#### 1.データのエクスポート

まずは、PostgreSQL からデータをエクスポートします。pg_dump コマンドを使ってデータベース全体をダンプファイルに保存します。

```bash
pg_dump -U username -h hostname -F p databasename > dumpfile.sql
```

#### 2.ダンプファイルの変換

PostgreSQL と MySQL では SQL の方言が異なるため、ダンプファイルを MySQL 用に変換する必要があります。例えば、データ型やシンタックスの違いを修正します。

#### 3.MySQL にデータベースを作成

次に、MySQL に新しいデータベースを作成します。

```sql
CREATE DATABASE newdatabasename;
```

#### 4.ダンプファイルのインポート

変換したダンプファイルを MySQL にインポートします。

```bash
mysql -u username -p newdatabasename < dumpfile.sql
```

#### 5.データの検証

移行が完了したら、データが正しくインポートされているかを確認します。テーブルのレコード数やデータの整合性をチェックしましょう。

#### 6.アプリケーションの設定変更

移行が完了したら、アプリケーションのデータベース接続設定を PostgreSQL から MySQL に変更します。

#### 7.テスト

移行後のデータベースとアプリケーションが正常に動作するか、テストを行います。特に、クエリのパフォーマンスやデータの整合性に注意してください。

#### 8.バックアップ

最後に、移行後のデータベースをバックアップしておくと安心です。

### SQLite → MySQL

#### 1.SQLite データベースのエクスポート

まずは、SQLite からデータをエクスポートします。sqlite3 コマンドを使ってデータベース全体をダンプファイルに保存します。

```bash
sqlite3 databasename .dump > dumpfile.sql
```

#### 2.ダンプファイルの変換

SQLite と MySQL では SQL の方言が異なるため、ダンプファイルを MySQL 用に変換する必要があります。特に、データ型やシンタックスの違いを修正します。例えば、SQLite の`AUTOINCREMENT`を MySQL の`AUTO_INCREMENT`に変更するなどです。

#### 3.MySQL にデータベースを作成

次に、MySQL に新しいデータベースを作成します。

```sql
CREATE DATABASE newdatabasename;
```

#### 4.ダンプファイルのインポート

変換したダンプファイルを MySQL にインポートします。

```bash
mysql -u username -p newdatabasename < dumpfile.sql
```

#### 5.データの検証

移行が完了したら、データが正しくインポートされているかを確認します。テーブルのレコード数やデータの整合性をチェックしましょう。

#### 6.アプリケーションの設定変更

移行が完了したら、アプリケーションのデータベース接続設定を SQLite から MySQL に変更します。

#### 7.テスト

移行後のデータベースとアプリケーションが正常に動作するか、テストを行います。特に、クエリのパフォーマンスやデータの整合性に注意してください。

#### 8.バックアップ

最後に、移行後のデータベースをバックアップしておくと安心です。

#### 9.データ量確認クエリ

- table_name: テーブルの名前
- engine: テーブルのストレージエンジン（例：InnoDB、MyISAM など）
- table_rows: テーブル内の行数
- avg_row_length: 平均行長
- allMB: データ長とインデックス長の合計（メガバイト単位）
- dMB: データ長（メガバイト単位）
- iMB: インデックス長（メガバイト単位）

```
SELECT
    table_name,
    engine,
    table_rows,
    avg_row_length,
    FLOOR((data_length + index_length) / 1024 / 1024) AS allMB,
    FLOOR((data_length) / 1024 / 1024) AS dMB,
    FLOOR((index_length) / 1024 / 1024) AS iMB
FROM
    information_schema.tables
WHERE
    table_schema = DATABASE()
ORDER BY (data_length + index_length) DESC;
```
