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

mkdir -p /home/container/logs /home/container/tmp
cd "$APP_DIR"

echo -e "${WHITE}[Next.js] Node $(node -v) | npm $(npm -v)${NC}"
echo -e "${WHITE}[Next.js] Installing dependencies: ${INSTALL_COMMAND}${NC}"
eval "$INSTALL_COMMAND"

echo -e "${WHITE}[Next.js] Building: ${BUILD_COMMAND}${NC}"
eval "$BUILD_COMMAND"

if [[ "$SERVE_MODE" == "static" ]]; then
  if [[ ! -d "${APP_DIR}/${BUILD_OUTPUT_DIR}" ]]; then
    echo -e "${RED}[Next.js] Static output not found: ${BUILD_OUTPUT_DIR}${NC}"
    echo -e "${YELLOW}[Next.js] For static export set output: 'export' in next.config and BUILD_OUTPUT_DIR=out${NC}"
    exit 1
  fi
  ln -sfn "${APP_DIR}/${BUILD_OUTPUT_DIR}" /home/container/public
  echo "static" > "$SERVE_MODE_FILE"
  echo -e "${GREEN}[Next.js] Static export ready at /home/container/public${NC}"
  exit 0
fi

if [[ -z "$START_COMMAND" || "$START_COMMAND" == "none" ]]; then
  echo -e "${YELLOW}[Next.js] No start command; falling back to static mode.${NC}"
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
echo -e "${WHITE}[Next.js] Listening on 127.0.0.1:${APP_PORT}${NC}"

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
