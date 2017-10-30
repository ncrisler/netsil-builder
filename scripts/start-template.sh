#!/bin/bash

# Set inventory
echo -e ${INVENTORY} > /home/user/hosts

# Run ansible
ansible-playbook -i /home/user/hosts /opt/builder/ansible/template.yml
