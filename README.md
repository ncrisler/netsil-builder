## About
The Netsil Application Operations Center (AOC) is a next-gen observability and analytics tool for modern cloud applications.

## Introduction
This repository provides scripts to install and deploy the AOC.

Currently, these scripts support CoreOS and CentOS. They have been tested on CoreOS Stable and CentOS 7, though they should work on other versions of those Linux distributions.

Support for more Linux distributions is planned.

## Documentation
You can browse through our [full documentation](https://netsil.github.io/docs), which provides API documentation, user guides, and more.

## Prerequisites 
### Resource Requirements
Please provision a machine with sufficient resources to run Netsil AOC. The requirements are listed below.

| Recommended | Minimum    |
| ----------- | --------   |
| 8 CPU       | 4 CPU      |
| 32 GB Mem   | 16 GB Mem  |
| 500 GB HDD  | 120 GB HDD |

### Ports
Ensure that port **443** and port **80** (optional) are open for web access to the AOC through HTTPS or HTTP.

Additionally, the following ports must be open on the AOC host to receive inbound traffic from the collectors:
* **2001** (TCP) for collectors metrics channel.
* **2003** (TCP and UDP) for collectors control and data channel.

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

## Quickstart
To get started quickly, SSH into the machine where you're installing the AOC.
Then, run the setup script:

`./setup.sh -h 127.0.0.1`

If you have an internal DNS server(s), we also recommend passing that in as a parameter to the setup script. E.g.:

`./setup.sh -h 127.0.0.1 -n 192.168.1.1`

When the installation completes, you can access the AOC at `https://<your-machine-ip-address>`.

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
