- [my.cnf](#my.cnf)
  - [max connections](#max-connections)
  - [innodb buffer](#innodb-buffer)

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

### PostgreSQL → 　 MySQL

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

### SQLite → 　 MySQL

#### 1. SQLite データベースのエクスポート

まずは、SQLite からデータをエクスポートします。sqlite3 コマンドを使ってデータベース全体をダンプファイルに保存します。

```bash
sqlite3 databasename .dump > dumpfile.sql
```

#### 2. ダンプファイルの変換

SQLite と MySQL では SQL の方言が異なるため、ダンプファイルを MySQL 用に変換する必要があります。特に、データ型やシンタックスの違いを修正します。例えば、SQLite の`AUTOINCREMENT`を MySQL の`AUTO_INCREMENT`に変更するなどです。

#### 3. MySQL にデータベースを作成

次に、MySQL に新しいデータベースを作成します。

```sql
CREATE DATABASE newdatabasename;
```

#### 4. ダンプファイルのインポート

変換したダンプファイルを MySQL にインポートします。

```bash
mysql -u username -p newdatabasename < dumpfile.sql
```

#### 5. データの検証

移行が完了したら、データが正しくインポートされているかを確認します。テーブルのレコード数やデータの整合性をチェックしましょう。

#### 6. アプリケーションの設定変更

移行が完了したら、アプリケーションのデータベース接続設定を SQLite から MySQL に変更します。

#### 7. テスト

移行後のデータベースとアプリケーションが正常に動作するか、テストを行います。特に、クエリのパフォーマンスやデータの整合性に注意してください。

#### 8. バックアップ

最後に、移行後のデータベースをバックアップしておくと安心です。
