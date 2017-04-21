#! /usr/bin/bash
set -x
check_url(){
curl -I http://`hostname`/dashboard > /tmp/horizon_status
if [ `grep HTTP /tmp/horizon_status | grep 200| wc -l` -eq 1 ]
then 
return 0
elif [ `grep HTTP /tmp/horizon_status | grep 302 | wc -l` -eq 1 ]
then
r_url=`grep Location /tmp/horizon_status | awk '{print $2}' | awk -F "?" '{print $1}'`
[ `curl -I $r_url 2>/dev/null | grep HTTP | grep 200 | wc -l` -eq 1 ] && return 0 || return 1
else
return 1
fi
}
horizon_init(){
yum install -y openstack-dashboard
sed -i "s/OPENSTACK_HOST =.*/OPENSTACK_HOST = \"`hostname`\"/g" /etc/openstack-dashboard/local_settings
sed -i "s/OPENSTACK_KEYSTONE_DEFAULT_ROLE =.*/OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"/g" /etc/openstack-dashboard/local_settings
sed -i "s/ALLOWED_HOSTS =.*/ALLOWED_HOSTS = \['\*',\]/g" /etc/openstack-dashboard/local_settings
sed -i "/^ *'BACKEND'.*/s/:.*/: 'django.core.cache.backends.memcached.MemcachedCache',/g" /etc/openstack-dashboard/local_settings
sed -i "/^ *'LOCATION':/d" /etc/openstack-dashboard/local_settings
sed -i "/^ *'BACKEND'.*/a\        'LOCATION': '127.0.0.1:11211'" /etc/openstack-dashboard/local_settings
sed -i "s/TIME_ZONE =.*/TIME_ZONE = \"Asia\/Shanghai\"/g" /etc/openstack-dashboard/local_settings
systemctl enable httpd.service memcached.service
memcached_status="systemctl status memcached | grep active | wc -l"
if [ $memcached_status -eq 1 ]
then systemctl restart memcached.service
else 
systemctl start memcached.service
fi
httpd_status="systemctl status httpd | grep active | wc -l"
if [ $httpd_status -eq 1 ]
then systemctl restart httpd.service
else 
systemctl start httpd.service
fi
check_url

if [ $? -eq 0 ]
then 
echo "Horizon install compelete" > /tmp/horizon_init.done
else
echo "Horizon intall failed, plz check..."
fi
}

cat /tmp/horizon_init.done > /dev/null 2>&1 || horizon_init
