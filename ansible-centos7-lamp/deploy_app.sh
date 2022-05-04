#!/bin/bash

# Overall OS variables 

psolab_os_password='ps0lab!'
psolab_govc_password=ps0Lab\!admin
OVF_bucket=psolab-ovas-dgo

# OS prerequisites
echo $psolab_os_password | sudo -S apt install git ansible -y
echo $psolab_os_password | sudo -S sed -i 's/#host_key_checking = False/host_key_checking = False/g' /etc/ansible/ansible.cfg 

## Set GOVC credentials
export GOVC_URL=https://172.16.10.2/sdk
export GOVC_USERNAME=administrator@psolab.local
export GOVC_PASSWORD=$psolab_govc_password
export GOVC_INSECURE=true

## gsutil requires a project_id to be set (skip if you already have done it)
project_id_default=$(gcloud projects list | grep migrate | tail -1 | awk '{print $1}')
gcloud config set project $project_id_default 


create_vm_from_ovf_template()
{
    current_ovf=$1
    target_vm_name=$2

    echo "create $target_vm_name VM from template $current_ovf"    
    if [[ -f "$current_ovf.ovf" ]]; then
       echo "$current_ovf ovf already present"

    else
       echo "$current_ovf ovf not present, downloading" 
       gsutil cp gs://$OVF_bucket/$current_ovf* .
    fi

    
    sed -i "s/^    \"Name\":.*$/    \"Name\": \"$target_vm_name\",/g" $current_ovf.json
    govc import.ovf --options=$current_ovf.json $current_ovf.ovf


}

NUMBER_OF_WEB_SERVER=5
NUMBER_OF_MYSQL_SERVER=3

for i in $( eval echo {1..$NUMBER_OF_WEB_SERVER} )
do
   create_vm_from_ovf_template centos7-base centos7-webapp-web-$i
done

for i in $( eval echo {1..$NUMBER_OF_MYSQL_SERVER} )
do
   create_vm_from_ovf_template centos7-base centos7-webapp-mysql-$i
done

create_vm_from_ovf_template centos7-base centos7-webapp-haproxy

rm $current_ovf.ovf

HAPROXY_IP=$(govc vm.ip centos7-webapp-haproxy)

git clone https://github.com/arocki7/ansible-centos7-lamp.git

cd ansible-centos7-lamp

echo '' > hosts
echo "[webservers]" >> hosts
for i in $( eval echo {1..$NUMBER_OF_WEB_SERVER} )
do
  current_ip=$(govc vm.ip centos7-webapp-web-$i) 
  echo $current_ip >> hosts
  ssh-keygen -f "/home/labUser/.ssh/known_hosts" -R $current_ip
done

echo "" >> hosts
echo "[dbservers]" >> hosts
for i in $( eval echo {1..$NUMBER_OF_MYSQL_SERVER} )
do
  current_ip=$(govc vm.ip centos7-webapp-mysql-$i) 
  echo $current_ip >> hosts
  ssh-keygen -f "/home/labUser/.ssh/known_hosts" -R $current_ip
done


cat > site-webserver.yml  << EOF
---
   
- name: deploy MySQL and configure databases
  hosts: dbservers
  remote_user: root
   
  roles:
   - db
   
- name: deploy Apache, PHP and configure website code
  hosts: webservers
  remote_user: root
   
  roles:
   - web

EOF


ansible -i hosts -m selinux -a 'state=disabled' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

ansible -i hosts -m rpm_key -a 'state=present key=https://repo.mysql.com/RPM-GPG-KEY-mysql-2022' dbservers --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

ansible-playbook -v -i hosts site-webserver.yml --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

# HAPROXY config

cat > haproxy_webservers.config <<EOF
frontend www.mysite.com
bind *:80
default_backend web_servers

backend web_servers
balance roundrobin
EOF

for i in $( eval echo {1..$NUMBER_OF_WEB_SERVER} )
do
  current_ip=$(govc vm.ip centos7-webapp-web-$i) 
  echo "server server$i $current_ip:80" >> haproxy_webservers.config
  
done

ansible -i $HAPROXY_IP, -m yum -a 'name=haproxy' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

ansible -i $HAPROXY_IP, -m copy -a 'src=haproxy_webservers.config dest=/tmp/haproxy_webservers.config' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

ansible -i $HAPROXY_IP, -m shell -a 'if grep "backend web_servers" /etc/haproxy/haproxy.cfg; then echo "config already present"; else cat /tmp/haproxy_webservers.config >> /etc/haproxy/haproxy.cfg; fi' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

ansible -i $HAPROXY_IP, -m service -a 'enabled=yes state=restarted name=haproxy' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

ansible -i $HAPROXY_IP, -m service -a 'enabled=no state=stopped name=firewalld' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"


echo "application IP is $HAPROXY_IP"
