#!/bin/bash

sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux
setenforce 0

systemctl stop firewalld
systemctl disable firewalld

yum install  -y mariadb
 systemctl start mariadb
 systemctl enable mariadb

 yum install nginx mariadb-server -y
 systemctl start nginx mariadb
 systemctl enable nginx mariadb


echo "CREATE DATABASE drupal CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" | mysql -u root
echo "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES ON drupal.* TO 'drupaluser'@'localhost' IDENTIFIED BY 'change-with-strong-password';" | mysql -u root


 yum install epel-release yum-utils -y

 sudo yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y

 yum-config-manager --enable remi-php72

 sudo yum install php-cli php-fpm php-mysql php-json php-opcache php-mbstring php-xml php-gd php-curl git unzip -y

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

 cd /var/www/my_drupal/

vendor/bin/drush site-install --db-url=mysql://drupaluser:change-with-strong-password@localhost/drupal -y -account-pass='ps0lab!'
sudo chown -R nginx: /var/www/my_drupal

cat <<'EOF' >/etc/nginx/nginx.conf

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /var/www/my_drupal/web;
        index index.php

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        error_page 404 /404.html;
        location = /404.html {
        }

        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
        }
   
            location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ~ \..*/.*\.php$ {
        return 403;
    }

    location ~ ^/sites/.*/private/ {
        return 403;
    }

    # Block access to scripts in site files directory
    location ~ ^/sites/[^/]+/files/.*\.php$ {
        deny all;
    }

    # Block access to "hidden" files and directories whose names begin with a
    # period. This includes directories used by version control systems such
    # as Subversion or Git to store control files.
    location ~ (^|/)\. {
        return 403;
    }

    location / {
        try_files $uri /index.php?$query_string;
    }

    location @rewrite {
        rewrite ^/(.*)$ /index.php?q=$1;
    }

    # Don't allow direct access to PHP files in the vendor directory.
    location ~ /vendor/.*\.php$ {
        deny all;
        return 404;
    }


    location ~ '\.php$|^/update.php' {
        fastcgi_split_path_info ^(.+?\.php)(|/.*)$;
        include fastcgi_params;
        # Block httpoxy attacks. See https://httpoxy.org/.
        fastcgi_param HTTP_PROXY "";
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param QUERY_STRING $query_string;
        fastcgi_intercept_errors on;
        fastcgi_pass unix:/run/php-fpm/www.sock;
    }

    # Fighting with Styles? This little gem is amazing.
    # location ~ ^/sites/.*/files/imagecache/ { # For Drupal <= 6
    location ~ ^/sites/.*/files/styles/ { # For Drupal >= 7
        try_files $uri @rewrite;
    }

    # Handle private files through Drupal. Private file's path can come
    # with a language prefix.
    location ~ ^(/[a-z\-]+)?/system/files/ { # For Drupal >= 7
        try_files $uri /index.php?$query_string;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        try_files $uri @rewrite;
        expires max;
        log_not_found off;
    }
  }
}
EOF

sudo service nginx restart && sudo service php-fpm restart
setsebool -P httpd_enable_homedirs 1


sudo -u nginx /usr/local/bin/composer require drupal/pathauto