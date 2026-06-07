#!/usr/bin/env bash
set -euo pipefail

cd /home/container

SERVER_JAR="${SERVER_JAR:-server.jar}"

# shellcheck source=start-modules.sh
source ./start-modules.sh

if [[ ! -f "${SERVER_JAR}" ]]; then
    echo "[Orchestrator] ERROR: JAR not found: ${SERVER_JAR}"
    echo "[Orchestrator] Set Server update to Automatic or Notification, or upload ${SERVER_JAR} manually."
    exit 1
fi

if [[ ! -f "game.yml" ]]; then
    echo "[Orchestrator] ERROR: game.yml was not created."
    echo "[Orchestrator] Check that all required Startup variables are set (Revision, Environment, World id, World key, DB password)."
    exit 1
fi

if [[ ! -d ".data/cache/SERVER" ]]; then
    echo "[Orchestrator] ERROR: .data/cache/SERVER not found"
    echo "[Orchestrator] Run Server update to download a release zip, or install cache data manually."
    exit 1
fi

exec java -Xms1g -XX:AutoBoxCacheMax=65535 -XX:MaxRAMPercentage=95.0 ${JAVA_OPTS:-} ${JVM_EXTRA_FLAGS:-} \
    -Duser.dir=/home/container \
    -jar "${SERVER_JAR}"
