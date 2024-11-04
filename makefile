# ### 基本構成案
# 1. アプリケーションサーバー × 2台
# 2. データベースサーバー × 1台
#
# ### 詳細な構成
# [クライアント]
#      ↓
# [アプリケーションサーバー1 (Nginx + ロードバランサー + アプリケーション)]
#      ↓
# [アプリケーションサーバー2 (Nginx + アプリケーション)]
#      ↓
# [データベースサーバー (MySQL)]
#

DATE:=$(shell date +%Y%m%d-%H%M%S)

# ssh configによる
APP_SERVER_1:=isucon1
APP_SERVER_2:=isucon2
DB_SERVER:=isucon3
SERVER_1:=isucon1
SERVER_2:=isucon2
SERVER_3:=isucon3

WEBAPP_DIR:=/home/isucon/webapp
NGINX_DIR:=/etc/nginx
MYSQL_DIR:=/etc/mysql
NGINX_LOG:=/var/log/nginx/access.log
MYSQL_LOG:=/var/log/mysql/slow-query.log
MYSQLDEF_DIR:=~

# env.shに合わせて変更する
DB_HOST:=127.0.0.1
DB_PORT:=3306
DB_USER:=isucon
DB_PASS:=isucon
DB_NAME:=isupipe

.PHONY: ssh
ssh:
	ssh $(APP_SERVER_1)

#######
# fetch
#######
.PHONY: fetch
fetch: fetch-webapp fetch-s1 fetch-s2 fetch-s3

.PHONY: fetch-webapp
fetch-webapp:
	@echo "\e[32mWebAppを取得します\e[m"
	rsync -az $(SERVER_1):/home/isucon/webapp/ $(CURDIR)/webapp

.PHONY: fetch-s1
fetch-s1:
	@echo "\e[32mServer1の設定を取得します\e[m"
	rsync -azL -e 'ssh -t' $(SERVER_1):/etc/mysql/ $(CURDIR)/s1/etc/mysql --rsync-path="sudo rsync"
	rsync -azL -e 'ssh -t' $(SERVER_1):/etc/nginx/ $(CURDIR)/s1/etc/nginx --rsync-path="sudo rsync"

.PHONY: fetch-s2
fetch-s2:
	@echo "\e[32mServer2の設定を取得します\e[m"
	rsync -azL -e 'ssh -t' $(SERVER_2):/etc/mysql/ $(CURDIR)/s2/etc/mysql --rsync-path="sudo rsync"
	rsync -azL -e 'ssh -t' $(SERVER_2):/etc/nginx/ $(CURDIR)/s2/etc/nginx --rsync-path="sudo rsync"

.PHONY: fetch-s3
fetch-s3:
	@echo "\e[32mServer3の設定を取得します\e[m"
	rsync -azL -e 'ssh -t' $(SERVER_3):/etc/mysql/ $(CURDIR)/s3/etc/mysql --rsync-path="sudo rsync"
	rsync -azL -e 'ssh -t' $(SERVER_3):/etc/nginx/ $(CURDIR)/s3/etc/nginx --rsync-path="sudo rsync"

######
# push
######
.PHONY: push
push: push-webapp push-s1 push-s2 push-s3

.PHONY: push-webapp
push-webapp:
	@echo "\e[32mWebAppのデータを送信します\e[m"
	rsync -az --exclude='.gitkeep' $(CURDIR)/webapp/ $(SERVER_1):/home/isucon/webapp
	rsync -az --exclude='.gitkeep' $(CURDIR)/webapp/ $(SERVER_2):/home/isucon/webapp
	rsync -az --exclude='.gitkeep' $(CURDIR)/webapp/ $(SERVER_3):/home/isucon/webapp

.PHONY: push-s1
push-s1:
	@echo "\e[32mServer1の設定を送信します\e[m"
	rsync -az --exclude='.gitkeep' $(CURDIR)/s1/home/isucon/ $(SERVER_1):/home/isucon
	rsync -azL -e 'ssh -t' --exclude='.gitkeep' $(CURDIR)/s1/etc/ $(SERVER_1):/etc --rsync-path="sudo rsync"

.PHONY: push-s2
push-s2:
	@echo "\e[32mServer2の設定を送信します\e[m"
	rsync -az --exclude='.gitkeep' $(CURDIR)/s2/home/isucon/ $(SERVER_2):/home/isucon
	rsync -azL -e 'ssh -t' --exclude='.gitkeep' $(CURDIR)/s2/etc/ $(SERVER_2):/etc --rsync-path="sudo rsync"

.PHONY: push-s3
push-s3:
	@echo "\e[32mServer3の設定を送信します\e[m"
	rsync -az --exclude='.gitkeep' $(CURDIR)/s3/home/isucon/ $(SERVER_3):/home/isucon
	rsync -azL -e 'ssh -t' --exclude='.gitkeep' $(CURDIR)/s3/etc/ $(SERVER_3):/etc --rsync-path="sudo rsync"

.PHONY: apply
apply:
	@echo "\e[32m設定を適用します\e[m"
	ssh -t $(APP_SERVER_1) "export PATH=\$$PATH:/home/isucon/local/golang/bin; cd $(WEBAPP_DIR)/go; make; sudo systemctl restart nginx.service"
	ssh -t $(APP_SERVER_2) "export PATH=\$$PATH:/home/isucon/local/golang/bin; cd $(WEBAPP_DIR)/go; make; sudo systemctl restart nginx.service"
	ssh -t $(DB_SERVER) "sudo systemctl restart mysql.service"
# TODO: マイグレーションを実行する場合も追記


.PHONY: etc-reflesh
etc:
	@echo "\e[32m/etc にファイルを配置します\e[m"
	sudo rm -rf /etc/mysql
	sudo rm -rf /etc/nginx
	sudo cp -r /usr/local/mysql /etc/mysql
	sudo cp -r /usr/local/mnginx /etc/nginx

.PHONY: etc-backup
etc-backup:
	@echo "\e[32m/etc を取得します\e[m"
	sudo cp /etc/mysql /usr/local/mysql
	sudo cp /etc/nginx /usr/local/nginx

.PHONY: conf-backup
etc-backup:
	cd /home/
	git clone https://github.com/cyg-isucon/getoru40man.git
	sudo cp /etc/mysql/mysql.cnf /home/getoru40man/conf/mysql.cnf
	sudo cp /etc/nginx/nginx.conf /home/getoru40man/conf/nginx.conf
	cd /etc/mysql
	sudo ln -s /home/getoru40man/conf/mysql.cnf mysql.cnf
	cd /etc/nginx
	sudo ln -s /home/getoru40man/conf/nginx.conf nginx.conf
	git commit -m "conf backup" -a
	git push origin master

.PHONY: setup
setup:
	ssh -t $(APP_SERVER_1) "\
		sudo dnf update; \
		sudo dnf install -y git zsh unzip percona-toolkit redis graphviz; \
		sudo dnf autoremove; \
		wget https://github.com/KLab/myprofiler/releases/download/0.2/myprofiler.linux_amd64.tar.gz; \
		tar xf myprofiler.linux_amd64.tar.gz; \
		rm myprofiler.linux_amd64.tar.gz; \
		sudo mv myprofiler /usr/local/bin/; \
		sudo chmod +x /usr/local/bin/myprofiler; \
		wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.tar.gz; \
		tar -zxvf alp_linux_amd64.tar.gz; \
		rm alp_linux_amd64.tar.gz; \
		sudo install alp /usr/local/bin/alp; \
		sudo chmod +x /usr/local/bin/alp; \
		wget -O - https://github.com/sqldef/sqldef/releases/latest/download/mysqldef_linux_amd64.tar.gz | tar xvz; \
		rm mysqldef_linux_amd64.tar.gz; \
		sudo mv mysqldef /usr/local/bin/; \
		sudo chmod +x /usr/local/bin/mysqldef;"

.PHONY: cleanup
cleanup:
	sudo dnf remove -y git zsh unzip percona-toolkit redis graphviz
	sudo dnf autoremove

.PHONY: mysql
mysql:
	ssh -t $(DB_SERVER) "mysql -h$(DB_HOST) -P$(DB_PORT) -u$(DB_USER) -p$(DB_PASS) $(DB_NAME)"

.PHONY: mysql-pull
mysql-pull:
	ssh -t $(DB_SERVER) "mysqldef -h$(DB_HOST) -P$(DB_PORT) -u$(DB_USER) -p$(DB_PASS) $(DB_NAME) --export > ${MYSQLDEF_DIR}/$(DB_NAME)_schema.sql;"
	scp $(DB_SERVER):/home/isucon/$(DB_NAME)_schema.sql $(CURDIR)/mysql/$(DB_NAME)_schema.sql
	code $(CURDIR)/mysql/$(DB_NAME)_schema.sql

.PHONY: mysql-push
mysql-push:
	scp $(CURDIR)/mysql/$(DB_NAME)_schema.sql $(DB_SERVER):/home/isucon/$(DB_NAME)_schema.sql
	ssh -t $(DB_SERVER) "mysqldef -h$(DB_HOST) -P$(DB_PORT) -u$(DB_USER) -p$(DB_PASS) $(DB_NAME) < ${MYSQLDEF_DIR}/$(DB_NAME)_schema.sql"

.PHONY: profile
profile:
	myprofiler -host=$(DB_HOST) -user=$(DB_USER) -password=$(DB_PASS) -interval=0.2 -delay=10 -top=30

.PHONY: profileL
profileL:
	myprofiler -host=$(DB_HOST) -user=$(DB_USER) -password=$(DB_PASS) -last=60 -delay=30 | rotatelogs logs/myprofiler.%Y%m%d 86400

ALPSORT=sum
ALPM=""
.PHONY: alp
alp:
	@echo "\e[32maccess logをalpで出力します\e[m"
	ssh -t ${APP_SERVER_1} 'sudo alp json --file /var/log/nginx/access.log --sort=avg -r -m "/api/user/[^/]+/theme,/api/user/[^/]+/statistics,/api/user/[^/]+/icon,/api/user/[^/]+/livestream,/api/user/[^/]+,/api/livestream/[^/]+/livecomment/[^/]+/report,/api/livestream/[^/]+/livecomment,/api/livestream/[^/]+/reaction,/api/livestream/[^/]+/report,/api/livestream/[^/]+/ngwords,/api/livestream/[^/]+/moderate,/api/livestream/[^/]+/enter,/api/livestream/[^/]+/exit,/api/livestream/[^/]+/statistics,/api/livestream/[^/]+"'
.PHONY: pt-query-digest
pt-query-digest:
	@echo "\e[32maccess logをpt-query-digestで出力します\e[m"
	ssh -t ${DB_SERVER} "sudo pt-query-digest $(MYSQL_LOG) > pt-query-digest.$(DATE).txt"

.PHONY: restart
restart:
	@echo "\e[32mサービスを再起動します\e[m"
	sudo systemctl restart mysql.service
	sudo systemctl restart nginx.service
	sudo systemctl restart redis.service

.PHONY: slow-on
slow-on:
	@echo "\e[32mMySQL slow-querry ONにします\e[m"
	sudo mysql -e "set global slow_query_log_file = '$(MYSQL_LOG)'; set global long_query_time = 0; set global slow_query_log = ON; set global log_queries_not_using_indexes = ON; set global log_slow_slave_statements = 1;"
	sudo mysql -e "show variables like 'slow%';"
	sudo mysql -e "show variables like 'log_queries%';"
	sudo mysql -e "show variables like 'log_slow_slave%';"

.PHONY: slow-off
slow-off:
	@echo "\e[32mMySQL slow-querry OFFにします\e[m"
	sudo mysql -e "set global slow_query_log = OFF;"
	sudo mysql -e "show variables like 'slow%';"
	sudo mysql -e "show variables like 'log_queries%';"
	sudo mysql -e "show variables like 'log_slow_slave%';"

.PHONY: rotate
rotate:
	sudo mv $(NGINX_LOG) $(NGINX_LOG).$(DATE)
	sudo nginx -s reopen
	sudo mv $(MYSQL_LOG) $(MYSQL_LOG).$(DATE)
	sudo touch $(MYSQL_LOG)
	sudo chown mysql:mysql $(MYSQL_LOG)

.PHONY: index
index:
	sudo mysql -e "alter table $(DB_NAME).livestream_tags add index idx_livestream_id (livestream_id);"
	sudo mysql -e "alter table $(DB_NAME).livestream_tags add index idx_tag_id_livestream_id (tag_id, livestream_id);"
	sudo mysql -e "alter table $(DB_NAME).livestreams add index idx_user_id (user_id);"
	sudo mysql -e "alter table $(DB_NAME).icons add index idx_user_id (user_id);"
	sudo mysql -e "alter table $(DB_NAME).livecomments add index idx_livestream_id (livestream_id);"
	sudo mysql -e "alter table $(DB_NAME).themes add index idx_user_id (user_id);"
	sudo mysql -e "alter table $(DB_NAME).reactions add index idx_livestream_id(livestream_id,created_at);"
	sudo mysql -e "alter table $(DB_NAME).livestream_viewers_history add index idx_user_id_livestream_id  (user_id, livestream_id);"
	sudo mysql -e "alter table $(DB_NAME).ng_words add index idx_livestream_id_user_id (livestream_id,user_id);"
	sudo mysql -e "alter table $(DB_NAME).reservation_slots add index idx_end_at (end_at);"
	sudo mysql -e "alter table $(DB_NAME).livecomment_reports add index idx_livestream_id(livestream_id);"
