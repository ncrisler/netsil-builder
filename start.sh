#!/bin/bash
set -x

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
export ANSIBLE_SUDO_FLAGS="-H -S"
export AZURE_CLIENT_SECRET=$(cat /opt/secrets/azure-client-secret)
export IMAGE_PATH="${IMAGE_PATH:-/opt/images}"
export IMAGE_NAME="${IMAGE_NAME:-base-dcos}"
export AWS_REGION="${AWS_REGION:-us-west-2}"

packer_binary=/opt/builder/packer

if [ "${BUILD_TYPE}" == "googlecompute" ] ; then
    packer_binary=/opt/builder-0-10-2/packer
fi

if [ "${BUILD_TYPE}" == "all" ] ; then
    BUILD_TYPE="qemu,amazon-ebs,googlecompute,azure-arm"
fi

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
PACKER_LOG=1 ${packer_binary} build -var ssh_pass="Password1234" -only=$BUILD_TYPE packer-config.json

# The image ouput directory must not exist on subsequent runs, so the directory
# is renamed with a datestamp.
if [ -d "${IMAGE_PATH}/packer" ]; then
    mv ${IMAGE_PATH}/packer ${IMAGE_PATH}/${IMAGE_NAME}-${DATESTAMP}
fi
