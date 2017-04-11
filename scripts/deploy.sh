#!/bin/bash
set -x -e

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
export ANSIBLE_SSH_ARGS="-o ControlMaster=no"

# Workaround for CoreOS bug
if [ "$DISTRIB" == "coreos" ]; then
    export ANSIBLE_SSH_ARGS="-o ControlMaster=no"
fi

###################################
### Install DCOS and Netsil AOC ###
###################################
ansible-playbook --extra-vars "distrib=${DISTRIB} build_type=deploy" -i ${HOST}, --private-key /credentials/id_rsa ansible/full-deployment.yml
