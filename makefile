DATE:=$(shell date +%Y%m%d-%H%M%S)
CD:=$(CURDIR)
PROJECT_ROOT:=/home/isucon/webapp

# env.shに合わせて変更する
DB_HOST:=127.0.0.1
DB_PORT:=3306
DB_USER:=isucon
DB_PASS:=isucon
DB_NAME:=isupipe

NGINX_LOG:=/var/log/nginx/access.log
MYSQL_LOG:=/var/log/mysql/slow-query.log

.PHONY: etc-reflesh
etc:
	@echo "\e[32m/etc にファイルを配置します\e[m"
	sudo rm -rf /etc/mysql
	sudo rm -rf /etc/nginx
	sudo cp -r mysql /etc/mysql
	sudo cp -r nginx /etc/nginx

.PHONY: etc-backup
etc-backup:
	@echo "\e[32m/etc を取得します\e[m"
	sudo cp /etc/mysql mysql
	sudo cp /etc/nginx nginx

.PHONY: setup
setup:
	sudo apt update
	sudo apt install -y git zsh unzip percona-toolkit
	wget https://github.com/KLab/myprofiler/releases/download/0.2/myprofiler.linux_amd64.tar.gz
	tar xf myprofiler.linux_amd64.tar.gz
	rm myprofiler.linux_amd64.tar.gz
	sudo mv myprofiler /usr/local/bin/
	sudo chmod +x /usr/local/bin/myprofiler
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.21/alp_linux_amd64.tar.gz
	tar -zxvf alp_linux_amd64.tar.gz
	rm alp_linux_amd64.tar.gz
	sudo install alp /usr/local/bin/alp
	sudo chmod +x /usr/local/bin/alp

.PHONY: cleanup
cleanup:
	sudo apt remove -y git zsh unzip percona-toolkit

.PHONY: mysql
mysql:
	mysql -h$(DB_HOST) -P$(DB_PORT) -u$(DB_USER) -p$(DB_PASS) $(DB_NAME)

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
	sudo alp json --file /var/log/nginx/access.log --sort=avg -r -m "/api/user/[^/]+/theme,/api/user/[^/]+/statistics,/api/user/[^/]+/icon,/api/user/[^/]+/livestream,/api/user/[^/]+,/api/livestream/[^/]+/livecomment/[^/]+/report,/api/livestream/[^/]+/livecomment,/api/livestream/[^/]+/reaction,/api/livestream/[^/]+/report,/api/livestream/[^/]+/ngwords,/api/livestream/[^/]+/moderate,/api/livestream/[^/]+/enter,/api/livestream/[^/]+/exit,/api/livestream/[^/]+/statistics,/api/livestream/[^/]+"

.PHONY: restart
restart:
	@echo "\e[32mサービスを再起動します\e[m"
	sudo systemctl restart mysql.service
	sudo systemctl restart nginx.service

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
