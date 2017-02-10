#!/bin/bash
cmd=$1

MARATHON_HOST=${MARATHON_HOST:-127.0.0.1}
MARATHON_PORT=${MARATHON_PORT:-8080}

http_ret_code=0

declare -A app_instances

function check_cmd_ret_code() {
    cmd=$1
    ret_code=$2
    app_id=$3
    if [[ ${cmd} = "install" ]] ; then
        if [[ ${ret_code} = "201" ]] ; then
            echo "Created app ${app_id}!"
        elif [[ ${ret_code} = "409" ]] ; then
            echo "Warning: App with ID ${app_id} already exists!"
        else
            echo "Return code ${ret_code} not recognized"
            exit 1
        fi
    elif [[ ${cmd} = "remove" ]] ; then
        if [[ ${ret_code} = "200" ]] ; then
            echo "Deleted app ${app_id}!"
        elif [[ ${ret_code} = "404" ]] ; then
            echo "Warning: App with ID ${app_id} already does not exist!"
        else
            echo "Return code ${ret_code} not recognized"
            exit 1
        fi
    else
        echo "Command ${cmd} not recognized!"
    fi
}

function wait_for_marathon() {
    timeout=1200
    count=0
    step=5
    while true ; do
        http_ret_code=$(curl -s -o /dev/null -w "%{http_code}" -I -X GET http://${MARATHON_HOST}:${MARATHON_PORT}/v2/apps)
        if [[ ${http_ret_code} = "200" ]] ; then
            echo "Marathon is initialized. Proceeding to install apps!"
            break
        fi
        echo "Waiting for marathon to initialize..."
        sleep ${step}
        count=$(expr $count + $step)
        if [ ${count} -gt ${timeout} ] ; then
            echo "Timeout exceeded!"
            exit 1
        fi
    done
}

function install_apps() {
    # Wait for marathon to start up
    wait_for_marathon

    # Change to directory where the specs are
    cd /opt/netsil/latest/apps/build/specs
    for app in *.json
    do
        app_id=$(cat ${app} | jq --raw-output '.id')
        ret_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://${MARATHON_HOST}:${MARATHON_PORT}/v2/apps -d @${app} -H "Content-type: application/json")
        check_cmd_ret_code "install" ${ret_code} ${app_id}

        # Scale instances if necessary
        instances=${app_instances[${app_id}]}
        if [[ -z ${instances} ]] && [[ ${instances} != 1 ]]; then
            echo "App ${app_id} was not yet installed or only has one instance. Not scaling."
        else
            echo "Attempting to scale ${app_id} to ${instances} instances"
            http_ret_code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT http://${MARATHON_HOST}:${MARATHON_PORT}/v2/apps/${app_id} -H "Content-type: application/json" -d '{ "instances" : '${instances}'}')
            if [[ ${http_ret_code} = "200" ]] ; then
                echo "Scaling succeeded!"
            else
                echo "Scaling failed!"
                exit 1
            fi
        fi
    done
}

function remove_apps() {
    # Wait for marathon to start up
    wait_for_marathon

    # Change to directory where the specs are
    cd /opt/netsil/${NETSIL_BUILD_BRANCH}-${NETSIL_VERSION_NUMBER}/apps/build/specs
    for app in *.json
    do
        app_id=$(cat ${app} | jq --raw-output '.id')

        # Store instances in an array for install step
        instances=$(curl -X GET -s http://${MARATHON_HOST}:${MARATHON_PORT}/v2/apps/${app_id} | jq --raw-output '.[].instances')
        app_instances[${app_id}]=${instances}

        ret_code=$(curl -s -o /dev/null -w "%{http_code}" -I -X DELETE http://${MARATHON_HOST}:${MARATHON_PORT}/v2/apps/${app_id})
        check_cmd_ret_code "remove" ${ret_code} ${app_id}
    done
}

case "${cmd}" in
    install)
        install_apps
        ;;
    remove)
        if [[ -z ${NETSIL_BUILD_BRANCH} ]] || [[ -z ${NETSIL_VERSION_NUMBER} ]] ; then
            echo "Netsil build branch or version number not given."
            exit 1
        else
            remove_apps
        fi
        ;;
    upgrade)
        if [[ -z ${NETSIL_BUILD_BRANCH} ]] || [[ -z ${NETSIL_VERSION_NUMBER} ]] ; then
            echo "Netsil build branch or version number not given."
            exit 1
        else
            remove_apps
            echo "Waiting for apps to be removed..."
            sleep 5
            install_apps
        fi
        ;;
    *)
        echo "Usage: ./manage-netsil-apps.sh <install | remove | upgrade>"
        exit 1
        ;;
esac

