#! /usr/bin/bash
#set -x
compute_install(){
sed -i "s/controller_ip=.*/controller_ip=`hostname -i`/g" neutron_compute_install.sh
sed -i "s/controller_hostname=.*/controller_hostname=`hostname`/g" neutron_compute_install.sh
rsync -avrz /root/fbo-tools/neutron_compute_install.sh root@compute:/root/fbo-tools/
rsync -avrz /etc/neutron/neutron.conf root@compute:/root/fbo-tools/
rsync -avrz /etc/neutron/plugins/ml2/linuxbridge_agent.ini root@compute:/root/fbo-tools/
rsync -avrz /etc/neutron/plugins/ml2/ml2_conf.ini root@compute:/root/fbo-tools/

ssh root@compute -C "bash /root/fbo-tools/neutron_compute_install.sh"
}

check_install(){
source admin-openrc.sh
check_status=`neutron agent-list | grep "neutron-linuxbridge-agent" | grep "True" | wc -l`
[  $check_status -eq 2 ] && echo ok > /tmp/neutron_compute_init.done
}

neutron_compute_init(){
compute_install
check_install
}

main(){
cat /tmp/neutron_compute_init.done > /dev/null 2>&1 || neutron_compute_init
}

main
