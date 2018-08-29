#!/bin/bash
set -xe

tf_state_dir=${TF_STATE_DIR:-"$HOME/tf-state"}

submodule_state_dir=${tf_state_dir}/$MODULE/$SUBMODULE

mkdir -p ${tf_state_dir} ${submodule_state_dir}


if [ "$SINGLE_STAGE" != "no" ] && [ "$SINGLE_STAGE" != "$STAGE" ] ; then
    echo "We're only running $SINGLE_STAGE, not running $STAGE"
    exit 0
fi

#export GOOGLE_APPLICATION_CREDENTIALS="$HOME/credentials/netsil-infra-project-editor.json"
export GOOGLE_PROJECT="netsil-test"

function getVar() {
    local key=$1
    local default=$2
    local val=""
    val=$(cat ./terraform/$MODULE/$SUBMODULE.tfvars | grep $key | awk '{print $3}' | tr -d '"')
    if [ -z "$val" ] ; then
        echo $default
    else
        echo $val
    fi
}

### Terraform
pushd terraform/$MODULE
if [ "$STAGE" = "init" ] ; then
    terraform init

elif [ "$STAGE" = "plan" ] ; then
    terraform plan \
            -var-file=$SUBMODULE.tfvars \
            -out=${submodule_state_dir}/tf.plan \
            -state=${submodule_state_dir}/terraform.tfstate

elif [ "$STAGE" = "apply" ] ; then
    terraform apply \
            -state-out=${submodule_state_dir}/terraform.tfstate \
            ${submodule_state_dir}/tf.plan

elif [ "$STAGE" = "output" ] ; then
    # TODO: Need further parameters for what kind of output. Not always getting ips
    ips=$(terraform output -state=${submodule_state_dir}/terraform.tfstate -module=$MODULE -json | jq --raw-output '.instance_ips.value')
    echo "$ips" > ${submodule_state_dir}/inventory

elif [ "$STAGE" = "destroy" ] ; then
    if [ "$DESTROY" = "yes" ] ; then
        terraform destroy -auto-approve -state=${submodule_state_dir}/terraform.tfstate
    fi
fi

popd

### Ansible
if [ "$STAGE" = "setup" ] ; then
    ssh_key=$(getVar "ssh_key" "netsil-dev")
    ssh_user=$(getVar "ssh_user" "ubuntu")
    ansible_playbook=$(getVar "ansible_playbook" "dev-vm")

    if [ "${ansible_playbook}" = "skip" ] ; then
        echo "Skipping ansible setup"
        exit 0
    fi

    export ANSIBLE_HOST_KEY_CHECKING=False
    ansible-playbook -i ${submodule_state_dir}/inventory \
                     -u ${ssh_user} \
                     --private-key=~/.ssh/${ssh_key}.pem \
                     ansible/${ansible_playbook}.yml

fi

# TODO: need to do this before plan -- export GOOGLE_PROJECT=$(gcloud config get-value project)
# TODO: After provision runs, we'll run a "deploy" step that will run ansible, or first pull netsil-builder image and then run ansible
