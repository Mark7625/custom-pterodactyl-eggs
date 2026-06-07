#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "${RED}[Ktor] Error on line $LINENO${NC}"' ERR

BLUE='\033[0;34m'; BOLD_BLUE='\033[1;34m'
WHITE='\033[0;37m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

header() {
  echo -e "${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}[Ktor] $1${NC}"
}

enabled() { [[ "$1" =~ ^(true|1|yes|on)$ ]]; }

KTOR_STATUS="${KTOR_STATUS:-1}"
SERVER_JAR="${SERVER_JAR:-app.jar}"
APP_PORT="${APP_PORT:-${SERVER_PORT:-8080}}"
APP_ARGS="${APP_ARGS:-}"
APP_PORT_METHOD="${APP_PORT_METHOD:-property}"
JAVA_OPTS="${JAVA_OPTS:--Xms128M -XX:MaxRAMPercentage=95.0}"
JVM_EXTRA_FLAGS="${JVM_EXTRA_FLAGS:-}"
JAVA_STARTUP="${JAVA_STARTUP:-}"

JAR_PATH="/home/container/${SERVER_JAR}"

if ! enabled "$KTOR_STATUS"; then
  exit 0
fi

header "Starting Java application"

if [[ ! -f "$JAR_PATH" ]]; then
  echo -e "${RED}[Ktor] JAR not found: ${JAR_PATH}${NC}"
  exit 1
fi

mkdir -p /home/container/logs /home/container/tmp
export HOME=/home/container
cd /home/container

echo -e "${WHITE}[Ktor] Java: $(java -version 2>&1 | head -1)${NC}"
echo -e "${WHITE}[Ktor] JAR:  ${SERVER_JAR}${NC}"
echo -e "${WHITE}[Ktor] Port: ${APP_PORT}${NC}"

port_args=()
case "$(echo "${APP_PORT_METHOD}" | tr '[:upper:]' '[:lower:]')" in
  property|ktor|system) port_args+=("-Dktor.deployment.port=${APP_PORT}") ;;
  cli|args|argument) ;;
  none|off|disabled) ;;
  *) port_args+=("-Dktor.deployment.port=${APP_PORT}") ;;
esac

resolved_app_args="$APP_ARGS"
case "$(echo "${APP_PORT_METHOD}" | tr '[:upper:]' '[:lower:]')" in
  cli|args|argument)
    if [[ -z "$resolved_app_args" ]]; then
      resolved_app_args="$APP_PORT"
    elif [[ "$resolved_app_args" != *"$APP_PORT"* ]]; then
      resolved_app_args="${resolved_app_args} ${APP_PORT}"
    fi
    ;;
esac

if [[ -n "$JAVA_STARTUP" ]]; then
  startup_cmd="$JAVA_STARTUP"
else
  startup_cmd="java ${JAVA_OPTS} ${JVM_EXTRA_FLAGS} ${port_args[*]} -Duser.dir=/home/container -jar \"${JAR_PATH}\" ${resolved_app_args}"
fi

echo -e "${WHITE}[Ktor] Command: ${startup_cmd}${NC}"
echo -e "${GREEN}[Ktor] Services successfully launched${NC}"
exec bash -lc "$startup_cmd"
