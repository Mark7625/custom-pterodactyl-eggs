#!/usr/bin/env bash
# Write game.yml from Pterodactyl panel variables on every start.
set -euo pipefail

OPENRUNE_REVISION="${OPENRUNE_REVISION:-}"
OPENRUNE_ENVIRONMENT="${OPENRUNE_ENVIRONMENT:-}"
OPENRUNE_WORLD="${OPENRUNE_WORLD:-}"

OPENRUNE_CENTRAL_WORLD_KEY="${OPENRUNE_CENTRAL_WORLD_KEY:-}"
OPENRUNE_CENTRAL_DB_PASSWORD="${OPENRUNE_CENTRAL_DB_PASSWORD:-}"
OPENRUNE_BRAND="${OPENRUNE_BRAND:-OpenRune}"

OPENRUNE_CENTRAL_HOST="${OPENRUNE_CENTRAL_HOST:-}"
OPENRUNE_CENTRAL_LINK_PORT="${OPENRUNE_CENTRAL_LINK_PORT:-9091}"
OPENRUNE_DB_HOST="${OPENRUNE_DB_HOST:-}"
OPENRUNE_DB_PORT="${OPENRUNE_DB_PORT:-5432}"
OPENRUNE_DB_NAME="${OPENRUNE_DB_NAME:-openrune_central}"
OPENRUNE_DB_USER="${OPENRUNE_DB_USER:-openrune}"
OPENRUNE_DB_POOL_SIZE="${OPENRUNE_DB_POOL_SIZE:-10}"
OPENRUNE_DB_JDBC_URL="${OPENRUNE_DB_JDBC_URL:-}"

GAME_NAME="${OPENRUNE_BRAND} Game Server"

CENTRAL_HOST="${OPENRUNE_CENTRAL_HOST}"
CENTRAL_LINK_PORT="${OPENRUNE_CENTRAL_LINK_PORT}"
CENTRAL_DB_USER="${OPENRUNE_DB_USER}"
CENTRAL_POOL_SIZE="${OPENRUNE_DB_POOL_SIZE}"

if [[ -n "${OPENRUNE_DB_JDBC_URL}" ]]; then
    CENTRAL_JDBC_URL="${OPENRUNE_DB_JDBC_URL}"
else
    CENTRAL_JDBC_URL="jdbc:postgresql://${OPENRUNE_DB_HOST}:${OPENRUNE_DB_PORT}/${OPENRUNE_DB_NAME}"
fi

# Fixed values — not exposed in the panel
GAME_PORT="43594"
CENTRAL_SAME_INSTANCE="false"

RED='\033[0;31m'
NC='\033[0m'

is_blank() {
    [[ -z "${1//[[:space:]]/}" ]]
}

require_panel_values() {
    local missing=()

    is_blank "${OPENRUNE_REVISION}" && missing+=("Revision (OPENRUNE_REVISION)")
    is_blank "${OPENRUNE_ENVIRONMENT}" && missing+=("Environment (OPENRUNE_ENVIRONMENT)")
    is_blank "${OPENRUNE_WORLD}" && missing+=("World id (OPENRUNE_WORLD)")
    is_blank "${OPENRUNE_CENTRAL_WORLD_KEY}" && missing+=("Central world key (OPENRUNE_CENTRAL_WORLD_KEY)")
    is_blank "${OPENRUNE_CENTRAL_DB_PASSWORD}" && missing+=("Central DB password (OPENRUNE_CENTRAL_DB_PASSWORD)")
    is_blank "${OPENRUNE_CENTRAL_HOST}" && missing+=("Central host (OPENRUNE_CENTRAL_HOST)")
    if is_blank "${OPENRUNE_DB_JDBC_URL}"; then
        is_blank "${OPENRUNE_DB_HOST}" && missing+=("Database host (OPENRUNE_DB_HOST)")
    fi

    if ((${#missing[@]} == 0)); then
        return 0
    fi

    echo -e "${RED}[Config] Cannot start — required Startup variables are not set:${NC}"
    for item in "${missing[@]}"; do
        echo -e "${RED}  - ${item}${NC}"
    done
    echo "[Config] Set them in the Pterodactyl panel Startup tab, then restart the server."
    exit 1
}

yaml_quote() {
    printf '%s' "$1" | sed "s/'/''/g"
}

echo "[Config] Writing game.yml from panel variables"
require_panel_values

CONFIG_FILE="/home/container/game.yml"
TMP="${CONFIG_FILE}.new"

{
    echo "# Generated on container start from Pterodactyl variables."
    echo "# Game values"
    echo "# You want to edit these to fit your game."
    echo "name: \"$(yaml_quote "${GAME_NAME}")\""
    echo "game-port: ${GAME_PORT}"
    echo "revision: ${OPENRUNE_REVISION}"
    echo "environment: \"$(yaml_quote "${OPENRUNE_ENVIRONMENT}")\""
    echo "world: ${OPENRUNE_WORLD}"
    echo
    echo "central:"
    echo "  same-instance: ${CENTRAL_SAME_INSTANCE}"
    echo "  host: \"$(yaml_quote "${CENTRAL_HOST}")\""
    echo "  link-port: ${CENTRAL_LINK_PORT}"
    echo "  world-key: \"$(yaml_quote "${OPENRUNE_CENTRAL_WORLD_KEY}")\""
    echo "  postgres:"
    echo "    jdbc-url: \"$(yaml_quote "${CENTRAL_JDBC_URL}")\""
    echo "    user: \"$(yaml_quote "${CENTRAL_DB_USER}")\""
    echo "    password: \"$(yaml_quote "${OPENRUNE_CENTRAL_DB_PASSWORD}")\""
    echo "    pool-size: ${CENTRAL_POOL_SIZE}"
} >"${TMP}"

mv -f "${TMP}" "${CONFIG_FILE}"
echo "[Config] Wrote ${CONFIG_FILE}"
