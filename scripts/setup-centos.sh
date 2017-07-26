#!/bin/bash

# Check if running as root
if [[ `id -u` -ne 0 ]] ; then
    echo "Please run this script as root."
    exit 1
fi

# Check if overlay is enabled
overlay_exists=$(lsmod | grep overlay)
if [[ -z "${overlay_exists}" ]] ; then
    echo "Overlay is not enabled. Please run the 'enable-overlay.sh' script first"
    exit
fi

# Check for python
if [[ ! -f '/usr/bin/python' ]] ; then
    echo "Error: You must install python at /usr/bin/python!"
    exit 1
fi

# Enable epel
yum update && yum install -y epel-release
yum udpate && yum install -y jq

# Install docker
# Use docker yum repo
tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

# Configure systemd to run with overlay
mkdir -p /etc/systemd/system/docker.service.d && sudo tee /etc/systemd/system/docker.service.d/override.conf <<- EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --storage-driver=overlay
EOF

# Install docker 
yum install -y docker-engine-1.13.1 docker-engine-selinux-1.13.1
systemctl start docker
systemctl enable docker

# Disabling firewalld
echo "Warning: we are disabling the firewalld program. This is necessary for normal operation of Netsil AOC."
systemctl stop firewalld && systemctl disable firewalld
