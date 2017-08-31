#!/bin/bash
node_type=$1

do_scale=${DO_SCALE:-yes}
marathon_host=${MARATHON_HOST:-marathon.mesos}
marathon_port=${MARATHON_PORT:-8080}

metadata_port=${METADATA_PORT:-5444}
version_info_file=${VERSION_INFO_FILE:-/opt/netsil/latest/version-info}

worker_ip=$(/opt/mesosphere/bin/detect_ip)

scaled_apps=()

function get_scaled_apps() {
    scaled_apps_raw=$(curl -s -X GET http://${marathon_host}:${marathon_port}/v2/apps | jq --raw-output '.apps | .[] | select(.env.DO_SCALE=="yes") | .id')
    for app in ${scaled_apps_raw[@]}
    do
        scaled_apps+=(${app#/})
    done
}

function setup_worker() {
    # This gets the last mesos_master_ip in the list
    mesos_master_ip=leader.mesos

    # Check if we can proceed with setup worker script based on worker version
    worker_version=$(cat ${version_info_file} | jq --raw-output '.NETSIL_VERSION_NUMBER')
    resp=$(curl -X GET http://metadata.marathon.mesos:${metadata_port}/worker_join/${worker_version})
    if [[ ${resp} = "yes" ]] ; then
        echo "Worker version is suitable. Continuing with upgrade."
    else
        echo "Worker version is incompatible. Please upgrade your worker before proceeding."
        exit 1
    fi

    # Kill all mesos-related services
    systemctl stop dcos-exhibitor
    systemctl stop dcos-marathon
    systemctl stop dcos-mesos-dns
    systemctl stop dcos-mesos-master
    systemctl stop dcos-adminrouter
    systemctl stop marathon-health-checker

    # Disable all mesos-master related services
    systemctl disable dcos-exhibitor
    systemctl disable dcos-marathon
    systemctl disable dcos-mesos-dns
    systemctl disable dcos-mesos-master
    systemctl disable dcos-adminrouter
    systemctl disable marathon-health-checker

    # remove master role
    rm -rf /etc/mesosphere/roles/master
    rm -rf /opt/mesosphere/etc/roles/master

    # Disable netsil-startup service
    systemctl disable netsil-startup

    # Clean /var/lib/mesos/slave
    rm -rf /var/lib/mesos/slave/*

    # Clean docker container state
    docker rm -f $(docker ps -qa)

    echo "Getting current number of workers."
    total_workers=$(curl -s http://${mesos_master_ip}:5050/metrics/snapshot | jq '."master/slaves_active"')

    if [[ ${do_scale} = "yes" ]] ; then
    	timeout=600
    	count=0
    	step=5
    	while true ; do
    	    http_ret_code=$(curl -s -o /dev/null -w "%{http_code}" -I -X GET http://${marathon_host}:${marathon_port}/v2/apps)
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

        get_scaled_apps

        echo "Scaling apps..."
        for app in ${scaled_apps[@]}
        do
            http_ret_code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT http://${marathon_host}:${marathon_port}/v2/apps/${app} -H "Content-type: application/json" -d '{ "instances" : '${total_workers}'}')
            if [[ ${http_ret_code} = "200" ]] ; then
                echo "Scaling succeeded for ${app}!"
            else
                echo "Scaling failed ${app}!"
                exit 1
            fi
            sleep 2
        done
    fi
}

case "${node_type}" in
    worker)
        echo "Setting up worker"
        setup_worker
        ;;
    # TODO: setup for master
    #    master*)
    #        echo "Setting up master"
    #        setup_master
    #        ;;
    *)
        echo "Usage: ./setup-node.sh node_type"
        exit 1
        ;;
esac
