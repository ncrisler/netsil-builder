#!/bin/bash
node_type=$1
mesos_master_ip_list=$2

do_scale=${DO_SCALE:-yes}
marathon_host=${MARATHON_HOST:-marathon.mesos}
marathon_port=${MARATHON_PORT:-8080}

metadata_port=${METADATA_PORT:-5444}
version_info_file=${VERSION_INFO_FILE:-/opt/netsil/latest/version-info}

worker_ip=$(/opt/mesosphere/bin/detect_ip)

scaled_apps=()

function check_number() {
    number=$1
    re='^[0-9]+$'
    if ! [[ $number =~ $re ]] ; then
        echo "error: Not a number" >&2; exit 1
    fi
}

function get_scaled_apps() {
    scaled_apps_raw=$(curl -s -X GET http://${marathon_host}:${marathon_port}/v2/apps | jq --raw-output '.apps | .[] | select(.env.DO_SCALE=="yes") | .id')
    for app in ${scaled_apps_raw[@]}
    do
        scaled_apps+=(${app#/})
    done
}

function setup_worker() {
    # Check if mesos_master_ip_list was passed in.
    # If not, check if it was passed in as an env var
    if [[ -z ${mesos_master_ip_list} ]] ; then
        echo "The mesos master ip list was not given. Failing node setup."
        exit 1
    else
        echo "The mesos master ip list is ${mesos_master_ip_list}. Proceeding with node setup."
    fi

    # This gets the last mesos_master_ip in the list
    mesos_master_ip=${mesos_master_ip_list##*,}

    # Check if we can proceed with setup worker script based on worker version
    worker_version=$(cat ${version_info_file} | jq --raw-output '.NETSIL_VERSION_NUMBER')
    resp=$(curl -X GET http://${mesos_master_ip}:${metadata_port}/worker_join/${worker_version})
    if [[ ${resp} = "yes" ]] ; then
        echo "Worker version is suitable. Continuing with upgrade."
    else
        echo "Worker version is incompatible. Please upgrade your worker before proceeding."
        exit 1
    fi

    # Clean the old persistent volumes of any apps that are to be scaled on the worker node. Hardcoded for now.
    curl -X DELETE "http://${marathon_host}:${marathon_port}/v2/apps/druid-realtime/tasks?host=${worker_ip}&wipe=true"
    curl -X DELETE "http://${marathon_host}:${marathon_port}/v2/apps/druid-historical/tasks?host=${worker_ip}&wipe=true"
    curl -X DELETE "http://${marathon_host}:${marathon_port}/v2/apps/ceph-osd/tasks?host=${worker_ip}&wipe=true"

    # Kill all mesos-related services
    systemctl stop dcos-exhibitor
    systemctl stop dcos-marathon
    systemctl stop dcos-mesos-dns
    systemctl stop dcos-mesos-master
    systemctl stop dcos-mesos-slave
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

    # Template /opt/mesosphere/etc/master_list with the list of master_ips
    echo "[\"${mesos_master_ip_list}\"]" > /opt/mesosphere/etc/master_list

    # Search and replace exhibitor uris
    sed -i "s/EXHIBITOR_URI=.*/EXHIBITOR_URI=http:\/\/${mesos_master_ip}:8181\/exhibitor\/v1\/cluster\/status/" /opt/mesosphere/etc/dns_config_master
    sed -i "s/EXHIBITOR_ADDRESS=.*/EXHIBITOR_ADDRESS=${mesos_master_ip}/" /opt/mesosphere/etc/dns_config_master

    echo "Restart spartan to resolve new exhibitor address"
    systemctl restart dcos-spartan

    echo "Waiting for mesos-slave to start up and connect to cluster..."
    sleep 5

    echo "Getting current number of workers."
    current_workers=$(curl -s http://${mesos_master_ip}:5050/metrics/snapshot | jq '."master/slaves_active"')
    expected_workers=$(( current_workers + 1))

    echo "Restart mesos-slave to connect to new master"
    systemctl restart dcos-mesos-slave
    ret=$?
    while true ; do
        if [[ ${ret} != 0 ]] ; then
            echo "Waiting for mesos-slave to start up and connect to cluster..."
            sleep 5
            systemctl restart dcos-mesos-slave
            ret=$?
        else
            echo "Mesos slave connected successfully!"
            break
        fi
    done

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

        while true ; do
            # Here, we find the total number of workers and scale the app to that number
            total_workers=$(curl -s http://leader.mesos:5050/metrics/snapshot | jq '."master/slaves_active"')
            if [[ "${total_workers}" == "${expected_workers}" ]] ; then
                break
            else
                echo "Waiting for mesos-slave state to become active..."
                sleep 5
            fi
        done

        check_number ${total_workers}

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
        echo "Usage: ./setup-node.sh node_type mesos_master_ip_list."
        echo "Pass in mesos_master_ip_list as a comma-separated list of ip addresses."
        exit 1
        ;;
esac
