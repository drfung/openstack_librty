#! /bin/bash
cinder_controller_init(){
	# install cinder controller node
	cat /tmp/cinder_endpoint.done > /dev/null 2>&1 || cinder_endpoint
	yum install -y openstack-cinder python-cinderclient
	cinder_config
	cinder_db=`mysql -ucinder -pcinder -s cinder -e "show tables" | wc -l`
	if [ $cinder_db -eq 0 ]
	then
		su -s /bin/sh -c "cinder-manage db sync" cinder && echo ok > /tmp/cinder_db.done
	else
		echo ok > /tmp/cinder_d.done
	fi
	if [ -f /tmp/cinder_db.done ]
	then
		systemctl restart openstack-nova-api.service
		systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
		systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service
		echo "cinder controller install suceses" && touch /tmp/cinder_controller_init.done
	else
		echo "database rsync fail, please check"
	fi
}

cinder_endpoint(){
	source admin-openrc.sh
	openstack user create --domain default --password cinder cinder
	openstack role add --project service --user cinder admin
	openstack service create --name cinder \
		  --description "OpenStack Block Storage" volume
	openstack service create --name cinderv2 \
		  --description "OpenStack Block Storage" volumev2
	openstack endpoint create --region RegionOne \
		  volume public http://`hostname`:8776/v1/%\(tenant_id\)s
	openstack endpoint create --region RegionOne \
		  volume internal http://`hostname`:8776/v1/%\(tenant_id\)s
	openstack endpoint create --region RegionOne \
		  volume admin http://`hostname`:8776/v1/%\(tenant_id\)s
	openstack endpoint create --region RegionOne \
		  volume public http://`hostname`:8776/v2/%\(tenant_id\)s
	openstack endpoint create --region RegionOne \
		  volume internal http://`hostname`:8776/v2/%\(tenant_id\)s
	openstack endpoint create --region RegionOne \
		  volume admin http://`hostname`:8776/v2/%\(tenant_id\)s
	echo ok > /tmp/cinder_endpoint.done
}

cinder_config(){
	openstack-config --set /etc/cinder/cinder.conf DEFAULT my_ip `hostname -i`
	openstack-config --set /etc/cinder/cinder.conf DEFAULT glance_host `hostname`
	openstack-config --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
	openstack-config --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
	openstack-config --set /etc/cinder/cinder.conf database connection mysql://cinder:cinder@`hostname -i`/cinder
	openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://`hostname`:5000
	openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://`hostname`:35357
	openstack-config --set /etc/cinder/cinder.conf keystone_authtoken auth_plugin password
	openstack-config --set /etc/cinder/cinder.conf keystone_authtoken project_domain_id default
	openstack-config --set /etc/cinder/cinder.conf keystone_authtoken user_domain_id default
	openstack-config --set /etc/cinder/cinder.conf keystone_authtoken project_name service
	openstack-config --set /etc/cinder/cinder.conf keystone_authtoken username cinder
	openstack-config --set /etc/cinder/cinder.conf keystone_authtoken password cinder
	openstack-config --set /etc/cinder/cinder.conf oslo_concurrency lock_path /var/lib/cinder/tmp
	openstack-config --set /etc/cinder/cinder.conf slo_messaging_rabbit rabbit_host `hostname`
	openstack-config --set /etc/cinder/cinder.conf slo_messaging_rabbit rabbit_userid openstack
	openstack-config --set /etc/cinder/cinder.conf slo_messaging_rabbit rabbit_password openstack
	openstack-config --set /etc/nova/nova.con cinder os_region_name RegionOne
}

[ -f /tmp/cinder_controller_init.done ] || cinder_controller_init
