#!/bin/bash
set -x
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APPS_DIR=${APPS_DIR:-""}

docker build -t ${URI_NAMESPACE}/netsil-builder ${DIR}

docker run -e "INVENTORY=[agents]\nlocalhost ansible_connection=local" \
       -e "IS_HA=${IS_HA}" \
       -e "URI_NAMESPACE=${URI_NAMESPACE}" \
       -e "NETSIL_BUILD_BRANCH=${NETSIL_BUILD_BRANCH}" \
       -e "NETSIL_VERSION_NUMBER=${NETSIL_VERSION_NUMBER}" \
       -e "NETSIL_BUILD_NUMBER=${NETSIL_BUILD_NUMBER}" \
       -e "NETSIL_COMMIT_HASH=${NETSIL_COMMIT_HASH}" \
       -e LOCAL_USER_ID=`id -u $USER` \
       -v ${APPS_DIR}:/apps \
       -t ${URI_NAMESPACE}/netsil-builder /opt/builder/scripts/start-template.sh
