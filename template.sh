#!/bin/bash
set -x
URI_NAMESPACE=${URI_NAMESPACE:-netsildev}
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APPS_DIR=${APPS_DIR:-""}

docker build -t ${URI_NAMESPACE}/netsil-builder ${DIR}

docker run -e "INVENTORY=[agents]\nlocalhost ansible_connection=local" \
       -v ${APPS_DIR}:/apps \
       -t ${URI_NAMESPACE}/netsil-builder /opt/builder/start-template.sh
