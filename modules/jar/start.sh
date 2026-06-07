#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "${RED}[Jar] Error on line $LINENO${NC}"' ERR

BLUE='\033[0;34m'; BOLD_BLUE='\033[1;34m'
WHITE='\033[0;37m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

header() {
  echo -e "${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}[Jar] $1${NC}"
}

SERVER_JAR="${SERVER_JAR:-app.jar}"
APP_ARGS="${APP_ARGS:-}"
APP_PORT="${APP_PORT:-${SERVER_PORT:-}}"
JAVA_OPTS="${JAVA_OPTS:--Xms128M -XX:MaxRAMPercentage=95.0}"
JAVA_STARTUP="${JAVA_STARTUP:-}"

JAR_PATH="/home/container/${SERVER_JAR}"

header "Starting JAR"

if [[ ! -f "$JAR_PATH" ]]; then
  echo -e "${RED}[Jar] JAR not found: ${JAR_PATH}${NC}"
  exit 1
fi

mkdir -p /home/container/logs /home/container/tmp
export HOME=/home/container
cd /home/container

resolved_args="$APP_ARGS"
if [[ -n "$APP_PORT" ]]; then
  if [[ -z "$resolved_args" ]]; then
    resolved_args="$APP_PORT"
  elif [[ "$resolved_args" != *"$APP_PORT"* ]]; then
    resolved_args="${resolved_args} ${APP_PORT}"
  fi
fi

if [[ -n "$JAVA_STARTUP" ]]; then
  startup_cmd="$JAVA_STARTUP"
else
  startup_cmd="java ${JAVA_OPTS} -Duser.dir=/home/container -jar \"${JAR_PATH}\" ${resolved_args}"
fi

echo -e "${WHITE}[Jar] Java: $(java -version 2>&1 | head -1)${NC}"
echo -e "${WHITE}[Jar] JAR:  ${SERVER_JAR}${NC}"
echo -e "${WHITE}[Jar] Command: ${startup_cmd}${NC}"
echo -e "${GREEN}[Jar] Services successfully launched${NC}"
exec bash -lc "$startup_cmd"
