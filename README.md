## About
Netsil Application Operations Center (AOC) is a next-gen observability and analytics tool for modern cloud applications. The Netsil AOC helps SREs and DevOps improve the reliability and performance of API and microservices-driven production applications.

## Introduction
This repository provides scripts to install and deploy Netsil AOC.

Currently, these scripts support CoreOS and CentOS. They have been tested on CoreOS 1068.9.0, CoreOS 1268.6.0, and CentOS 7, though it should work on other versions of those Linux distributions.

Support for more Linux distributions is planned for future releases.

## Documentation
You can browse through our [full documentation](https://netsil.github.io/docs), which provides API documentation, user guides, and more.

## Prerequisites 
### Resource Requirements
You will need to allocate an instance with sufficient resources to run Netsil AOC.
The requirements are listed below.

| Recommended | Minimum    |
| ----------- | --------   |
| 8 CPU       | 4 CPU      |
| 32 GB Mem   | 16 GB Mem  |
| 500 GB HDD  | 120 GB HDD |

### Ports
Ensure that port **443** and port **80** (optional) are open for web access to Netsil AOC through HTTPS or HTTP

Additionally, the following ports must be open on the AOC host to receive inbound traffic from the collectors:
* **2001** (TCP) for collectors metrics channel.
* **2003** (TCP and UDP) for collectors control and data channel.

Finally, Netsil requires an open channel to a license site for verifying your license key.
Thus, ensure that you can reach `lm.netsil.com` on port 443 from where you are running Netsil AOC.

### CentOS
If deploying on a CentOS machine, ensure that:
* Docker (preferably v.1.10.0 or above) is installed and configured correctly.
* Python 2 is installed and available at `/usr/bin/python`.

## Usage
To deploy Netsil, run the `setup.sh` script.

Running this script without arguments will print a short help section. Here, we will elaborate on some of the parameters of `setup.sh`:

`-h, --host`

If these deploy scripts are running on the same machine where you intend to install Netsil, then specify '127.0.0.1' for the host.

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
For help please join our public [slack channel](https://netsil-users.slack.com) or email support@netsil.com

## Misc
The `setup.sh` script first builds a `netsil/netsil-builder` docker image and runs the AOC deployment from that image.

For the offline case, you may pull `netsil/netsil-builder` from Dockerhub and move it onto the machine where you are running these deploy scripts.

If you specified a `registry` parameter, we then assume that the image resides in `${registry}/netsil/netsil-builder`, where `${registry}` is your third party registry path.
