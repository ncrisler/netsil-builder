#!/bin/bash
ansible_config_dir=/opt/ansible/etc
# Create ansible config directory
mkdir -p ${ansible_config_dir}

# Set inventory
echo -e ${INVENTORY} > ${ansible_config_dir}/hosts

# Run ansible
ansible-playbook -i ${ansible_config_dir}/hosts /opt/builder/ansible/template.yml

# chown so permissions are correct (this fixes build)
chown -R ${LOCAL_USER_ID}:${LOCAL_USER_ID} /apps
