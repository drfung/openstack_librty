#! /bin/bash
set -x
for i in controller compute
do
ssh $i -C "yum install centos-release-openstack-liberty -y"
ssh $i -C "yum install python-openstackclient openstack-utils -y"
done

