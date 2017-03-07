#!/bin/bash

if [ -z "$HOST" ]; then
    echo "HOST is not set."
    exit 1
fi

##################################################
### Environment variables inherited by Ansible ###
##################################################
export ANSIBLE_HOST_KEY_CHECKING=0
export ANSIBLE_SCP_IF_SSH=1
export ANSIBLE_SUDO_FLAGS="-H -S"

###################################
### Install DCOS and Netsil AOC ###
###################################
ansible-playbook --extra-vars build_type=deploy -i ${HOST}, --private-key /secrets/id_rsa ansible/full-deployment.yml
