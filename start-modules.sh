#!/usr/bin/env bash
sed -i 's/\r$//' "$0"
find modules -type f -name "*.sh" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

set -euo pipefail
trap 'echo -e "${RED}[Orchestrator] Error on line $LINENO${NC}"' ERR

BLUE='\033[0;34m'; BOLD_BLUE='\033[1;34m'; NC='\033[0m'

header() {
  echo -e "\n${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}[Orchestrator] $1${NC}"
}

echo -e "\n${BOLD_BLUE}[Orchestrator] Ktor egg starting...${NC}"

is_enabled() { [[ "$1" =~ ^(true|1|yes|on)$ ]]; }

jarupdate_enabled() {
  if ! is_enabled "${JAR_UPDATE_STATUS:-1}"; then
    return 1
  fi
  case "$(echo "${JAR_UPDATE_MODE:-Automatic}" | tr '[:upper:]' '[:lower:]')" in
    disabled|disable|off|0|false|no) return 1 ;;
    *) return 0 ;;
  esac
}

AUTOUPDATE_STATUS="${AUTOUPDATE_STATUS:-1}"
if is_enabled "$AUTOUPDATE_STATUS" && [[ -f modules/autoupdate/start.sh ]]; then
  header "Running module: autoupdate"
  modules/autoupdate/start.sh
fi

if jarupdate_enabled && [[ -f modules/jarupdate/start.sh ]]; then
  header "Running module: jarupdate"
  modules/jarupdate/start.sh
fi

CLOUDFLARED_STATUS="${CLOUDFLARED_STATUS:-0}"
if is_enabled "$CLOUDFLARED_STATUS" && [[ -f modules/cloudflared/start.sh ]]; then
  header "Running module: cloudflared"
  modules/cloudflared/start.sh
fi

KTOR_STATUS="${KTOR_STATUS:-1}"
if is_enabled "$KTOR_STATUS" && [[ -f modules/ktor/start.sh ]]; then
  header "Running module: ktor"
  exec modules/ktor/start.sh
fi

echo "[Orchestrator] KTOR_STATUS is disabled; nothing to run."
exit 1
