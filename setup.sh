#!/bin/bash

OS=""
VER=""
PYTHON_VERSION=""
declare -a to_install=()

function display_usage() {
    echo "Usage: ./setup.sh -h hostname [-k ssh_key] [-a apps_dir] [-u username] [-d dcos_path] [-r registry] [-o offline] [-y yes-all]


Parameters:
  -h, --host         Server hostname of IP address
  -k, --ssh-key      Private SSH key path (default: ~/.ssh/id_ra)
  -a, --apps-dir     The apps directory (default: ./apps)
  -u, --user         SSH user for deployment (default: $USER)
  -d, --dcos-path    Path to the DCOS release package
  -r, --registry     For use with third party registries (default: dockerhub)
                     You should pass the repository prefix of the 'netsil/<image>' images.
  -o, --offline      Are we deploying offline? Choose 'yes' or 'no' (default: no)
  -s, --skip-query   Skip query and auto-respond yes or no. Choose 'yes' or 'no' (default: no)
"
    exit 1
}

function deploy_aoc() {
    echo "deploying aoc"
    builder_image=netsil/netsil-builder
    if [ "${OFFLINE}" = "no" ]; then
        sudo docker build -t ${builder_image} ${DIR}
    else
        if [ "${REGISTRY}" != "dockerhub" ] ; then
            builder_image=${REGISTRY}/netsil/netsil-builder
        fi
    fi

    if [ $? -eq 0 ]; then
        sudo docker run --rm --privileged -${INTERACTIVE} \
            $DCOS_VOLUME_ARG \
            -v ${APPS_DIR}:/apps \
            -v ${SSH_PRIVATE_KEY}:/credentials/id_rsa \
            -v ${CREDENTIALS_PATH}:/opt/credentials \
            -e DISTRIB=$DISTRIB \
            -e HOST=$HOST \
            -e ANSIBLE_USER=$ANSIBLE_USER \
            -e REGISTRY=$REGISTRY \
            ${builder_image} \
            /opt/builder/scripts/deploy.sh
    fi
}

function abs_path() {
    (
    cd $(dirname $1)
    echo $PWD/$(basename $1)
    )
}

function detect_os_version() {
    # Do checks based on linux distribution
    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/SuSe-release ]; then
        # Older SuSE/etc.
        ...
    elif [ -f /etc/redhat-release ]; then
        # Older Red Hat, CentOS, etc.
        ...
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    echo "OS is $OS and Version is $VER"
}

function parse_input() {
    prompt_text=$1
    yes_action=$2
    no_text=$3

    read -p "${prompt_text}" choice
    if [ "$SKIP_QUERY" = "yes" ] ; then
        choice=y
    fi
    case "$choice" in
        y|Y|"" )
            $yes_action
            ;;
        n|N )
            echo "$no_text"
            exit 0
            ;;
        * )
            echo "Exiting. Invalid choice."
            exit 1
            ;;
    esac
}

function install_docker() {
    if [ "$OS" = "ubuntu" ] ; then
        sudo apt-get -y update
        sudo apt-get -y install \
             apt-transport-https \
             ca-certificates \
             curl \
             software-properties-common

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

        sudo add-apt-repository \
             "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

        sudo apt-get -y update
        sudo apt-get -y install docker-ce=17.12.0*
    else
        echo "This script is not yet able to install docker for your OS"
	echo "Exiting for manual package installation."
	exit 0
    fi
}
function symlink_python () { sudo ln -s /usr/bin/python2.7 /usr/bin/python ; }
function install_python() {
    if [ "$OS" = "ubuntu" ] ; then
        sudo apt-get -y update
        sudo apt-get -y install python2.7
        if [ ! -f /usr/bin/python ] && [ -f /usr/bin/python2.7 ] ; then
            parse_input "Found python2.7 binary. Do you want this script to symlink it to /usr/bin/python for you? (y/n) " symlink_python "Exiting. Please symlink python2.7 to /usr/bin/python manually."
        else
            "Exiting. Cannot find python2.7 binary. Please symlink python2.7 binary to /usr/bin/python manually."
            exit 1
        fi
    else
        echo "This script is not yet able to install python for your OS"
        echo "Exiting for manual package installation."
        exit 0
    fi
}

function check_docker() {
    echo "Checking docker"
    (command -v docker || docker) > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        echo "Unable to locate 'docker' in your path."
        parse_input "Do you want this script to install it for you? (y/n) " install_docker "Exiting for manual package installation."
    fi

    sudo docker info > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
        echo "Docker does not appear to be running locally. Please start the Docker daemon and ensure it is enabled at startup."
        exit 1
    fi

    echo "Docker check passed."
}

function python_version_check() {
    symlink=$1
    # Check python version as well
    python_major_version=$(/usr/bin/python -c 'import platform; print(platform.python_version_tuple()[0])')
    if [ "${python_major_version}" = "2" ] ; then
        echo "Python check passed."
    else
        echo "Python check failed."
        echo "Python major version is ${python_major_version}. Please install python 2."
        exit 1
    fi
}

function check_python() {
    if [ -x "/usr/bin/python" ] ; then
        python_version_check
    else
        echo "Unable to locate 'python' in your path."
        parse_input "Do you want this script to install it for you? (y/n) " install_python "Exiting for manual package installation."
    fi
}

function check_jq() {
    if [ -x "/usr/bin/jq" ] ; then
        echo "jq check passed."
    else
        echo "jq was not installed. Adding to list of packages to install."
        exit 1
    fi
}

function check_ubuntu() {
    # Do symlinking
    declare -a binaries=("mkdir" "ln" "tar")
    for i in "${binaries[@]}"
    do
        if [ ! -f "/usr/bin/$i" ] ; then
            echo "Symlinking $i"
            sudo ln -s /bin/$i /usr/bin/$i
        fi
    done

    if [ ! -f "/usr/bin/useradd" ] ; then
        sudo ln -s /usr/sbin/useradd /usr/bin/useradd
    fi

    to_install+=("unzip")
    to_install+=("ipset")
    to_install+=("selinux-utils")
    to_install+=("jq")
}

function check_coreos() {
    echo ""
}

function check_centos() {
    echo ""
}

function check_by_distrib() {
    if [ "$OS" = "ubuntu" ] ; then
        if [ "$VER" = "16.04" ] ; then
            check_ubuntu
        else
            echo "Exiting. This script only supports Ubuntu 16.04"
            exit 1
        fi
    elif [ "$OS" = "coreos" ] ; then
        check_coreos
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] ; then
        check_centos
    fi
}

function not_supported() {
    echo "This script does not support installing packages for your OS."
    parse_input "Proceed anyway with (y), exit to install packages manually with (n) " echo "Exiting for manual package installation."
}

function pkg_install_helper() {
    if [ "$OS" = "ubuntu" ] ; then
        sudo apt-get install -y $pkgs
    else
        not_supported
    fi
}

function install_missing_pkgs() {
    pkgs=$( IFS=$' '; echo "${to_install[*]}" )
    echo "We need to install the following packages: $pkgs"
    parse_input "Proceed? (y/n) " pkg_install_helper "Exiting. These packages must be installed."
}

###########################################################
### Check SSH key authentication and Linux distribution ###
###########################################################
function check_ssh_auth() {
    DISTRIB=$(ssh -i $SSH_PRIVATE_KEY \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        ${ANSIBLE_USER}@${HOST} "sed -n 's/^ID=//p' /etc/os-release")

    if [ "$?" -ne 0 ]; then
        echo "There appears to be a problem with SSH public/private key authentication."
        exit 1
    fi
}

###############################################################################
### Generate SSH keys and configure key authentication for local deployment ###
###############################################################################
function setup_ssh_auth() {
    if [ ! -d "~/.ssh" ]; then
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
    fi

    ssh-keygen -q -b 2048 -t rsa -N '' -f $DIR/netsil_rsa
    cat $DIR/netsil_rsa.pub >> ~/.ssh/authorized_keys
    SSH_PRIVATE_KEY=$DIR/netsil_rsa
}

####################################
### Parse command line arguments ###
####################################
while [ $# -gt 0 ]; do
    case $1 in
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -k|--ssh-key)
            SSH_PRIVATE_KEY="$2"
            shift 2
            ;;
        -a|--apps-dir)
            APPS_DIR="$2"
            shift 2
            ;;
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -d|--dcos-path)
            DCOS_PATH="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -o|--offline)
            OFFLINE="$2"
            shift 2
            ;;
        -s|--skip-query)
            SKIP_QUERY="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter \"$1\"" 1>&2
            display_usage
            exit 2
            ;;
    esac
done

# Get the directory this script is in
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

### Set default values and convert to absolute paths ###
SSH_PRIVATE_KEY=${SSH_PRIVATE_KEY:-~/.ssh/id_rsa}
SSH_PRIVATE_KEY=$(abs_path $SSH_PRIVATE_KEY)
APPS_DIR=${APPS_DIR:-$DIR/apps}
APPS_DIR=$(abs_path $APPS_DIR)
CREDENTIALS_PATH=${CREDENTIALS_PATH:-~/credentials}
ANSIBLE_USER=$USER
REGISTRY=${REGISTRY:-"dockerhub"}
OFFLINE=${OFFLINE:-"no"}
SKIP_QUERY=${SKIP_QUERY:-"manual"}
############################################################
### If DCOS_PATH is defined:                             ###
###  * Replace with relative path with an absolute path. ###
###  * Set Docker volume mount argument.                 ###
############################################################
if [ -n "$DCOS_PATH" ]; then
    DCOS_PATH=$(abs_path $DCOS_PATH)
    DCOS_VOLUME_ARG="-v $DCOS_PATH:/data/dcos_generate_config.sh"
fi

### Start: Docker-specific env vars ###
INTERACTIVE=${INTERACTIVE:-"yes"}
### End: Docker-specific env vars ###

### Start: Netsil-specific env vars ###
# TODO: Make these variables able to be overwritten by environment variables.
export URI_NAMESPACE=${URI_NAMESPACE:-netsilprivate}
export BUILD_ENV=${BUILD_ENV:-production}
export NETSIL_BUILD_BRANCH=${NETSIL_BUILD_BRANCH:-master}
export NETSIL_VERSION_NUMBER=${NETSIL_VERSION_NUMBER:-0.2.0}
export NETSIL_COMMIT_HASH=${NETSIL_COMMIT_HASH}
export NETSIL_BUILD_NUMBER=${NETSIL_BUILD_NUMBER}
export RESOURCE_ROLE=${RESOURCE_ROLE:-*}
export FORCE_PULL_IMAGE=${FORCE_PULL_IMAGE:-false}
### End: Netsil-specific env vars ###

###########################
### Interactive setting ###
###########################
# This must be non-interactive in jenkins, but when running locally, "INTERACTIVE" allows us to ctrl-c out of the application.
if [[ ${INTERACTIVE} = "yes" ]] ; then
    INTERACTIVE="it"
else
    INTERACTIVE="t"
fi

#############################
### Run build-time checks ###
#############################
if [ -z ${HOST} ]; then
    echo "Could not find host: $HOST" 1>&2
    display_usage
    exit 1
fi

if [ "$HOST" == "localhost" ] || [ "$HOST" == "127.0.0.1" ]; then
    DEPLOY=local
fi

if [ ! -f "${SSH_PRIVATE_KEY}" ] && [ "$DEPLOY" != "local" ]; then
    echo "The private SSH key \"$SSH_PRIVATE_KEY\" does not appear to exist."
    display_usage
    exit 1
fi

if [ ! -d "${APPS_DIR}" ]; then
    echo "The apps directory \"$APPS_DIR\" does not appear to exist."
    display_usage
    exit 1
fi

# Root check
if [ $(id -u) = 0 ]; then
   echo "Please run this script as a non-root user. This script will invoke sudo when it needs to."
   exit 1
fi

###################
### Gather info ###
###################
detect_os_version

##########################
### Pre-install checks ###
##########################
# These require more custom installation than a simple "apt-get" or "yum"
check_docker
check_python

##################################
### Perform OS-specific checks ###
##################################
check_by_distrib
install_missing_pkgs

###########################
### Post-install checks ###
###########################
check_jq

##########################################
### Local deployment pre-configuration ###
##########################################
if [ "$DEPLOY" == "local" ]; then
    # Use Docker bridge IP address when setting host to localhost.
    HOST=$(ip -f inet addr show docker0 | grep -Po 'inet \K[\d.]+')

    # Setup local SSH key authentication.
    if [ ! -f "${SSH_PRIVATE_KEY}" ]; then
        setup_ssh_auth
    fi
fi

##########################################
### Perform prerequisite check for SSH ###
##########################################
check_ssh_auth

####################################
### Resolving NETSIL_VERSION_TAG ###
####################################
# TODO: We eventually want to generate the VERSION_TAG from the buildvar files in the apps directory.
# Then, we won't have to pass in all of these variables at buildtime
if [[ ${NETSIL_BUILD_BRANCH} = "stable" ]] || [[ ${NETSIL_BUILD_BRANCH} = "staging" ]] ; then
    export NETSIL_VERSION_TAG=${NETSIL_BUILD_BRANCH}-${NETSIL_VERSION_NUMBER}
else
    export NETSIL_VERSION_TAG=${NETSIL_BUILD_BRANCH}-${NETSIL_VERSION_NUMBER}-${NETSIL_COMMIT_HASH}.${NETSIL_BUILD_NUMBER}
fi

export IS_PRIVATE_REGISTRY=false
if [[ ${URI_NAMESPACE} != "netsil" ]] ; then
    export IS_PRIVATE_REGISTRY=true
fi

###################################
### Launch deployment container ###
###################################
deploy_aoc
