#! /usr/bin/bash
set -x
endpoint(){
#获得 admin 凭证来获取只有管理员能执行命令的访问权限：
source admin-openrc.sh
openstack user create --domain default --password neutron neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region RegionOne network public http://`hostname`:9696
openstack endpoint create --region RegionOne network internal http://`hostname`:9696
openstack endpoint create --region RegionOne network admin http://`hostname`:9696
}

install_neutron(){
# 安装配置nova
yum install -y openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge python-neutronclient ebtables ipset
echo > /etc/neutron/neutron.conf
## [DEFAULT]
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins router
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT nova_url http://`hostname`:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT verbose True

## [oslo_messaging_rabbit]
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host `hostname`
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid openstack
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password openstack

## [database]
openstack-config --set /etc/neutron/neutron.conf database connection mysql://neutron:neutron@`hostname -i`/neutron

## [keystone_authtoken]
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://`hostname`:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://`hostname`:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_plugin password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_id default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_id default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password neutron

## [nova]
openstack-config --set /etc/neutron/neutron.conf nova auth_url http://`hostname`:35357
openstack-config --set /etc/neutron/neutron.conf nova auth_plugin password
openstack-config --set /etc/neutron/neutron.conf nova project_domain_id default
openstack-config --set /etc/neutron/neutron.conf nova user_domain_id default
openstack-config --set /etc/neutron/neutron.conf nova region_name RegionOne
openstack-config --set /etc/neutron/neutron.conf nova project_name service
openstack-config --set /etc/neutron/neutron.conf nova username nova
openstack-config --set /etc/neutron/neutron.conf nova password nova

## [oslo_concurrency]
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp

# /etc/neutron/plugins/ml2/linuxbridge_agent.ini
cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini "/etc/neutron/plugins/ml2/linuxbridge_agent.ini_`date %Y%m%sd_%H%M%S`"
echo > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings physnet1:`ip a | grep qlen | awk -F ":" '{print $2}' | cut -d " " -f2`
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan False
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

# /etc/neutron/plugins/ml2/ml2_conf.ini
cp /etc/neutron/plugins/ml2/ml2_conf.ini "/etc/neutron/plugins/ml2/ml2_conf.ini_`date %Y%m%d_%H%M%S`"
echo > /etc/neutron/plugins/ml2/ml2_conf.ini

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan,gre,vxlan,geneve
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vlan,gre,vxlan,geneve
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch,linuxbridge
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks physnet1
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True

# /etc/neutron/dhcp_agent.ini
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata true

# /etc/neutron/metadata_agent.ini
echo > /etc/neutron/metadata_agent.ini
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_uri http://`hostname`:5000
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://`hostname`:35357
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_region RegionOne
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT auth_plugin password
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT project_domain_id default
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT user_domain_id default
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT project_name service
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT username neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT password neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip `hostname`
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT verbose True

# /etc/nova/nova.conf
openstack-config --set /etc/nova/nova.conf neutron url http://`hostname`:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://`hostname`:35357
openstack-config --set /etc/nova/nova.conf neutron auth_plugin password
openstack-config --set /etc/nova/nova.conf neutron project_domain_id default
openstack-config --set /etc/nova/nova.conf neutron user_domain_id default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password neutron
openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy True
openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret neutron

# /etc/neutron/plugin.ini
rm -f /etc/neutron/plugin.ini
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
}

rsync_database(){
# 同步数据库
neutron_table=$(mysql -uneutron -pneutron -s neutron -e  "show tables;" | wc -l)
[[ $neutron_table -eq 0 ]] && su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
--config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron


table_check=$(mysql -uneutron -pneutron -s neutron -e  "show tables;" | wc -l)
[[ $table_check -eq 0 ]] || {
systemctl restart openstack-nova-api.service
systemctl enable neutron-server.service \
   neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
   neutron-metadata-agent.service
systemctl start neutron-server.service \
   neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
   neutron-metadata-agent.service
} 
}

neutron_status(){
re=$(systemctl status neutron-server.service \
   neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
   neutron-metadata-agent.service | grep "active (running)" | wc -l
)
if [[ re -eq 4 ]]
then
return 0
else
return 110
fi
}

neutron_controller_install(){
endpoint
install_neutron
rsync_database
[[ neutron_status -eq 0 ]]  && echo ok > /tmp/neutron_controller_install.done
}

main(){
cat /tmp/neutron_controller_install.done > /dev/null 2>&1 || neutron_controller_install
}

main
