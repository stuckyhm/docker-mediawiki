#!/bin/bash

if [ -z "$(ls -A /var/lib/mysql)" ]; then
	cd /var/lib/mysql
	tar -xf ../mysql.tar.gz
#	mysql_install_db --user=mysql --datadir=/var/lib/mysql

	/usr/bin/pidproxy /var/run/mysqld/mysqld.pid /usr/sbin/mysqld &
	sleep 10

	MYSQL_ROOT_PASSWORD=$(pwgen -1 32)
	mysql -u root <<EOF
		SET @@SESSION.SQL_LOG_BIN=0;
		ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
		DROP USER 'debian-sys-maint'@'localhost';
		DROP DATABASE IF EXISTS test ;
		FLUSH PRIVILEGES ;
		SHUTDOWN ;
EOF
	echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
fi

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
