#!/bin/bash

yum install  -y mariadb
systemctl start mariadb
systemctl enable mariadb

echo "CREATE DATABASE drupal CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" | mysql -u root
echo "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES ON drupal.* TO 'drupaluser'@'%' IDENTIFIED BY 'change-with-strong-password';" | mysql -u root
