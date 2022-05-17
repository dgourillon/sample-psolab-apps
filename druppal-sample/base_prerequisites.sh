#!/bin/bash

sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux
setenforce 0

systemctl stop firewalld
systemctl disable firewalld

sudo yum install epel-release yum-utils -y
sudo yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
sudo yum-config-manager --enable remi-php72