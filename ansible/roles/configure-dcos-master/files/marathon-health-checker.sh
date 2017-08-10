#!/bin/bash

MARATHON_HOST=${MARATHON_HOST:-127.0.0.1}
MARATHON_PORT=${MARATHON_PORT:-8080}

# wait for marathon to initialize before starting health check
echo "Waiting for Marathon to initialize..."
sleep 10m

# monitor marathon's health periodically
echo "Starting periodic ping of Marathon..."
while true
do
    # perform a marathon ping
    response=$(curl --connect-timeout 30 --max-time 60 http://${MARATHON_HOST}:${MARATHON_PORT}/ping)

    if [ "$response" != "pong" ]
    then
        echo "Failure: Did not receive a pong response"
        echo $response

        # Restarting marathon via systemctl
        echo "Restarting marathon..."
        systemctl restart dcos-marathon

        # after a restart, give it sometime to recover
        sleep 5m
    else
        echo "Success: Pong Response Received"
    fi

    # check health every minute
    sleep 1m
done