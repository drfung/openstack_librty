#! /usr/bin/bash

#set -x
function keystone_server_install(){
# 安装keystone apache memcached（用来存储token）
yum install -y openstack-keystone httpd mod_wsgi memcached python-memcached
# 启动memchache
systemctl enable memcached.service
systemctl start memcached.service
# 修改keystone配置文件
cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf."date %Y%m%d_%H%M%S"
# open_key=`openssl rand -hex 10` # 生成随机码 c630ab770a246b68531f
open_key=c630ab770a246b68531f
openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $open_key
openstack-config --set /etc/keystone/keystone.conf database connection mysql://keystone:keystone@`hostname -i`/keystone
openstack-config --set /etc/keystone/keystone.conf memcache servers localhost:11211
openstack-config --set /etc/keystone/keystone.conf token provider uuid
openstack-config --set /etc/keystone/keystone.conf token driver memcache
openstack-config --set /etc/keystone/keystone.conf revoke driver sql
openstack-config --set /etc/keystone/keystone.conf DEFAULT verbose true
# 配置apache服务
sed -i "s,^#ServerName.*80$,ServerName `hostname -i`:80,g" /etc/httpd/conf/httpd.conf 
## 创建文件 /etc/httpd/conf.d/wsgi-keystone.conf
cat > /etc/httpd/conf.d/wsgi-keystone.conf << EOF
Listen 5000
Listen 35357

<VirtualHost *:5000>
	WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
	WSGIProcessGroup keystone-public
	WSGIScriptAlias / /usr/bin/keystone-wsgi-public
	WSGIApplicationGroup %{GLOBAL}
	WSGIPassAuthorization On
	<IfVersion >= 2.4>
	  ErrorLogFormat "%{cu}t %M"
	</IfVersion>
	ErrorLog /var/log/httpd/keystone-error.log
	CustomLog /var/log/httpd/keystone-access.log combined

	<Directory /usr/bin>
		<IfVersion >= 2.4>
			Require all granted
		</IfVersion>
		<IfVersion < 2.4>
			Order allow,deny
			Allow from all
		</IfVersion>
	</Directory>
</VirtualHost>

<VirtualHost *:35357>
	WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
	WSGIProcessGroup keystone-admin
	WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
	WSGIApplicationGroup %{GLOBAL}
	WSGIPassAuthorization On
	<IfVersion >= 2.4>
	  ErrorLogFormat "%{cu}t %M"
	</IfVersion>
	ErrorLog /var/log/httpd/keystone-error.log
	CustomLog /var/log/httpd/keystone-access.log combined

	<Directory /usr/bin>
		<IfVersion >= 2.4>
			Require all granted
		</IfVersion>
		<IfVersion < 2.4>
			Order allow,deny
			Allow from all
		</IfVersion>
	</Directory>
</VirtualHost>
EOF
# 启动apache服务
systemctl enable httpd.service
systemctl start httpd.service
# 同步数据库
db_show=`mysql -ukeystone -pkeystone -skeysotne -e "show tables" | wc -l`
[ $db_show -eq 0 ] && su -s /bin/sh -c "keystone-manage db_sync" keystone 
db_check=`mysql -ukeystone -pkeystone -skeysotne -e "show tables" | wc -l`
[ $db_check -ne 0 ] &&  touch /tmp/keystone_server_install.done
}

keystone_endpoint_init(){
# 配置认证令牌
export OS_TOKEN=c630ab770a246b68531f
export OS_URL=http://`hostname`:35357/v3
export OS_IDENTITY_API_VERSION=3
# 为身份认证服务创建服务实体
openstack service create --name keystone --description "OpenStack Identity" identity
## 身份认证服务管理了一个与您环境相关的 API 端点的目录。服务使用这个目录来决定如何与您环境中的其他服务进行通信。OpenStack使用三个API端点变种代表每种服务：admin，internal和public。
openstack endpoint create --region RegionOne identity public http://`hostname`:5000/v2.0
openstack endpoint create --region RegionOne identity internal http://`hostname`:5000/v2.0
openstack endpoint create --region RegionOne identity admin http://`hostname`:35357/v2.0
# 创建admin管理的项目、用户和角色：
openstack project create --domain default --description "Admin Project" admin
openstack user create --domain default --password-prompt admin
openstack role create admin
openstack role add --project admin --user admin admin
# 创建service项目：
openstack project create --domain default --description "Service Project" service
# 创建 demo 项目和用户 user。
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password-prompt demo
openstack role create user
openstack role add --project demo --user demo user # 添加user角色到demo项目和用户：
# check
unset OS_TOKEN OS_URL
check_v=`openstack --os-auth-url http://`hostname`:35357/v3 --os-project-domain-id default --os-user-domain-id default --os-project-name admin --os-username admin --os-auth-type password --os-password admin token issue | wc -l`
if [[ $check_v == 8 ]];then touch /tmp/keystone_endpoint_init.done;fi
}

create_env(){
cat > admin-openrc.sh << EOF
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=admin
export OS_AUTH_URL=http://`hostname`:35357/v3
export OS_IDENTITY_API_VERSION=3
EOF
 
cat > demo-openrc.sh << EOF
export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=demo
export OS_TENANT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=demo
export OS_AUTH_URL=http://`hostname`:5000/v3
export OS_IDENTITY_API_VERSION=3
EOF

echo ok > /tmp/create_env.done
}

main(){
[ -f /tmp/keystone_server_install.done ] || keystone_server_install
[ -f /tmp/keystone_endpoint_init.done ] || keystone_endpoint_init
[ -f /tmp/create_env.done ] || create_env
}

main
