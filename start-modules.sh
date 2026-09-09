#!/usr/bin/env bash
# Runs startup modules before the Java process.
set -euo pipefail

cd /home/container

BLUE='\033[0;34m'
BOLD_BLUE='\033[1;34m'
NC='\033[0m'

header() {
    echo -e "${BLUE}───────────────────────────────────────────────${NC}"
    echo -e "${BOLD_BLUE}[Orchestrator] $1${NC}"
}

enabled() { [[ "${1}" =~ ^(true|1|yes|on)$ ]]; }

serverupdate_enabled() {
    local mode="${OPENRUNE_SERVER_UPDATE:-}"
    if [[ -z "${mode}" ]]; then
        if enabled "${JAR_UPDATE_DISABLE:-0}" || ! enabled "${JAR_UPDATE_STATUS:-1}"; then
            return 1
        fi
        return 0
    fi
    case "${mode,,}" in
        disabled|disable|off|0|false|no) return 1 ;;
        *) return 0 ;;
    esac
}

run_module() {
    local name="$1"
    local script="modules/${name}/start.sh"
    if [[ ! -f "${script}" ]]; then
        echo "[Orchestrator] ERROR: Module '${name}' not found (${script})."
        echo "[Orchestrator] Reinstall the server in Pterodactyl to restore startup scripts."
        exit 1
    fi
    if [[ "${name}" == "jarupdate" ]] && ! serverupdate_enabled; then
        echo "[Orchestrator] Server update disabled (OPENRUNE_SERVER_UPDATE=disabled); skipping jarupdate."
        return 0
    fi
    header "Running module: ${name}"
    if ! bash "${script}"; then
        # The tunnel only fronts the web client; the game itself is reachable without it.
        if [[ "${name}" == "cloudflared" ]]; then
            echo "[Orchestrator] Module 'cloudflared' failed — continuing without the tunnel."
            return 0
        fi
        echo "[Orchestrator] Module '${name}' failed — startup aborted."
        exit 1
    fi
}

MODULE_ORDER="${START_MODULES:-autoupdate jarupdate config logcleaner cloudflared}"
for module in ${MODULE_ORDER}; do
    run_module "${module}"
done

header "Starting ${OPENRUNE_BRAND:-OpenRune} Game Server (Java)"
