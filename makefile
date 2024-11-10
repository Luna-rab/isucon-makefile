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
SERVER_1:=isucon1
SERVER_2:=isucon2
SERVER_3:=isucon3
APP_SERVER_1:=$(SERVER_1)
APP_SERVER_2:=$(SERVER_2)
DB_SERVER:=$(SERVER_3)


WEBAPP_DIR:=/home/isucon/webapp
NGINX_LOG:=/var/log/nginx/access.log
MYSQL_LOG:=/var/log/mysql/slow-query.log
MYSQLDEF_DIR:=~

# env.shに合わせて変更する
DB_HOST:=127.0.0.1
DB_PORT:=3306
DB_USER:=isucon
DB_PASS:=isucon
DB_NAME:=isupipe


#######
# fetch
#######
.PHONY: fetch
fetch: fetch-webapp fetch-s1 fetch-s2 fetch-s3

.PHONY: fetch-webapp
fetch-webapp:
	@echo -e "\e[32mWebAppを取得します\e[0m"
	rsync -az $(SERVER_1):/home/isucon/webapp/ $(CURDIR)/webapp

.PHONY: fetch-s1
fetch-s1:
	@echo -e "\e[32mServer1の設定を取得します\e[0m"
	rsync -azL -e 'ssh -t' $(SERVER_1):/etc/mysql/ $(CURDIR)/s1/etc/mysql --rsync-path="sudo rsync"
	rsync -azL -e 'ssh -t' $(SERVER_1):/etc/nginx/ $(CURDIR)/s1/etc/nginx --rsync-path="sudo rsync"

.PHONY: fetch-s2
fetch-s2:
	@echo -e "\e[32mServer2の設定を取得します\e[0m"
	rsync -azL -e 'ssh -t' $(SERVER_2):/etc/mysql/ $(CURDIR)/s2/etc/mysql --rsync-path="sudo rsync"
	rsync -azL -e 'ssh -t' $(SERVER_2):/etc/nginx/ $(CURDIR)/s2/etc/nginx --rsync-path="sudo rsync"

.PHONY: fetch-s3
fetch-s3:
	@echo -e "\e[32mServer3の設定を取得します\e[0m"
	rsync -azL -e 'ssh -t' $(SERVER_3):/etc/mysql/ $(CURDIR)/s3/etc/mysql --rsync-path="sudo rsync"
	rsync -azL -e 'ssh -t' $(SERVER_3):/etc/nginx/ $(CURDIR)/s3/etc/nginx --rsync-path="sudo rsync"

######
# push
######
.PHONY: push
push: push-webapp push-s1 push-s2 push-s3

.PHONY: push-webapp
push-webapp:
	@echo -e "\e[32mWebAppのデータを送信します\e[0m"
	rsync -az --exclude='.gitkeep' $(CURDIR)/webapp/ $(SERVER_1):/home/isucon/webapp
	rsync -az --exclude='.gitkeep' $(CURDIR)/webapp/ $(SERVER_2):/home/isucon/webapp
	rsync -az --exclude='.gitkeep' $(CURDIR)/webapp/ $(SERVER_3):/home/isucon/webapp

.PHONY: push-s1
push-s1:
	@echo -e "\e[32mServer1の設定を送信します\e[0m"
	rsync -az --exclude='.gitkeep' $(CURDIR)/s1/home/isucon/ $(SERVER_1):/home/isucon
	rsync -azL -e 'ssh -t' --exclude='.gitkeep' $(CURDIR)/s1/etc/ $(SERVER_1):/etc --rsync-path="sudo rsync"

.PHONY: push-s2
push-s2:
	@echo -e "\e[32mServer2の設定を送信します\e[0m"
	rsync -az --exclude='.gitkeep' $(CURDIR)/s2/home/isucon/ $(SERVER_2):/home/isucon
	rsync -azL -e 'ssh -t' --exclude='.gitkeep' $(CURDIR)/s2/etc/ $(SERVER_2):/etc --rsync-path="sudo rsync"

.PHONY: push-s3
push-s3:
	@echo -e "\e[32mServer3の設定を送信します\e[0m"
	rsync -az --exclude='.gitkeep' $(CURDIR)/s3/home/isucon/ $(SERVER_3):/home/isucon
	rsync -azL -e 'ssh -t' --exclude='.gitkeep' $(CURDIR)/s3/etc/ $(SERVER_3):/etc --rsync-path="sudo rsync"

.PHONY: apply
apply:
	@echo -e "\e[32m設定を適用します\e[0m"
	ssh -t $(APP_SERVER_1) "export PATH=\$$PATH:/home/isucon/local/golang/bin; cd $(WEBAPP_DIR)/go; make; sudo systemctl restart nginx.service"
	ssh -t $(APP_SERVER_2) "export PATH=\$$PATH:/home/isucon/local/golang/bin; cd $(WEBAPP_DIR)/go; make; sudo systemctl restart nginx.service"
	ssh -t $(DB_SERVER) "sudo systemctl restart mysql.service"
# TODO: マイグレーションを実行する場合も追記

.PHONY: setup
setup:
	ssh -t $(APP_SERVER_1) "\
		sudo apt install -y git zsh unzip percona-toolkit; \
		wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.tar.gz; \
		tar -zxvf alp_linux_amd64.tar.gz; \
		rm alp_linux_amd64.tar.gz; \
		sudo install alp /usr/local/bin/alp; \
		sudo chmod +x /usr/local/bin/alp; \
		wget -O - https://github.com/sqldef/sqldef/releases/latest/download/mysqldef_linux_amd64.tar.gz | tar xvz; \
		rm -f mysqldef_linux_amd64.tar.gz; \
		sudo mv mysqldef /usr/local/bin/; \
		sudo chmod +x /usr/local/bin/mysqldef;"

.PHONY: cleanup
cleanup:
	sudo dnf remove -y git zsh unzip redis wget percona-toolkit.noarch perl-CPAN
# TODO: graphviz(graphviz.aarch64)がremoveできない
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

ALPSORT=sum
ALPM=""
.PHONY: alp
alp:
	@echo -e "\e[32maccess logをalpで出力します\e[0m"
	ssh -t $(APP_SERVER_1) 'sudo alp json --file /var/log/nginx/access.log --sort=sum -r -m \
	"/api/admin/tenants/add,\
	/api/admin/tenants/billing,\
	/api/organizer/player/[^/]+/disqualified,\
	/api/organizer/players/add,\
	/api/organizer/players,\
	/api/organizer/competitions/add,\
	/api/organizer/competition/[^/]+/finish,\
	/api/organizer/competition/[^/]+/score,\
	/api/organizer/billing,\
	/api/organizer/competitions,\
	/api/player/competition/[^/]+/ranking,\
	/api/player/competitions,\
	/api/player/player/[^/]+,\
	/api/me"'

.PHONY: pt-query-digest
pt-query-digest:
	@echo -e "\e[32maccess logをpt-query-digestで出力します\e[0m"
	ssh -t $(DB_SERVER) "sudo pt-query-digest $(MYSQL_LOG) > $(MYSQL_LOG)/pt-query-digest-result.$(DATE).txt"

.PHONY: restart
restart:
	@echo -e "\e[32mサービスを再起動します\e[0m"
	ssh -t $(DB_SERVER) "sudo systemctl restart mysql.service"
	ssh -t $(APP_SERVER_1) "sudo systemctl restart nginx.service"
	ssh -t $(APP_SERVER_1) "sudo systemctl restart redis.service"
	ssh -t $(APP_SERVER_1) "sudo systemctl daemon-reload && sudo systemctl restart isuports.service"
	ssh -t $(APP_SERVER_2) "sudo systemctl daemon-reload && sudo systemctl restart isuports.service"
.PHONY: slow-on
slow-on:
	@echo -e "\e[32mMySQL slow-querry ONにします\e[0m"
	ssh -t $(DB_SERVER) 'sudo mysql -e "set global slow_query_log_file = \"$(MYSQL_LOG)\"; set global long_query_time = 0; set global slow_query_log = ON; set global log_queries_not_using_indexes = ON; set global log_slow_slave_statements = ON;"'
	ssh -t $(DB_SERVER) 'sudo mysql -e "show variables like \"slow%\";"'
	ssh -t $(DB_SERVER) 'sudo mysql -e "show variables like \"log_queries%\";"'
	ssh -t $(DB_SERVER) 'sudo mysql -e "show variables like \"log_slow_slave%\";"'

.PHONY: slow-off
slow-off:
	@echo -e "\e[32mMySQL slow-querry OFFにします\e[0m"
	ssh -t $(DB_SERVER) 'sudo mysql -e "set global slow_query_log = OFF; set global log_queries_not_using_indexes = OFF; set global log_slow_slave_statements = OFF;"'
	ssh -t $(DB_SERVER) 'sudo mysql -e "show variables like \"slow%\";"'
	ssh -t $(DB_SERVER) 'sudo mysql -e "show variables like \"log_queries%\";"'
	ssh -t $(DB_SERVER) 'sudo mysql -e "show variables like \"log_slow_slave%\";"'

.PHONY: rotate
rotate:
	ssh -t $(APP_SERVER_1) "sudo mv $(NGINX_LOG) $(NGINX_LOG).$(DATE)"
	ssh -t $(APP_SERVER_1) "sudo nginx -s reopen"
	ssh -t $(DB_SERVER) "sudo mv $(MYSQL_LOG) $(MYSQL_LOG).$(DATE)"
	ssh -t $(DB_SERVER) "sudo touch $(MYSQL_LOG)"
	ssh -t $(DB_SERVER) "sudo chown mysql:mysql $(MYSQL_LOG)"
