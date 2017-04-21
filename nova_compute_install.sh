#! /usr/bin/bash
#set -x
controller_ip=192.168.56.3
controller_hostname=controller
nova_compute_install(){
yum install openstack-nova-compute sysfsutils -y
[[ -f /root/fbo-tools/nova.conf ]] && cp -f /root/fbo-tools/nova.conf /etc/nova/nova.conf
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip `hostname -i`
openstack-config --set /etc/nova/nova.conf vnc novncproxy_base_url http://$controller_hostname:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address \$my_ip
openstack-config --set /etc/nova/nova.conf vnc enabled True
openstack-config --set /etc/nova/nova.conf glance host $controller_hostname
if [[ `egrep -c '(vmx|svm)' /proc/cpuinfo` -eq 0 ]]
then
openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu
else
openstack-config --set /etc/nova/nova.conf libvirt virt_type kvm
fi
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
sleep 5
[[ `systemctl status libvirtd.service openstack-nova-compute.service | grep 'active (running)' | wc -l` -eq 2 ]] && echo ok > /tmp/nova_compute_install.done
}

main(){
cat /tmp/nova_compute_install.done > /dev/null 2>&1 ||  nova_compute_install
}

main
