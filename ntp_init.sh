#! /bin/bash

function ntp_init()
{
if [[ $1 == controller ]]
then
yum install chrony -y
sed -i "/^#allow/a\allow 192.168.56.0\/24" /etc/chrony.conf # 允许本网段访问
systemctl enable chronyd.service # 设置开机启动
systemctl start chronyd.service
timedatectl set-timezone Asia/Shanghai # 设置时区为东八区
touch /tmp/ntp_init.done
elif [[ $1 == compute ]]
then
yum install chrony -y
sed -i "s/^server /#server /g" /etc/chrony.conf
sed -i -e '1,/^#server/{/^#server/i\server\tcontroller\tiburst' -e'}' /etc/chrony.conf # ntp server 指向linux-node1
systemctl enable chronyd.service
systemctl start chronyd.service
timedatectl set-timezone Asia/Shanghai
touch /tmp/ntp_init.done
else
echo "controller or compute"
fi
}

[[ ! -f /tmp/ntp_init.done ]] && ntp_init $1
