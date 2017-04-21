#! /bin/bash
rabbitmq_init(){
yum install rabbitmq-server -y
# 设置开机启动
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service # rabbitmq端口是5672
# 添加openstack用户
rabbitmqctl add_user openstack openstack 
# 给 openstack 用户配置写和读权限：
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
# 查看rabbitmq所有插件,打开web管理插件
# rabbitmq-plugins list
rabbitmq-plugins enable rabbitmq_management
systemctl restart rabbitmq-server.service # web界面监听15672，默认用户密码：guest/guest
echo ok > /tmp/rabbitmq_init.done
}

[ -f /tmp/rabbitmq_init.done ] || rabbitmq_init
