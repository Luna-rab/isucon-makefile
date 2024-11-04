- [nginx.conf](#nginx.conf)

## /etc/nginx/nginx.conf

## nginx.conf

```conf
worker_processes  auto;  # コア数と同じ数まで増やすと良いかも

# nginx worker の設定
worker_rlimit_nofile  4096;  # worker_connections の 4 倍程度（感覚値）
events {
  worker_connections  1024;  # 大きくするなら worker_rlimit_nofile も大きくする（file descriptor数の制限を緩める)
  # multi_accept on;  # error が出るリスクあり。defaultはoff。
  # accept_mutex_delay 100ms;
}

http {
  log_format main '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_time';   # kataribe 用の log format
  access_log  /var/log/nginx/access.log  main;   # これはしばらく on にして、最後に off にすると良さそう。
  # access_log  off;

  # 基本設定
  sendfile    on;
  tcp_nopush  on;
  tcp_nodelay on;
  types_hash_max_size 2048;
  server_tokens    off;
  # open_file_cache max=100 inactive=20s; file descriptor のキャッシュ。入れた方が良い。

  # proxy buffer の設定。白金動物園が設定してた。
  # proxy_buffers 100 32k;
  # proxy_buffer_size 8k;

  # mime.type の設定
  include       /etc/nginx/mime.types;

  # Keepalive 設定
  keepalive_timeout 65;
  keepalive_requests 500;

  # Proxy cache 設定。使いどころがあれば。1mでkey8,000個。1gまでcache。
  proxy_cache_path /var/cache/nginx/cache levels=1:2 keys_zone=zone1:1m max_size=1g inactive=1h;
  proxy_temp_path  /var/cache/nginx/tmp;
  # オリジンから来るCache-Controlを無視する必要があるなら。。。
  #proxy_ignore_headers Cache-Control;

  # Lua 設定。
  # Lua の redis package を登録
  lua_package_path /home/isucon/lua/redis.lua;
  init_by_lua_block { require "resty.redis" }

  # unix domain socket 設定1
  upstream app {
    server unix:/run/unicorn.sock;  # systemd を使ってると `/tmp` 以下が使えない。appのディレクトリに`tmp`ディレクトリ作って配置する方がpermissionでハマらずに済んで良いかも。
  }

  # 複数serverへ proxy
  upstream app {
    server 192.100.0.1:5000 weight=2;  // weight をつけるとproxyする量を変更可能。defaultは1。多いほどたくさんrequestを振り分ける。
    server 192.100.0.2:5000;
    server 192.100.0.3:5000;
    # keepalive 60; app server への connection を keepalive する。app が対応できるならした方が良い。
  }

  server {
    # HTTP/2 (listen 443 の後ろに http2 ってつけるだけ。ブラウザからのリクエストの場合ssl必須）
    listen 443 ssl http2;

    # TLS の設定
    listen 443 default ssl;
    # server_name example.jp;  # オレオレ証明書だと指定しなくても動いた
    ssl on;
    ssl_certificate /ssl/oreore.crt;
    ssl_certificate_key /ssl/oreore.key;
    # SSL Sesssion Cache
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1m;  # cacheする時間。1mは1分。

    # reverse proxy の 設定
    location / {
      proxy_pass http://localhost:3000;
      # proxy_http_version 1.1;          # app server との connection を keepalive するなら追加
      # proxy_set_header Connection "";  # app server との connection を keepalive するなら追加
    }

    # Unix domain socket の設定2。設定1と組み合わせて。
    location / {
      proxy_pass http://app;
    }

    # For Server Sent Event
    location /api/stream/rooms {
      # "magic trio" making EventSource working through Nginx
      proxy_http_version 1.1;
      proxy_set_header Connection '';
      chunked_transfer_encoding off;
      # These are not an official way
      # proxy_buffering off;
      # proxy_cache off;
      proxy_pass http://localhost:8080;
    }

    # For websocket
    location /wsapp/ {
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_pass http://wsbackend;
    }

    # Proxy cache
    location /cached/ {
      proxy_cache zone1;
      # proxy_set_header X-Real-IP $remote_addr;
      # proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      # proxy_set_header Host $http_host;
      proxy_pass http://localhost:9292/;
      # デフォルトでは 200, 301, 302 だけキャッシュされる。proxy_cache_valid で増やせる。
      # proxy_cache_valid 200 301 302 3s;
      # cookie を key に含めることもできる。デフォルトは $scheme$proxy_host$request_uri;
      # proxy_cache_key $proxy_host$request_uri$cookie_jessionid;
      # レスポンスヘッダにキャッシュヒットしたかどうかを含める
      add_header X-Nginx-Cache $upstream_cache_status;
    }

    # Lua
    location /img {
      # default_type 'image/svg+xml; charset=utf-8';
      content_by_lua_file /home/isucon/lua/img.lua;
    }

    # WebDav 設定。使いどころがあれば。
    location /img {
      client_body_temp_path /dev/shm/client_temp;
      dav_methods PUT DELETE MKCOL COPY MOVE;
      create_full_put_path  on;
      dav_access            group:rw  all:r;

      # IPを制限する場合
      # limit_except GET HEAD {
      #   allow 192.168.1.0/32;
      #   deny  all;
      # }
    }

    # static file の配信用の root
    root /home/isucon/webapp/public/;

    location ~ .*\.(htm|html|css|js|jpg|png|gif|ico) {
      expires 24h;
      add_header Cache-Control public;

      open_file_cache max=100  # file descriptor などを cache

      gzip on;  # cpu 使うのでメリット・デメリット見極める必要あり。gzip_static 使えるなら事前にgzip圧縮した上でそちらを使う。
      gzip_types text/css application/javascript application/json application/font-woff application/font-tff image/gif image/png image/jpeg image/svg+xml image/x-icon application/octet-stream;
      gzip_disable "msie6";
      gzip_static on;  # nginx configure時に --with-http_gzip_static_module 必要
      gzip_vary on;
    }
  }
}
```

## HTTP サーバーが nginx ではない場合

### apache → 　 nginx

#### 1. 環境のバックアップ

- 設定ファイルのバックアップ: Apache の設定ファイル（httpd.conf や sites-available ディレクトリ内のファイル）をバックアップします。
- データのバックアップ: ウェブサイトのコンテンツやデータベースをバックアップします。

#### 2. Nginx のインストール

- インストール: サーバーに Nginx をインストールします。多くの Linux ディストリビューションでは、パッケージマネージャーを使って簡単にインストールできます。

```bash
sudo apt-get update
sudo apt-get install nginx
```

#### 3. 設定ファイルの変換

- Apache の設定を Nginx に変換: Apache の設定ファイルを元に、Nginx の設定ファイル（通常は/etc/nginx/nginx.conf や/etc/nginx/sites-available ディレクトリ内のファイル）を作成します。以下のようなポイントに注意します。
- バーチャルホスト: Apache の<VirtualHost>ディレクティブを Nginx の server ブロックに変換します。
- リライトルール: Apache の RewriteRule を Nginx の rewrite ディレクティブに変換します。
- ディレクトリ設定: Apache の<Directory>ディレクティブを Nginx の location ブロックに変換します。
- モジュール: Apache のモジュール（例：mod_rewrite、mod_proxy）に対応する Nginx のモジュールや設定を確認します。

#### 4. SSL/TLS 設定

- SSL 証明書の設定: Apache で使用していた SSL 証明書を Nginx に設定します。Nginx の server ブロック内に以下のように設定します。

```nginx
server {
listen 443 ssl;
server_name example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

}
```

#### 5. サービスの停止と起動

- Apache の停止: Apache を停止します。

```bash
sudo systemctl stop apache2
```

- Nginx の起動: Nginx を起動します。

```bash
sudo systemctl start nginx
```

#### 6. 動作確認

- ログの確認: Nginx のエラーログやアクセスログを確認し、問題がないかチェックします。

```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

- ウェブサイトの確認: ブラウザでウェブサイトにアクセスし、正しく表示されるか確認します。

#### 7. 調整と最適化

- パフォーマンスの最適化: Nginx の設定を調整し、パフォーマンスを最適化します。
- セキュリティの強化: セキュリティ設定を確認し、必要に応じて強化します。
