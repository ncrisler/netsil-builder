#!/bin/bash
set -xe

BUILD_TYPE=${BUILD_TYPE:-""}
BUILD_OUTPUT=${BUILD_OUTPUT:-"base-dcos"}
INTERACTIVE=${INTERACTIVE:-"yes"}
IMAGE_PATH=${IMAGE_PATH:-~/images}
CREDENTIALS_PATH=${CREDENTIALS_PATH:-~/credentials}
AWS_PROFILE=${AWS_PROFILE:-"default"}
# TODO: Reuse this env var for base dcos image/vhd for googlecompute and azure. We'll have to create some sort of associative array in the packer vars
BASE_DCOS_IMAGE=${BASE_DCOS_IMAGE:-"ami-57f25337"}

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
if [ "${BUILD_OUTPUT}" = "netsil-aoc" ] && [ -z "${APPS_DIR}" ] ; then
    echo "APPS_DIR not set!"
    exit 1
fi

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

# Export aws variables into the environment
export AWS_ACCESS_KEY_ID=$(aws configure --profile ${AWS_PROFILE} get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure --profile ${AWS_PROFILE} get aws_secret_access_key)

build_base_dcos() {
    docker build -t netsil/netsil-builder ${DIR}

    docker run --privileged -${INTERACTIVE} \
        -v ${IMAGE_PATH}:/opt/images \
        -e IMAGE_PATH=/opt/images \
        -e IMAGE_NAME=base-dcos \
        -e BUILD_TYPE=${BUILD_TYPE} \
        -e BUILD_OUTPUT=base-dcos \
        -v ${CREDENTIALS_PATH}:/opt/credentials \
        -e SSH_PUBLIC_KEY=/opt/credentials/id_rsa.pub \
        -e SSH_PRIVATE_KEY=/opt/credentials/id_rsa \
        -e AWS_ACCESS_KEY=${AWS_ACCESS_KEY_ID} \
        -e AWS_SECRET_KEY=${AWS_SECRET_ACCESS_KEY} \
        netsil/netsil-builder
}

# TODO: We should copy the apps folder into another location in the container so we can run concurrent builds from the same machine. Otherwise if we wanted to run another build with a different set of variables, it would interfere with the state of the previous build.
build_netsil_aoc() {
    docker build -t netsil/netsil-builder ${DIR}

    docker run --rm --privileged -${INTERACTIVE} \
        -v ${APPS_DIR}:/apps \
        -v ${IMAGE_PATH}:/opt/images \
        -e IMAGE_PATH=/opt/images \
        -e IMAGE_NAME=netsil-aoc-${NETSIL_BUILD_BRANCH} \
        -e BASE_DCOS_IMAGE=${BASE_DCOS_IMAGE} \
        -e BUILD_TYPE=${BUILD_TYPE} \
        -e BUILD_OUTPUT=netsil-aoc \
        -e VERSION_INFO=${NETSIL_VERSION_TAG} \
        -v ${CREDENTIALS_PATH}:/opt/credentials \
        -e SSH_PUBLIC_KEY=/opt/credentials/id_rsa.pub \
        -e SSH_PRIVATE_KEY=/opt/credentials/id_rsa \
        -e AWS_ACCESS_KEY=${AWS_ACCESS_KEY_ID} \
        -e AWS_SECRET_KEY=${AWS_SECRET_ACCESS_KEY} \
        netsil/netsil-builder
}

if [[ ${BUILD_OUTPUT} = "base-dcos" ]] ; then
    build_base_dcos
elif [[ ${BUILD_OUTPUT} = "netsil-aoc" ]] ; then
    build_netsil_aoc
else
    echo "Build output ${BUILD_OUTPUT} not recognized"
fi

