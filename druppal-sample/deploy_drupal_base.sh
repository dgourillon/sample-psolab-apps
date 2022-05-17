#!/bin/bash

IP_MYSQL=$1

sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux
setenforce 0

systemctl disable firewalld
systemctl stop firewalld

 yum install epel-release yum-utils -y

 sudo yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y

 yum-config-manager --enable remi-php72

 sudo yum install nginx php-cli php-fpm php-mysql php-json php-opcache php-mbstring php-xml php-gd php-curl git unzip -y

systemctl start nginx
systemctl enable nginx

 sed -i 's/user = apache/user = nginx/g' /etc/php-fpm.d/www.conf 
 sed -i 's/group = apache/group = nginx/g' /etc/php-fpm.d/www.conf 
 sed -i 's/;listen.owner = nobody/listen.owner = nginx/g' /etc/php-fpm.d/www.conf 
 sed -i 's/;listen.group = nobody/listen.group = nginx/g' /etc/php-fpm.d/www.conf 
 sed -i 's/listen = 127.0.0.1:9000/listen = \/run\/php-fpm\/www.sock/g' /etc/php-fpm.d/www.conf 

chown -R root:nginx /var/lib/php

sudo systemctl enable php-fpm
sudo systemctl start php-fpm

 curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
 /usr/local/bin/composer create-project drupal-composer/drupal-project:8.x-dev /var/www/my_drupal --stability dev --no-interaction

