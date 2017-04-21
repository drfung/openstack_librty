#! /usr/bin/bash
#set -x

controller_ip=192.168.56.3
controller_hostname=controller

start_service(){
systemctl restart openstack-nova-compute.service         #前面修改了nova配置需要重启
systemctl enable neutron-linuxbridge-agent.service
systemctl start neutron-linuxbridge-agent.service
sleep 5
neutron_status=`systemctl status neutron-linuxbridge-agent.service | grep 'active (running)' | wc -l`
[[ $neutron_status -eq 1 ]] && echo ok > /tmp/neutron_compute_install.done
}

neutron_compute_install(){
yum install -y openstack-neutron openstack-neutron-linuxbridge ebtables ipset

openstack-config --set /etc/nova/nova.conf neutron url http://$controller_hostname:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://$controller_hostname:35357
openstack-config --set /etc/nova/nova.conf neutron auth_plugin password
openstack-config --set /etc/nova/nova.conf neutron project_domain_id default
openstack-config --set /etc/nova/nova.conf neutron user_domain_id default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password neutron

cat /root/fbo-tools/neutron.conf > /etc/neutron/neutron.conf
cat /root/fbo-tools/linuxbridge_agent.ini > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
cat /root/fbo-tools/ml2_conf.ini > /etc/neutron/plugins/ml2/ml2_conf.ini
rm -f /etc/neutron/plugin.ini
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
chown root:neutron /etc/neutron/plugins/ml2/*
start_service
}

main(){
cat /tmp/neutron_compute_install.done > /dev/null 2>&1 ||  neutron_compute_install
}

main
