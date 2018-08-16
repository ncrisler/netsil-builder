#!/bin/bash

function display_usage() {
    echo "Usage: ./setup.sh -c config_file [-s stage]

Parameters:
    -c, --config        Path to config.yaml file, which is the source of configuration for the AOC cluster
    -s, --stages        If set to 'auto', this script will run through all stages automatically. Otherwise, it will only run the given stage.
"
    exit 1
}


####################################
### Parse command line arguments ###
####################################
while [ $# -gt 0 ]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter \"$1\"" 1>&2
            display_usage
            exit 2
            ;;
    esac
done


### Stages: init, infra, install, validate
docker run "Some docker run command that will take stage as input"

