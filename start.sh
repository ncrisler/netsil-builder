#!/bin/bash

if [ -z "$SSH_PRIVATE_KEY" ]; then
    echo "SSH_PRIVATE_KEY is not set."
    exit 1
fi

if [ -z "$SSH_PUBLIC_KEY" ]; then
    echo "SSH_PUBLIC_KEY is not set."
    exit 1
fi

# Environment variables inherited by Packer and Ansible.
export PACKER_LOG_PATH="/opt/packer.log"
export PACKER_LOG="${PACKER_LOG:-0}"
export ANSIBLE_SCP_IF_SSH=1
export IMAGE_PATH="${IMAGE_NAME:-/opt/images}"
export IMAGE_NAME="${IMAGE_NAME:-coreos-stable}"

# Local environment variables
DATESTAMP=$(date +"%Y%m%d-%H%M%S")

# Assign user_data template to variable.
read -r -d '' USER_DATA << EOF
#cloud-config
write_files:
  - path: "/etc/udev/rules.d/80-net-setup-link.rules"
    permissions: "0644"
    owner: "root"
    content: |
      SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="ff:ff:ff:ff:ff:ff", NAME="eth0"
ssh_authorized_keys:
EOF

write_user_data() {
    echo "$USER_DATA"
    sed -e 's/^/  - /'
}

# Read the SSH public key text.
SSH_PUBLIC_KEY_TEXT=$(cat "$SSH_PUBLIC_KEY")

# Create user_data directory and write the user_data file.
mkdir -p data/openstack/latest
echo "$SSH_PUBLIC_KEY_TEXT" | write_user_data > \
     "data/openstack/latest/user_data"

# Run the Packer build.
/opt/builder/packer build packer-config.json

# The image ouput directory must not exist on subsequent runs, so the directory
# is renamed with a datestamp.
mv ${IMAGE_PATH}/packer ${IMAGE_PATH}/${DATESTAMP}
