FROM ubuntu:xenial
MAINTAINER Ethan Devenport <ethand@stackpointcloud.com>

# Set the working directory.
WORKDIR /opt/builder

# Update and install required system packages.
RUN apt-get -qq update && \
    apt-get -qq install -y --no-install-recommends \
      ca-certificates \
      curl \
      python-pip \
      python-setuptools \
      qemu \
      qemu-utils \
      software-properties-common \
      ssh-client \
      sudo \
      unzip \
      vim && \
    apt-add-repository -y ppa:ansible/ansible && \
    apt-get update && \
    apt-get -qq install -y --no-install-recommends ansible

## Start: TODO: We have these two lines because we run ansible locally for the templating tasks...we should do away with that and run it remotely
RUN pip install --upgrade pip wheel && \
    pip install pystache boto && \
    mkdir -p /opt/bin && \
    ln -s /usr/bin/python /opt/bin/python
### End

# Download and extract the Packer binary (0.12.2).
ENV PACKER_VERSION=0.12.2
RUN curl -sOL https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip && \
    unzip packer_${PACKER_VERSION}_linux_amd64.zip && \
    rm -f packer_${PACKER_VERSION}_linux_amd64.zip

# Copy builder files into the image.
COPY . /opt/builder/

# Setup environment and launch Packer.
ENTRYPOINT ["/bin/sh", "-c"]
CMD [ "/opt/builder/scripts/start.sh" ]
