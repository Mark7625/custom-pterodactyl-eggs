#!/usr/bin/env bash
sed -i 's/\r$//' "$0"
find modules -type f -name "*.sh" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

set -euo pipefail

RED='\033[0;31m'; BOLD_BLUE='\033[1;34m'; BLUE='\033[0;34m'; NC='\033[0m'
trap 'echo -e "${RED}[Orchestrator] Error on line $LINENO${NC}"' ERR

header() {
  echo -e "\n${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}[Orchestrator] $1${NC}"
}

if [[ -x scripts/bootstrap-deps.sh ]]; then
  scripts/bootstrap-deps.sh
elif [[ -f scripts/bootstrap-deps.sh ]]; then
  bash scripts/bootstrap-deps.sh
fi

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

if is_enabled "${AUTOUPDATE_STATUS:-1}" && [[ -f modules/autoupdate/start.sh ]]; then
  header "autoupdate"
  modules/autoupdate/start.sh
fi

if jarupdate_enabled && [[ -f modules/jarupdate/start.sh ]]; then
  header "jarupdate"
  modules/jarupdate/start.sh
fi

if [[ -f modules/jar/start.sh ]]; then
  header "jar"
  exec modules/jar/start.sh
fi

echo "[Orchestrator] modules/jar/start.sh missing"
exit 1
