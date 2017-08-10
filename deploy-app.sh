#!/bin/bash
set -xe

function display_usage() {
    echo "Usage: ./setup.sh [-p cloud_provider] [-d linux_distrib] [-k private_key_path] [-a apps_dir] ...


Parameters:
  -p, --provider           Cloud provider for provisioning (only: aws)
  -d, --distribution       Linux distribution for provisioning (only: coreos)
  -k, --ssh-private-key    Private SSH key path (default: ~/.ssh/id_ra)
  -s, --ssh-public-key     Public SSH key path (default: ~/.ssh/id_ra)
  -a, --apps-dir           The apps directory (default: ./apps)
  -s, --size
  -r, --region
  -i, --image
  -z, --zone
"
    exit 1
}

function deploy_aoc() {
    sudo docker build -t netsil/netsil-builder ${DIR}
    if [ $? -eq 0 ]; then
        sudo docker run --privileged -${INTERACTIVE} \
            -e APPS_DIR=$APPS_DIR \
            -e PROVIDER_ID=$PROVIDER_ID \
            -e PROVIDER=$PROVIDER \
            -e DISTRIB=$DISTRIB \
            -e INSTANCE_ID=$INSTANCE_ID \
            -e REGION=$REGION \
            -e IMAGE=$IMAGE \
            -e MASTER_SIZE=$SIZE \
            -e AWS_ACCESS_KEY=$AWS_ACCESS_KEY \
            -e AWS_SECRET_KEY=$AWS_SECRET_KEY \
            -e GCE_PROJECT_ID=$GCE_PROJECT_ID \
            -e GCE_SERVICE_ACCOUNT_EMAIL=$GCE_SERVICE_ACCOUNT_EMAIL \
            -e GCE_CREDENTIALS_FILE_B64=$GCE_CREDENTIALS_FILE_B64 \
            -e SSH_PRIVATE_KEY_B64=$SSH_PRIVATE_KEY_B64 \
            -e SSH_PUBLIC_KEY_B64=$SSH_PUBLIC_KEY_B64 \
            -e ZONE=$ZONE \
            -e NETWORK_ID=$NETWORK_ID \
            -e SUBNET_ID=$SUBNET_ID \
            netsil/netsil-builder \
            'ansible-playbook ansible/deploy-app.yml'
    fi
}

function abs_path() {
    (
    cd $(dirname $1)
    echo $PWD/$(basename $1)
    )
}

function check_docker() {
    (command -v docker || docker) > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        echo -n "Unable to locate 'docker' in your path. "
        echo "Please make sure Docker is installed."
        exit 1
    fi 

    sudo docker info > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        echo "Docker does not appear to be running locally."
        exit 1
    fi
}

####################################
### Parse command line arguments ###
####################################
while [ $# -gt 0 ]; do
    case $1 in
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        -d|--distribution)
            DISTRIB="$2"
            shift 2
            ;;
        -a|--apps-dir)
            APPS_DIR="$2"
            shift 2
            ;;
        -n|--network-id)
            NETWORK_ID="$2"
            shift 2
            ;;
        -S|--subnet-id)
            SUBNET_ID="$2"
            shift 2
            ;;
        -s|--size)
            SIZE="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE="$2"
            shift 2
            ;;
        -z|--zone)
            ZONE="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter \"$1\"" 1>&2
            display_usage
            exit 2
            ;;
    esac
done

# Get the directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

### Set default values and convert to absolute paths ###
# APPS_DIR=${APPS_DIR:-$DIR/apps}
# APPS_DIR=$(abs_path $APPS_DIR)
APPS_DIR=/opt/builder/apps
ORG_ID=${ORG_ID}
CLUSTER_ID=${CLUSTER_ID}
PROVIDER=${PROVIDER:-aws}
DISTRIB=${DISTRIB:-coreos}
# SSH_PRIVATE_KEY=${SSH_PRIVATE_KEY:-~/.ssh/id_rsa}
# SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-~/.ssh/id_rsa.pub}
# AWS_ACCESS_KEY=${AWS_ACCESS_KEY:-$(grep aws_access_key_id ~/.aws/credentials | cut -f3 -d" ")}
# AWS_SECRET_KEY=${AWS_SECRET_KEY:-$(grep aws_secret_access_key ~/.aws/credentials | cut -f3 -d" ")}

# echo $SSH_PRIVATE_KEY
# echo $(cat $SSH_PRIVATE_KEY)

# echo $SSH_PUBLIC_KEY
# echo $(cat $SSH_PUBLIC_KEY)

### Base64 encode SSH keys ###
# if [ -f "$SSH_PRIVATE_KEY" ]; then
#     SSH_PRIVATE_KEY_B64=$(base64 -w0 $SSH_PRIVATE_KEY)
# else
#     echo "The private SSH key \"$SSH_PRIVATE_KEY\" does not appear to exist."
#     display_usage
#     exit 1
# fi

# if [ -f "$SSH_PUBLIC_KEY" ]; then
#     SSH_PUBLIC_KEY_B64=$(base64 -w0 $SSH_PUBLIC_KEY)
# else
#     echo "The public SSH key \"$SSH_PUBLIC_KEY\" does not appear to exist."
#     display_usage
#     exit 1
# fi

# Cloud provider variables
# TODO: Move to another file
INSTANCE_ID=1
# REGION=us-west-2
# MASTER_SIZE=m3.xlarge # m3.large # m1.large
# ZONE=us-west-2c

# case $DISTRIB in
#     coreos)
#         IMAGE=ami-dc6ba3bc
#         ;;
#     centos)
#         IMAGE=ami-d2c924b2
#         ;;
# esac

### Start: Docker-specific env vars ###
INTERACTIVE=${INTERACTIVE:-"yes"}
### End: Docker-specific env vars ###

###########################
### Interactive setting ###
###########################
# This must be non-interactive in jenkins, but when running locally, "INTERACTIVE" allows us to ctrl-c out of the application.
if [[ ${INTERACTIVE} = "yes" ]] ; then
    INTERACTIVE="it"
else
    INTERACTIVE="t"
fi

# if [ ! -d "${APPS_DIR}" ]; then
#     echo "The apps directory \"$APPS_DIR\" does not appear to exist."
#     display_usage
#     exit 1
# fi

#############################################
### Perform prerequisite check for Docker ###
#############################################
check_docker

###################################
### Launch deployment container ###
###################################
deploy_aoc
