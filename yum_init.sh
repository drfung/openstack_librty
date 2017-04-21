#! /bin/bash

function aliyum()
{
cd /etc/yum.repos.d
mv CentOS-Base.repo CentOS-Base.repo.bak
ls | grep -Ev "CentOS-Base.repo|epel.repo" | xargs -I {} rm -rf {}
wget -O CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum clean all && yum makecache && touch /tmp/aliyum.done
}
yum install wget net-tools psmisc -y
[[ ! -f /tmp/aliyum.done ]] && aliyum;
