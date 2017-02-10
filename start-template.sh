#!/bin/bash

# Set inventory
echo -e ${INVENTORY} > /etc/ansible/hosts

# Run ansible
ansible-playbook /opt/builder/ansible/template.yml
