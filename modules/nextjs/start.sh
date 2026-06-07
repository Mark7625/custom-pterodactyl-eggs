#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "${RED}[Next.js] Error on line $LINENO${NC}"' ERR

BLUE='\033[0;34m'; BOLD_BLUE='\033[1;34m'
WHITE='\033[0;37m'; GREEN='\033[0;32m'
YELLOW='\033[0;33m'; RED='\033[0;31m'
NC='\033[0m'

header() {
  echo -e "${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}[Next.js] $1${NC}"
}

NEXTJS_STATUS="${NEXTJS_STATUS:-${REACT_STATUS:-true}}"
NEXTJS_VERSION="${NEXTJS_VERSION:-16}"
APP_DIR="${APP_DIR:-/home/container/www}"
INSTALL_COMMAND="${INSTALL_COMMAND:-npm install}"
BUILD_COMMAND="${BUILD_COMMAND:-npx next build}"
START_COMMAND="${START_COMMAND:-npx next start}"
SERVE_MODE="${SERVE_MODE:-node}"
APP_PORT="${APP_PORT:-3000}"
BUILD_OUTPUT_DIR="${BUILD_OUTPUT_DIR:-out}"
APP_PID_FILE="/home/container/tmp/nextjs.pid"
APP_LOG_FILE="/home/container/logs/nextjs.log"
SERVE_MODE_FILE="/home/container/tmp/serve_mode"
WEBSITE_UPDATED_FILE="${WEBSITE_UPDATED_FILE:-/home/container/tmp/website_updated}"

enabled() { [[ "$1" =~ ^(true|1)$ ]]; }

if ! enabled "$NEXTJS_STATUS"; then
  exit 0
fi

header "Building Next.js Application"

if [[ ! -f "${APP_DIR}/package.json" ]]; then
  echo -e "${YELLOW}[Next.js] No package.json found in ${APP_DIR}; skipping.${NC}"
  echo "static" > "$SERVE_MODE_FILE"
  exit 0
fi

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo -e "${RED}[Next.js] Node.js/npm not available; cannot build.${NC}"
  exit 1
fi

mkdir -p /home/container/logs /home/container/tmp /home/container/.npm
export HOME=/home/container
export NPM_CONFIG_CACHE=/home/container/.npm
export npm_config_cache=/home/container/.npm
export COREPACK_HOME=/home/container/.corepack
export NPM_CONFIG_UPDATE_NOTIFIER=false
cd "$APP_DIR"

echo -e "${WHITE}[Next.js] Target v${NEXTJS_VERSION} | Node $(node -v) | npm $(npm -v)${NC}"
echo -e "${WHITE}[Next.js] HOME=${HOME} | npm cache=${NPM_CONFIG_CACHE}${NC}"

run_install() {
  if enabled "${CLEAN_NODE_MODULES:-0}" && [[ -d node_modules ]]; then
    echo -e "${YELLOW}[Next.js] CLEAN_NODE_MODULES=1 — removing existing node_modules${NC}"
    rm -rf node_modules
  fi
  eval "$INSTALL_COMMAND"
}

needs_install=false
needs_build=false
website_update_reason=""

if [[ -f "$WEBSITE_UPDATED_FILE" ]]; then
  website_update_reason=$(tr -d '\n\r' < "$WEBSITE_UPDATED_FILE")
  needs_install=true
  needs_build=true
elif [[ ! -d node_modules ]]; then
  needs_install=true
  needs_build=true
elif [[ ! -d .next ]]; then
  needs_build=true
fi

if enabled "${CLEAN_NODE_MODULES:-0}"; then
  needs_install=true
fi

if [[ -f /home/container/.rebuild_requested ]]; then
  echo -e "${WHITE}[Next.js] Rebuild requested via cron flag.${NC}"
  needs_install=true
  needs_build=true
  rm -f /home/container/.rebuild_requested
fi

if $needs_install; then
  if [[ -n "$website_update_reason" ]]; then
    echo -e "${WHITE}[Next.js] Git update detected (${website_update_reason}); installing dependencies${NC}"
  else
    echo -e "${WHITE}[Next.js] Installing dependencies (first run or missing node_modules)${NC}"
  fi
  echo -e "${WHITE}[Next.js] Command: ${INSTALL_COMMAND}${NC}"
  if ! run_install; then
    echo -e "${YELLOW}[Next.js] Install failed; removing node_modules and retrying once...${NC}"
    rm -rf node_modules
    run_install
  fi
  rm -f "$WEBSITE_UPDATED_FILE"
else
  echo -e "${YELLOW}[Next.js] Skipping npm install — no git updates since last start.${NC}"
fi

if $needs_build; then
  echo -e "${WHITE}[Next.js] Building: ${BUILD_COMMAND}${NC}"
  eval "$BUILD_COMMAND"
else
  echo -e "${YELLOW}[Next.js] Skipping build — no git updates and existing .next output found.${NC}"
fi

if [[ "$SERVE_MODE" == "static" ]]; then
  if [[ ! -d "${APP_DIR}/${BUILD_OUTPUT_DIR}" ]]; then
    echo -e "${RED}[Next.js] Static output not found: ${BUILD_OUTPUT_DIR}${NC}"
    exit 1
  fi
  ln -sfn "${APP_DIR}/${BUILD_OUTPUT_DIR}" /home/container/public
  echo "static" > "$SERVE_MODE_FILE"
  echo -e "${GREEN}[Next.js] Static export ready at /home/container/public${NC}"
  exit 0
fi

if [[ -z "$START_COMMAND" || "$START_COMMAND" == "none" ]]; then
  if [[ -d "${APP_DIR}/${BUILD_OUTPUT_DIR}" ]]; then
    ln -sfn "${APP_DIR}/${BUILD_OUTPUT_DIR}" /home/container/public
    echo "static" > "$SERVE_MODE_FILE"
    exit 0
  fi
  echo -e "${RED}[Next.js] Build finished but Next.js server was not started.${NC}"
  exit 1
fi

echo "node" > "$SERVE_MODE_FILE"
echo -e "${WHITE}[Next.js] Starting server: ${START_COMMAND}${NC}"
echo -e "${WHITE}[Next.js] Internal port: ${APP_PORT} (Nginx proxies your SITE_PORT to this)${NC}"

export PORT="$APP_PORT"
export HOSTNAME="127.0.0.1"

nohup bash -lc "$START_COMMAND" >> "$APP_LOG_FILE" 2>&1 &
app_pid=$!
echo "$app_pid" > "$APP_PID_FILE"

echo -e "${YELLOW}[Next.js] Waiting for server to become ready...${NC}"
for i in $(seq 1 120); do
  if ! kill -0 "$app_pid" 2>/dev/null; then
    echo -e "${RED}[Next.js] Server process exited unexpectedly.${NC}"
    tail -n 20 "$APP_LOG_FILE" | sed 's/^/  /'
    exit 1
  fi

  if curl -fsS "http://127.0.0.1:${APP_PORT}/" >/dev/null 2>&1 \
    || curl -fsS "http://127.0.0.1:${APP_PORT}" >/dev/null 2>&1; then
    echo -e "${GREEN}[Next.js] Server is live on port ${APP_PORT} (pid ${app_pid})${NC}"
    exit 0
  fi

  sleep 1
done

echo -e "${YELLOW}[Next.js] Server started but health check timed out; continuing anyway.${NC}"
echo -e "${YELLOW}[Next.js] Check logs: ${APP_LOG_FILE}${NC}"
