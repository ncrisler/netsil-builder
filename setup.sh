#!/bin/bash
# set -xe

function display_usage() {
    echo "Usage: ./setup.sh -h hostname [-k key_path] [-a apps_dir] 

Parameters:
  -h, --host         Server hostname of IP address
  -k, --ssh-key      Private SSH key path (default: ~/.ssh/id_ra)
  -a, --apps-dir     The apps directory (default: ./apps)
"
    exit 1
}

function deploy_aoc() {
    docker build -q -t netsil/netsil-builder ${DIR}

    if [ $? -eq 0 ]; then
        docker run --rm --privileged -${INTERACTIVE} \
            -v ${APPS_DIR}:/apps \
            -v ${SSH_PRIVATE_KEY}:/secrets/id_rsa \
            -e HOST=$HOST \
            netsil/netsil-builder \
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

    docker info > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        echo "Docker does not appear to be running locally."
        exit 1
    fi
}

function check_ssh() {
    ssh -i $SSH_PRIVATE_KEY \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        core@${HOST} uname
    if [ "$?" -ne 0 ]; then
        echo "There appears to be a problem with SSH public/private key authentication."
        exit 1
    fi
}

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
        *)
            echo "Unknown parameter \"$1\"" 1>&2
            display_usage
            exit 2
            ;;
    esac
done


### Set default values and convert to absolute paths ###
SSH_PRIVATE_KEY=${SSH_PRIVATE_KEY:-~/.ssh/id_rsa}
SSH_PRIVATE_KEY=$(abs_path $SSH_PRIVATE_KEY)
APPS_DIR=${APPS_DIR:-./apps}
APPS_DIR=$(abs_path $APPS_DIR)

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

# Get the directory this script is in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

if [ ! -f "${SSH_PRIVATE_KEY}" ]; then
    echo "The private SSH key \"$SSH_PRIVATE_KEY\" does not appear to exist."
    display_usage
    exit 1
fi

if [ ! -d "${APPS_DIR}" ]; then
    echo "The apps directory \"$APPS_DIR\" does not appear to exist."
    display_usage
    exit 1
fi

######################################################
### Perform prerequisite checks for Docker and SSH ###
######################################################
check_docker && check_ssh

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
