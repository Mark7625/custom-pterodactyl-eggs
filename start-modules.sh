#!/usr/bin/env bash
# Ensure Unix line endings
sed -i 's/\r$//' "$0"
find modules -type f -name "*.sh" -exec sed -i 's/\r$//' {} + 2>/dev/null || true

set -euo pipefail
trap 'echo -e "${RED}[Orchestrator] Error on line $LINENO${NC}"' ERR

shopt -s nullglob

BLUE='\033[0;34m'; BOLD_BLUE='\033[1;34m'
WHITE='\033[0;37m'; GREEN='\033[0;32m'
YELLOW='\033[0;33m'; RED='\033[0;31m'
NC='\033[0m'

header() {
  echo -e " "
  echo -e "\n${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}[Orchestrator] $1${NC}"
}

echo -e "\n${BOLD_BLUE}[Orchestrator] Module orchestration starting...${NC}"

is_enabled() { [[ "$1" =~ ^(true|1)$ ]]; }

LOGCLEANER_STATUS="${LOGCLEANER_STATUS:-false}"
if is_enabled "$LOGCLEANER_STATUS"; then
  header "Running module: logcleaner"
  modules/logcleaner/start.sh
fi

AUTOUPDATE_STATUS="${AUTOUPDATE_STATUS:-true}"
if is_enabled "$AUTOUPDATE_STATUS" && [[ -f "modules/autoupdate/start.sh" ]]; then
  header "Running module: autoupdate"
  modules/autoupdate/start.sh
fi

for module_dir in modules/*/; do
  module_name=$(basename "$module_dir")
  [[ "$module_name" == "autoupdate" || "$module_name" == "logcleaner" || "$module_name" == "nextjs" || "$module_name" == "nginx" ]] && continue
  start_script="${module_dir}start.sh"
  status_var="${module_name^^}_STATUS"
  status="${!status_var:-false}"

  if ! is_enabled "$status"; then
    continue
  fi

  if [[ -x "$start_script" ]]; then
    header "Running module: ${module_name}"
    "$start_script"
  fi
done

NEXTJS_STATUS="${NEXTJS_STATUS:-${REACT_STATUS:-true}}"
if is_enabled "$NEXTJS_STATUS" && [[ -x "modules/nextjs/start.sh" ]]; then
  header "Running module: nextjs"
  modules/nextjs/start.sh
fi

NGINX_STATUS="${NGINX_STATUS:-true}"
if is_enabled "$NGINX_STATUS"; then
  header "Running module: nginx"
  modules/nginx/start.sh
  exit 0
fi

echo -e "\n${GREEN}[Orchestrator] Module orchestration complete.${NC}\n"
