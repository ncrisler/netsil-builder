#!/bin/bash
### This script gathers various debug output and wraps it up into a tarball ###

DEBUG_OUTPUT_DIR=$HOME/debug-output

# Stage folders
rm -rf ${DEBUG_OUTPUT_DIR}
mkdir -p ${DEBUG_OUTPUT_DIR}

# Marathon app state
curl http://marathon.mesos:8080/v2/apps > ${DEBUG_OUTPUT_DIR}/app-state.json

# Marathon deployments state
curl http://marathon.mesos:8080/v2/deployments > ${DEBUG_OUTPUT_DIR}/deployment-state.json

# /slaves endpoint
curl http://leader.mesos:5050/slaves > ${DEBUG_OUTPUT_DIR}/slave-state.json

# systemctl status endpoint
function systemctl_out() {
    service=$1
    systemctl status ${service} > ${DEBUG_OUTPUT_DIR}/${service}.out
}
systemctl_out dcos-exhibitor
systemctl_out dcos-mesos-dns
systemctl_out dcos-mesos-master
systemctl_out dcos-mesos-slave
systemctl_out dcos-marathon

# docker ps output
docker ps -a > ${DEBUG_OUTPUT_DIR}/containers.out

# disk usage
df -h > ${DEBUG_OUTPUT_DIR}/disk.out

# cpu info
cat /proc/cpuinfo > ${DEBUG_OUTPUT_DIR}/cpuinfo

# mem info
cat /proc/meminfo > ${DEBUG_OUTPUT_DIR}/meminfo

# networking info (ifconfig)
ifconfig > ${DEBUG_OUTPUT_DIR}/ifconfig.out
/opt/mesosphere/bin/detect_ip > ${DEBUG_OUTPUT_DIR}/myip

# Current date
date > ${DEBUG_OUTPUT_DIR}/current_date

# Hostname
hostname > ${DEBUG_OUTPUT_DIR}/current_date

# Tar and gzip everything
# Get logs from /var/log/netsil, /var/tmp
tar -cvzf $HOME/debug-logs.tar.gz /var/log/netsil /var/tmp ${DEBUG_OUTPUT_DIR}
