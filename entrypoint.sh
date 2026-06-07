#!/bin/bash
# Pterodactyl may set the runtime user home to /nonexistent; npm needs a real HOME.
export HOME=/home/container
export USER="${USER:-container}"
export NPM_CONFIG_CACHE=/home/container/.npm
export COREPACK_HOME=/home/container/.corepack
mkdir -p "$HOME" "$NPM_CONFIG_CACHE" "$COREPACK_HOME" /home/container/logs /home/container/tmp

cd /home/container

# Replace Startup Variables
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}