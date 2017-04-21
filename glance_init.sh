#! /usr/bin/bash 
glance_install(){
# 创建 glance 用户,添加 admin 角色到 glance 用户和 service 项目上。
openstack user create --domain default --password glance glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "Openstack Image service" image
openstack endpoint create --region RegionOne image public http://`hostname`:9292
openstack endpoint create --region RegionOne image internal http://`hostname`:9292
openstack endpoint create --region RegionOne image admin http://`hostname`:9292
# 安装并配置组件
yum install openstack-glance python-glance python-glanceclient -y
# /etc/glance/glance-api.conf
openstack-config --set /etc/glance/glance-api.conf DEFAULT notification_driver noop
openstack-config --set /etc/glance/glance-api.conf DEFAULT verbose True
openstack-config --set /etc/glance/glance-api.conf database connection mysql://glance:glance@`hostname -i`/glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://`hostname`:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://`hostname`:35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken username glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken password glance
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone
openstack-config --set /etc/glance/glance-api.conf glance_store default_store file
openstack-config --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/
# /etc/glance/glance-regitry.conf
openstack-config --set /etc/glance/glance-registry.conf DEFAULT notification_driver noop
openstack-config --set /etc/glance/glance-registry.conf DEFAULT verbose True
openstack-config --set /etc/glance/glance-registry.conf database connection mysql://glance:glance@`hostname -i`/glance 
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://`hostname`:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://`hostname`:35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken username glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken password glance
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

# 同步数据库
su -s /bin/sh -c "glance-manage db_sync" glance
if [[ `echo $?` == 0 ]];then
systemctl enable openstack-glance-api.service openstack-glance-registry.service;
systemctl start openstack-glance-api.service openstack-glance-registry.service
[ $(systemctl status openstack-glance-api.service openstack-glance-registry.service | grep active | wc -l) -eq 2 ]  && echo ok > /tmp/glance_install.done
else
echo "glance install faild, plz check the configure files..."
fi
}
glance_check(){
[ `grep OS_IMAGE_API_VERSION admin-openrc.sh | wc -l` -eq 0 ] && echo "export OS_IMAGE_API_VERSION=2" >> admin-openrc.sh
[ `grep OS_IMAGE_API_VERSION demo-openrc.sh | wc -l` -eq 0 ] && echo "export OS_IMAGE_API_VERSION=2" >> demo-openrc.sh
# 下载源镜像
wget http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
# 使用 QCOW2 磁盘格式， bare 容器格式上传镜像到镜像服务并设置公共可见，这样所有的项目都可以访问它：
glance image-create --name "cirros" --file cirros-0.3.5-x86_64-disk.img --disk-format qcow2 --container-format bare --visibility public --progress
image_id=`glance image-list | grep cirros | awk -F "|" '{print $2}'`
[[ $(ls /var/lib/glance/images/ | grep $image_id | wc -l) == 1 ]] && echo ok > /tmp/glance_check.done 
}

main(){
cat /tmp/glance_install.done  > /dev/null 2>&1 || glance_install
cat /tmp/glance_check.done > /dev/null 2>&1 || glance_check
}

main
