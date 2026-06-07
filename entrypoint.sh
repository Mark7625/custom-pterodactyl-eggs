#!/bin/bash
export HOME=/home/container
export USER="${USER:-container}"
mkdir -p "$HOME" /home/container/logs /home/container/tmp

cd /home/container

MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e ":/home/container$ ${MODIFIED_STARTUP}"

eval ${MODIFIED_STARTUP}
