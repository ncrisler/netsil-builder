FROM ubuntu:xenial
MAINTAINER Kevin Lu <kevin@netsil.com>

# Set the working directory.
WORKDIR /opt/builder

# Update and install required system packages.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      python-pip \
      python-setuptools \
      python-dev \
      ssh-client \
      sudo \
      unzip \
      build-essential \
      vim

## Start: TODO: We have these two lines because we run ansible locally for the templating tasks...we should do away with that and run it remotely
RUN pip install --upgrade pip wheel && \
    pip install \
      apache-libcloud==1.5.0 \
      boto \
      pystache \
      ansible==2.3 && \
    mkdir -p /opt/bin && \
    ln -s /usr/bin/python /opt/bin/python
### End

RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.4/gosu-$(dpkg --print-architecture)" \
    && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.4/gosu-$(dpkg --print-architecture).asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu

# Download and extract the Packer binary (0.12.2).
ENV PACKER_VERSION=0.12.2
RUN curl -sOL https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip && \
    unzip packer_${PACKER_VERSION}_linux_amd64.zip && \
    rm -f packer_${PACKER_VERSION}_linux_amd64.zip

# Copy builder files into the image.
COPY . /opt/builder/

# Setup environment and launch Packer.
ENTRYPOINT ["/opt/builder/scripts/entrypoint.sh"]
CMD [ "/opt/builder/scripts/start.sh" ]
