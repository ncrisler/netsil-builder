#!/bin/bash

function display_usage() {
    echo "Usage: ./setup.sh [-a APPS_DIR] [-i IMAGES_DIR]

Parameters:
  -a, --apps-dir     The apps directory (default: ./apps)
  -i, --images-dir   The images export directory (default: ./images)
"
    exit 1
}

####################################
### Parse command line arguments ###
####################################
while [ $# -gt 0 ]; do
    case $1 in
        -a|--apps-dir)
            APPS_DIR="$2"
            shift 2
            ;;
        -i|--images-dir)
            IMAGES_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter \"$1\"" 1>&2
            display_usage
            exit 2
            ;;
    esac
done

##########################
### Set default values ###
##########################
APPS_DIR=${APPS_DIR:-$PWD/apps}
IMAGES_DIR=${IMAGES_DIR:-$PWD/images}

if [ ! -d "$APPS_DIR" ]; then
    echo "Apps directory not found."
fi

# Create images directory if it does not exist.
if [ ! -d "$IMAGES_DIR" ]; then
    mkdir $IMAGES_DIR
fi

# Pull and save Netsil AOC images.
for app in ${APPS_DIR}/build/specs/*.json; do
    image=$(jq --raw-output < ${app} 'select(.container.docker.image != null) .container.docker.image')
    if [ -n $image ] ; then
        image_filename=$(echo $image | cut -d\/ -f2).tar.gz
        docker pull $image
        docker save $image > ${IMAGES_DIR}/${image_filename}
    fi
done
