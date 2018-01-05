#!/bin/bash
set -xe

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
export ANSIBLE_SSH_ARGS="-o ControlMaster=auto -o ControlPersist=60s -o ControlPath=/dev/ansible.netsil"

###################################
### Install DCOS and Netsil AOC ###
###################################
if [ "${REGISTRY}" != "dockerhub" ] ; then
    export URI_NAMESPACE="${REGISTRY}/netsil"
fi

if [ "$MODE" = "HA" ] ; then
    inventory_file=$HOST
    ansible-playbook --extra-vars "distrib=${DISTRIB} build_type=deploy" -i ${inventory_file} --private-key /credentials/id_rsa ansible/cloud-deployment.yml
else
    ansible-playbook --extra-vars "distrib=${DISTRIB} build_type=deploy" -i ${HOST}, --private-key /credentials/id_rsa ansible/full-deployment.yml
fi

