## Introduction
This *netsil-builder* repository provides scripts to install and deploy Netsil AOC.

Currently, these scripts support CoreOS and CentOS. They have been tested on CoreOS 1068.9.0, CoreOS 1268.6.0, and CentOS 7, though it should work on other versions of those Linux distributions.

Support for other Linux distributions is planned for future releases.

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
* Docker (preferably v.1.10.0 or above) is installed and configured correctly
* Python 2 is installed and available at `/usr/bin/python`

## Usage
To use the deploy script run the `setup.sh` script.
Running this script without arguments will print a short help section.
Here, we will elaborate on some of the parameters of `setup.sh`

`-d, --dcos-path`
Pass

`-r, --registry`
Pass
For instance, if we were using 'gcr.io/netsil-images/netsil/<image>', 
we would pass 'gcr.io/netsil-images' for this parameter.

`-o, --offline`
Pass

## Misc
