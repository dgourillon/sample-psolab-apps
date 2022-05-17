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

NUMBER_OF_APP_SERVERS=1
NUMBER_OF_DB_SERVERS=1
RANDOM_ID=$(echo $RANDOM)

echo '' > hosts
echo "[app]" >> hosts
for i in $( eval echo {1..$NUMBER_OF_APP_SERVERS} )
do
   echo "create VM centos7-drupal$RANDOM_ID-app-$i"
   create_vm_from_ovf_template centos7-base centos7-drupal$RANDOM_ID-app-$i
   govc vm.ip centos7-base centos7-drupal$RANDOM_ID-app-$i
   current_ip=$(govc vm.ip centos7-drupal$RANDOM_ID-app-$i) 
   echo $current_ip >> hosts
   ssh-keygen -f "/home/labUser/.ssh/known_hosts" -R $current_ip
done
echo '' >> hosts
echo "[db]" >> hosts
for i in $( eval echo {1..$NUMBER_OF_DB_SERVERS} )
do
   echo "create VM centos7-drupal$RANDOM_ID-db-$i"
   create_vm_from_ovf_template centos7-base centos7-drupal$RANDOM_ID-db-$i
   current_ip=$(govc vm.ip centos7-drupal$RANDOM_ID-db-$i) 
   echo $current_ip >> hosts
    ssh-keygen -f "/home/labUser/.ssh/known_hosts" -R $current_ip
done


  