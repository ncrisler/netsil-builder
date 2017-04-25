#!/bin/bash
set -e

function display_usage() {
    echo "Usage: ./setup.sh -h hostname [-k key_path] [-a apps_dir] [-u username] [-d dcos_path]


Parameters:
  -h, --host         Server hostname of IP address
  -k, --ssh-key      Private SSH key path (default: ~/.ssh/id_ra)
  -a, --apps-dir     The apps directory (default: ./apps)
  -u, --user         SSH user for deployment (default: $USER)
  -d, --dcos-path    Path to the DCOS release package
  -r, --registry     For use with third party registries. Defaults to Dockerhub.
                     You should pass the repository prefix of the 'netsil/<image>' images.
  -o, --offline      Are we deploying offline? Choose 'Yes' or 'No'. Defaults to No.
"
    exit 1
}

function deploy_aoc() {
    builder_image=netsil/netsil-builder
    if [ "${OFFLINE}" = "No" ]; then
        sudo docker build -q -t ${builder_image} ${DIR}
    else 
        builder_image=${REGISTRY}/netsil/netsil-builder 
    fi

    if [ $? -eq 0 ]; then
        sudo docker run --rm --privileged -${INTERACTIVE} \
            $DCOS_VOLUME_ARG \
            -v ${APPS_DIR}:/apps \
            -v ${SSH_PRIVATE_KEY}:/credentials/id_rsa \
            -v ${CREDENTIALS_PATH}:/opt/credentials \
            -e DISTRIB=$DISTRIB \
            -e HOST=$HOST \
            -e ANSIBLE_USER=$ANSIBLE_USER \
            -e REGISTRY=$REGISTRY \
            ${builder_image} \
            /opt/builder/scripts/deploy.sh
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

###########################################################
### Check SSH key authentication and Linux distribution ###
###########################################################
function check_ssh_auth() {
    DISTRIB=$(ssh -i $SSH_PRIVATE_KEY \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        ${ANSIBLE_USER}@${HOST} "sed -n 's/^ID=//p' /etc/os-release")

    if [ "$?" -ne 0 ]; then
        echo "There appears to be a problem with SSH public/private key authentication."
        exit 1
    fi
}

###############################################################################
### Generate SSH keys and configure key authentication for local deployment ###
###############################################################################
function setup_ssh_auth() {
    if [ ! -d "~/.ssh" ]; then
        mkdir ~/.ssh && chmod 700 ~/.ssh
    fi

    ssh-keygen -q -b 2048 -t rsa -N '' -f $DIR/netsil_rsa
    cat $DIR/netsil_rsa.pub >> ~/.ssh/authorized_keys
    SSH_PRIVATE_KEY=$DIR/netsil_rsa
}

####################################
### Parse command line arguments ###
####################################
while [ $# -gt 0 ]; do
    case $1 in
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_PRIVATE_KEY="$2"
            shift 2
            ;;
        -a|--apps-dir)
            APPS_DIR="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -d|--dcos-path)
            DCOS_PATH="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -o|--offline)
            OFFLINE="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter \"$1\"" 1>&2
            display_usage
            exit 2
            ;;
    esac
done

# Get the directory this script is in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

### Set default values and convert to absolute paths ###
SSH_PRIVATE_KEY=${SSH_PRIVATE_KEY:-~/.ssh/id_rsa}
SSH_PRIVATE_KEY=$(abs_path $SSH_PRIVATE_KEY)
APPS_DIR=${APPS_DIR:-$DIR/apps}
APPS_DIR=$(abs_path $APPS_DIR)
CREDENTIALS_PATH=${CREDENTIALS_PATH:-~/credentials}
ANSIBLE_USER=$USER
REGISTRY=${REGISTRY:-"dockerhub"}
OFFLINE=${OFFLINE:-"No"}
############################################################
### If DCOS_PATH is defined:                             ###
###  * Replace with relative path with an absolute path. ###
###  * Set Docker volume mount argument.                 ###
############################################################
if [ -n "$DCOS_PATH" ]; then
    DCOS_PATH=$(abs_path $DCOS_PATH)
    DCOS_VOLUME_ARG="-v $DCOS_PATH:/data/dcos_generate_config.sh"
fi

### Start: Docker-specific env vars ###
INTERACTIVE=${INTERACTIVE:-"yes"}
### End: Docker-specific env vars ###

### Start: Netsil-specific env vars ###
# TODO: Make these variables able to be overwritten by environment variables.
export URI_NAMESPACE=${URI_NAMESPACE:-netsilprivate}
export BUILD_ENV=${BUILD_ENV:-production}
export NETSIL_BUILD_BRANCH=${NETSIL_BUILD_BRANCH:-master}
export NETSIL_VERSION_NUMBER=${NETSIL_VERSION_NUMBER:-0.2.0}
export NETSIL_COMMIT_HASH=${NETSIL_COMMIT_HASH}
export NETSIL_BUILD_NUMBER=${NETSIL_BUILD_NUMBER}
export RESOURCE_ROLE=${RESOURCE_ROLE:-*}
export FORCE_PULL_IMAGE=${FORCE_PULL_IMAGE:-false}
### End: Netsil-specific env vars ###

###########################
### Interactive setting ###
###########################
# This must be non-interactive in jenkins, but when running locally, "INTERACTIVE" allows us to ctrl-c out of the application.
if [[ ${INTERACTIVE} = "yes" ]] ; then
    INTERACTIVE="it"
else
    INTERACTIVE="t"
fi

#############################
### Run build-time checks ###
#############################
if [ -z ${HOST} ]; then
    echo "Could not find host: $HOST" 1>&2
    display_usage
    exit 1
fi

if [ "$HOST" == "localhost" ] || [ "$HOST" == "127.0.0.1" ]; then
    DEPLOY=local
fi

if [ ! -f "${SSH_PRIVATE_KEY}" ] && [ "$DEPLOY" != "local" ]; then
    echo "The private SSH key \"$SSH_PRIVATE_KEY\" does not appear to exist."
    display_usage
    exit 1
fi

if [ ! -d "${APPS_DIR}" ]; then
    echo "The apps directory \"$APPS_DIR\" does not appear to exist."
    display_usage
    exit 1
fi

#############################################
### Perform prerequisite check for Docker ###
#############################################
check_docker

##########################################
### Local deployment pre-configuration ###
##########################################
if [ "$DEPLOY" == "local" ]; then
    # Use Docker bridge IP address when setting host to localhost.
    HOST=$(ip -f inet addr show docker0 | grep -Po 'inet \K[\d.]+')

    # Setup local SSH key authentication.
    if [ ! -f "${SSH_PRIVATE_KEY}" ]; then
        setup_ssh_auth
    fi
fi

##########################################
### Perform prerequisite check for SSH ###
##########################################
check_ssh_auth

####################################
### Resolving NETSIL_VERSION_TAG ###
####################################
# TODO: We eventually want to generate the VERSION_TAG from the buildvar files in the apps directory.
# Then, we won't have to pass in all of these variables at buildtime
if [[ ${NETSIL_BUILD_BRANCH} = "stable" ]] || [[ ${NETSIL_BUILD_BRANCH} = "staging" ]] ; then
    export NETSIL_VERSION_TAG=${NETSIL_BUILD_BRANCH}-${NETSIL_VERSION_NUMBER}
else
    export NETSIL_VERSION_TAG=${NETSIL_BUILD_BRANCH}-${NETSIL_VERSION_NUMBER}-${NETSIL_COMMIT_HASH}.${NETSIL_BUILD_NUMBER}
fi

export IS_PRIVATE_REGISTRY=false
if [[ ${URI_NAMESPACE} != "netsil" ]] ; then
    export IS_PRIVATE_REGISTRY=true
fi

###################################
### Launch deployment container ###
###################################
deploy_aoc
