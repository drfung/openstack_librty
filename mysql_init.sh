#! /bin/bash
mysql_init(){
yum install mariadb mariadb-server MySQL-python -y
cat > /etc/my.cnf << EOF
[client]
port		= 3306
socket		= /var/lib/mysql/mysql.sock
[mysqld]
default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8
log-error	= /var/log/mariadb/mariadb.log
port		= 3306
socket		= /var/lib/mysql/mysql.sock
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
log-bin=mysql-bin
binlog_format=mixed
server-id	= 1
[mysqldump]
quick
max_allowed_packet = 16M
[mysql]
no-auto-rehash
[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M
[mysqlhotcopy]
interactive-timeout
EOF

systemctl enable mariadb.service
systemctl start mariadb.service

mysql_secure_installation

sleep 3

for pd in keystone glance nova neutron cinder
do
mysql -u root -pfbo -e "CREATE DATABASE $pd;"
mysql -u root -pfbo -e "GRANT ALL PRIVILEGES ON $pd.* TO '$pd'@'localhost' IDENTIFIED BY '$pd';"
mysql -u root -pfbo -e "GRANT ALL PRIVILEGES ON $pd.* TO '$pd'@'%' IDENTIFIED BY '$pd';"
mysql -u root -pfbo -e "flush privileges;"
done

touch /tmp/mysql_init.done
}

[ -f /etc/mysql_init.done ] || mysql_init
