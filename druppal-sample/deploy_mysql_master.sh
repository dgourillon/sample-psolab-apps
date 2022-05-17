#!/bin/bash

sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux
setenforce 0

systemctl disable firewalld
systemctl stop firewalld

yum install  -y mariadb-server
systemctl start mariadb
systemctl enable mariadb

echo "CREATE DATABASE drupal CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" | mysql -u root
echo "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES ON drupal.* TO 'drupaluser'@'%' IDENTIFIED BY 'change-with-strong-password';" | mysql -u root

