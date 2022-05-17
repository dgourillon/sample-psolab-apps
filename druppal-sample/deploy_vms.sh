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

remote_shell_script_exec_with_ansible()
{
    hosts=$1
    script_path=$2
    ansible -i $hosts all -m copy -a "src=$script_path dest=/root/$script_path mode=u+x"
    ansible -i $hosts all -m shell -a "/root/$script_path"
}

RANDOM_ID=$(echo $RANDOM)

create_vm_from_ovf_template centos7-base centos7-drupal$RANDOM_ID-app-1
create_vm_from_ovf_template centos7-base centos7-drupal$RANDOM_ID-app-2
create_vm_from_ovf_template centos7-base centos7-drupal$RANDOM_ID-db-1
create_vm_from_ovf_template centos7-base centos7-drupal$RANDOM_ID-db-2

IP_APP_1=$(govc vm.ip centos7-drupal$RANDOM_ID-app-1)
IP_APP_2=$(govc vm.ip centos7-drupal$RANDOM_ID-app-2)
IP_DB_1=$(govc vm.ip centos7-drupal$RANDOM_ID-db-1)
IP_DB_2=$(govc vm.ip centos7-drupal$RANDOM_ID-db-2)

ansible -i "$IP_APP_1,$IP_APP_2,$IP_DB_1,$IP_DB_2" -m selinux -a 'state=disabled' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"
ansible -i "$IP_APP_1,$IP_APP_2,$IP_DB_1,$IP_DB_2" -m yum -a 'name=epel-release state=present' all --extra-vars "ansible_user=root ansible_password=$psolab_os_password"


remote_shell_script_exec_with_ansible  "$IP_APP_1," deploy_mysql.sh