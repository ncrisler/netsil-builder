## About
The Netsil Application Operations Center (AOC) is a next-gen observability and analytics tool for modern cloud applications.

## Introduction
This repository provides scripts to install and deploy the AOC.

Currently, these scripts support CoreOS Stable, CentOS 7, and Ubuntu 16.04.

Please contact us if you require support for other Linux distributions.

## Documentation
You can browse through our [full documentation](https://docs.netsil.com), which provides API documentation, user guides, and more.

## Prerequisites 
### Resource Requirements
Please provision a machine with sufficient resources to run Netsil AOC. The requirements are listed below.

| Recommended |
| ----------- |
| 8 vCPU      |
| 32 GB RAM   |
| 500 GB SSD  |

### Ports
The following ports must be open on the AOC host:
* **2000** (TCP) for collectors control and data channel.
* **2001** (TCP) for collectors metrics channel.
* **80/443** (TCP) for AOC web UI access.

Finally, Netsil requires an open channel to a license site for verifying your license key.
Thus, ensure that you can reach `lm.netsil.com` on port 443 from where you are running the AOC.

### SSH Access
You will need SSH access to the machine where you're installing the AOC.

### CentOS
If deploying on a CentOS machine, ensure that:
* Docker (preferably v.1.10.0 or above) is installed and configured to run at OS startup.
* Python 2 is installed and available at `/usr/bin/python`.
* The `jq` program is installed. You can enable the EPEL repository and install via `yum install jq`.
* The `firewalld` service is stopped and disabled: `systemctl stop firewalld && systemctl disable firewalld`.
* Please run the command `setenforce 0` as well for permissive selinux mode

The `setup.sh` script can walk you through the installation and configuration of the above if you wish.

### Ubuntu
If deploying on an Ubuntu machine, ensure that:
* Docker (preferably v.1.10.0 or above) is installed and configured to run at OS startup.
* Python 2 is installed and available at `/usr/bin/python`.
* The `jq` program is installed. You can enable the EPEL repository and install via `yum install jq`.

The `setup.sh` script can walk you through the installation and configuration of the above if you wish.

## Quickstart
To get started quickly, SSH into the machine where you're installing the AOC.

As a **non-root** user, run the following setup script:

`./setup.sh -h 127.0.0.1`

This will start the installation process.

The `setup.sh` script will also attempt to install and configure certain programs on your OS.
If you wish to accept all of its changes, you can automate it by running the script like so:

`./setup.sh -h 127.0.0.1 -s yes`

This will auto-fill all of the yes/no user-input prompts with `yes`.

## Advanced Usage
Here, we will elaborate on some of the advanced usage parameters of `setup.sh`:

`-o, --offline`

This parameter must be set to `Yes` if you are running these deploy scripts "offline", or without access to the public Internet.

`-d, --dcos-path`

Specifying the dcos path will likely be necessary if you are running the deploy scripts offline.
In this parameter, you must specify the locally sourced path to the DC/OS binary. 
You may download this binary [here](https://downloads.dcos.io/dcos/EarlyAccess/commit/14509fe1e7899f439527fb39867194c7a425c771/dcos_generate_config.sh).

`-r, --registry`

By default, the container images that Netsil uses are sourced from Dockerhub. Thus, the image names are of the format `netsil/<image>`.
However, you may wish to pull these images into your own docker registry and source the installation from that registry instead of Dockerhub. In that case, you would need to provide this parameter.

For instance, if we were using `gcr.io/netsil-images/netsil/<image>`, we would pass in `gcr.io/netsil-images` for this parameter.
Please make sure that your docker daemon is also authenticated to pull from your third party registry.

If you wish to download the set of Netsil images necessary for installation, you can do so with the command
```
python ./scripts/download-images.py
```

If you only wish to print the names of those images, you can do so with the command
```
python ./scripts/download-images.py print
```

## Support
For help please join our public [slack channel](http://slack.netsil.com) or email support@netsil.com

## Misc
The `setup.sh` script first builds a `netsil/netsil-builder` docker image and runs the AOC deployment from that image.

For the offline case, you may pull `netsil/netsil-builder` from Dockerhub and move it onto the machine where you are running these deploy scripts.

If you specified a `registry` parameter, we then assume that the image resides in `${registry}/netsil/netsil-builder`, where `${registry}` is your third party registry path.
