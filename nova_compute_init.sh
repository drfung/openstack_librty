#! /usr/bin/bash
nova_compute_init(){
compute_install(){
sed -i "s/controller_ip=.*/controller_ip=`hostname -i`/g" nova_compute_install.sh
sed -i "s/controller_hostname=.*/controller_hostname=`hostname`/g" nova_compute_install.sh
rsync -avrz /root/fbo-tools/nova_compute_install.sh root@compute:/root/fbo-tools/
rsync -avrz /etc/nova/nova.conf root@compute:/root/fbo-tools/
ssh root@compute -C "bash /root/fbo-tools/nova_compute_install.sh"
}
check_install(){
source admin-openrc.sh
[ `nova service-list | grep nova-compute | grep enabled | grep up | wc -l` -eq 1 -a `openstack host list | grep nova | wc -l` -eq 1 ] && echo ok > /tmp/nova_compute_init.done
}
compute_install
check_install
}

main(){
cat /tmp/nova_compute_init.done > /dev/null 2>&1 || nova_compute_init
}

main
