FROM ubuntu:latest
MAINTAINER Ethan Devenport <ethand@stackpointcloud.com>

# Set the working directory.
WORKDIR /opt/builder

# Update and install required system packages.
RUN apt-get -qq update && \
    apt-get -qq install -y --no-install-recommends \
    ansible ca-certificates curl qemu qemu-utils ssh-client unzip vim

# Download and extract the Packer binary.
RUN curl -sOL https://releases.hashicorp.com/packer/0.11.0/packer_0.11.0_linux_amd64.zip && \
    unzip packer_0.11.0_linux_amd64.zip && \
    rm -f packer_0.11.0_linux_amd64.zip

# Copy builder files into the image.
COPY . /opt/builder/

# Setup environment and launch Packer.
CMD [ "/opt/builder/start.sh" ]
