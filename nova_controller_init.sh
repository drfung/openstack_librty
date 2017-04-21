#! /usr/bin/bash
set -x
nova_controller_install(){
endpoint(){
#获得 admin 凭证来获取只有管理员能执行命令的访问权限：
source admin-openrc.sh
# 创建 nova 用户,添加admin角色到 nova 用户：
openstack user create --domain default --password nova nova
openstack role add --project service --user nova admin
# 创建nova服务实体：
openstack service create --name nova --description "OpenStack Compute" compute
# 创建计算服务API端点:
openstack endpoint create --region RegionOne compute public http://`hostname`:8774/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute internal http://`hostname`:8774/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute admin http://`hostname`:8774/v2/%\(tenant_id\)s
}
# 安装配置nova
install_nova(){
yum install -y openstack-nova-api openstack-nova-cert \
openstack-nova-conductor openstack-nova-console \
openstack-nova-novncproxy openstack-nova-scheduler \
python-novaclient

## [DEFAULT]
openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class  nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api  neutron
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver  nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend  rabbit
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy  keystone
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip `hostname -i` 
openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
openstack-config --set /etc/nova/nova.conf DEFAULT verbose  True

## [oslo_messaging_rabbit]
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host `hostname` 
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password openstack

## [database]
openstack-config --set /etc/nova/nova.conf database connection mysql://nova:nova@`hostname -i`/nova

## [keystone_authtoken]
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://`hostname`:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://`hostname`:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken password nova

## [vnc]
openstack-config --set /etc/nova/nova.conf vnc vncserver_listen \$my_ip
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address \$my_ip

## [glance]
openstack-config --set /etc/nova/nova.conf glance host \$my_ip

## [oslo_concurrency]
openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp

# 同步数据库
nova_table=$(mysql -unova -pnova -s nova -e  "show tables;" | wc -l)
[[ $nova_table -eq 0 ]] && su -s /bin/sh -c "nova-manage db sync" nova

table_check=$(mysql -unova -pnova -s nova -e  "show tables;" | wc -l)
[[ $table_check -eq 0 ]] || {
systemctl enable openstack-nova-api.service \
openstack-nova-cert.service openstack-nova-consoleauth.service \
openstack-nova-scheduler.service openstack-nova-conductor.service \
openstack-nova-novncproxy.service

systemctl start openstack-nova-api.service \
openstack-nova-cert.service openstack-nova-consoleauth.service \
openstack-nova-scheduler.service openstack-nova-conductor.service \
openstack-nova-novncproxy.service
}
}

nova_status(){
re=$(systemctl status openstack-nova-api.service \
openstack-nova-cert.service openstack-nova-consoleauth.service \
openstack-nova-scheduler.service openstack-nova-conductor.service \
openstack-nova-novncproxy.service | grep "active (running)" | wc -l
)
if [[ re -eq 6 ]]
then
return 0
else
return 110
fi
}

# endpoint
# install_nova
[[ nova_status -eq 0 ]]  && echo ok > /tmp/nova_controller_install.done

}

main(){
cat /tmp/nova_controller_install.done > /dev/null 2>&1 || nova_controller_install
}

main
