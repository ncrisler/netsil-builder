1. A Docker image is built with QEMU, Ansible, and Packer.
2. A Docker container will prepare the environment and launch the Packer build (`start.sh`).
3. Packer uses the QEMU builder to launch a VM with a generated user_data file containing the SSH public key.
4. Packer then provisions the VM with Python and DCOS using Ansible.
5. The VM image is saved as a qcow2 image file.
6. A Packer post-processor launches an Ansible playbook that converts the qcow2 image to vdi, vhd, and vmdk images.
7. The image output directory is then renamed as date and timestamp.

# Notes

coreos_production_qemu_image.img 
Rename network interface

# Project Files

* ansible/convert-images.yml - Uses `qemu-img` to convert the created qcow2 image to vdi, vhd, and vmdk images.
* ansible/dcos-bootstrap.yml - Bootstraps the CoreOS image with DCOS master and slave roles.
* ansible/roles - Various Ansible roles used by the available playbooks.
* Dockerfile - Dockerfile necessary to build an Ubuntu image with QEMU, Ansible, and Packer.
* packer-config.json - Packer config file that launches the VM, bootstraps the image, and saves the image.
* start.sh - The script that launches Packer build process.

# Docker Variables

* SSH_PRIVATE_KEY - The SSH private key used to connect to the CoreOS VM instance by Packer and Ansible. This should be saved.
* SSH_PUBLIC_KEY - The SSH public key that will be injected into the CoreOS image for provisioning.
* IMAGE_PATH - The path inside the container where the images will be saved. This *should* map to a location on the host system.
* IMAGE_NAME - The name of the images without any extension.

# Example Usage
    
    $ docker build -t netsil-builder .
    $ docker run --privileged -ti \
          -v /path/to/images:/opt/images \
          -v /path/to/secrets:/opt/secrets \
          -e SSH_PUBLIC_KEY=/opt/secrets/id_rsa.pub \
          -e SSH_PRIVATE_KEY=/opt/secrets/id_rsa \
          -e IMAGE_PATH=/opt/images \
          -e IMAGE_NAME=coreos-stable \
          netsil-builder
