#!/bin/bash

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

NUMBER_OF_LB_SERVER=1
NUMBER_OF_APP_SERVER=3
NUMBER_OF_DB_SERVER=3
NUMBER_OF_CACHE_SERVER=3


for i in $( eval echo {1..$NUMBER_OF_LB_SERVER} )
do
   create_vm_from_ovf_template centos7-base centos7-wordpress-lb-$i
done

for i in $( eval echo {1..$NUMBER_OF_APP_SERVER} )
do
   create_vm_from_ovf_template centos7-base centos7-wordpress-app-$i
done

for i in $( eval echo {1..$NUMBER_OF_DB_SERVER} )
do
   create_vm_from_ovf_template centos7-base centos7-wordpress-db-$i
done

for i in $( eval echo {1..$NUMBER_OF_CACHE_SERVER} )
do
   create_vm_from_ovf_template centos7-base centos7-wordpress-cache-$i
done


git clone https://github.com/OnstakInc/ansible-multi-tier-app.git

cd ansible-multi-tier-app

echo '' > hosts
echo "[lb]" >> hosts
for i in $( eval echo {1..$NUMBER_OF_LB_SERVER} )
do
  current_ip=$(govc vm.ip centos7-wordpress-lb-$i) 
  echo $current_ip >> hosts
  ssh-keygen -f "/home/labUser/.ssh/known_hosts" -R $current_ip
done
echo '' >> hosts
echo "[app]" >> hosts
for i in $( eval echo {1..$NUMBER_OF_APP_SERVER} )
do
  current_ip=$(govc vm.ip centos7-wordpress-app-$i) 
  echo $current_ip >> hosts
  ssh-keygen -f "/home/labUser/.ssh/known_hosts" -R $current_ip
 
done
echo '' >> hosts
echo "[db]" >> hosts
for i in $( eval echo {1..$NUMBER_OF_DB_SERVER} )
do
    current_ip=$(govc vm.ip centos7-wordpress-db-$i) 
  echo $current_ip >> hosts
  ssh-keygen -f "/home/labUser/.ssh/known_hosts" -R $current_ip

done
echo '' >> hosts
echo "[cache]" >> hosts

for i in $( eval echo {1..$NUMBER_OF_CACHE_SERVER} )
do
    current_ip=$(govc vm.ip centos7-wordpress-cache-$i) 
  echo $current_ip >> hosts
  ssh-keygen -f "/home/labUser/.ssh/known_hosts" -R $current_ip

done

ansible -i hosts -m selinux -a 'state=disabled' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

ansible -i hosts -m yum -a 'name=epel-release state=present' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

ansible -i hosts -m rpm_key -a 'state=present key=https://repo.mysql.com/RPM-GPG-KEY-mysql-2022' db --extra-vars "ansible_user=root ansible_password=$psolab_os_password"

ansible-playbook playbooks/deploy.yml -i hosts --extra-vars "ansible_user=root ansible_password=$psolab_os_password"
