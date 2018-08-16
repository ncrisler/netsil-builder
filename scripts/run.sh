#!/bin/bash
# TODO: Switch to case statement later
if [ "${STAGE}" = "init" ] ; then
elif [ "${STAGE}" = "infra" ] ; then
    # run terraform commands
elif [ "${STAGE}" = "install" ] ; then
    # run ansible commands
elif [ "${STAGE}" = "validate" ] ; then
else
    echo "Error: Did not recognize stage $STAGE"
    exit 1
fi
