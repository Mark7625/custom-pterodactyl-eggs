#!/usr/bin/env bash
# Cloudflare Tunnel module (token-based). Fronts the web client bridge with HTTPS.

CLOUDFLARED_STATUS="${CLOUDFLARED_STATUS:-0}"
CLOUDFLARED_TOKEN="${CLOUDFLARED_TOKEN:-}"
CLOUDFLARED_LOG_FILE="${CLOUDFLARED_LOG_FILE:-/home/container/logs/cloudflared.log}"
CLOUDFLARED_PID_FILE="${CLOUDFLARED_PID_FILE:-/home/container/tmp/cloudflared.pid}"
CLOUDFLARED_MAX_ATTEMPTS="${CLOUDFLARED_MAX_ATTEMPTS:-130}"
CLOUDFLARED_STATUS_TIMES="${CLOUDFLARED_STATUS_TIMES:-5 10 15 30 60 90 120}"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

enabled() { [[ "${1}" =~ ^(true|1|yes|on)$ ]]; }

if ! enabled "${CLOUDFLARED_STATUS}"; then
    exit 0
fi

echo -e "${YELLOW}[Tunnel] Starting Cloudflared Tunnel${NC}"

if [[ -z "${CLOUDFLARED_TOKEN}" ]]; then
    echo -e "${RED}[Tunnel] CLOUDFLARED_TOKEN is not set; skipping Cloudflared startup.${NC}"
    exit 0
fi

download_cloudflared() {
    local arch cf
    arch="$(uname -m)"
    case "${arch}" in
        x86_64|amd64) cf=amd64 ;;
        aarch64|arm64) cf=arm64 ;;
        *)
            echo -e "${RED}[Tunnel] Unsupported architecture ${arch}; cannot fetch cloudflared.${NC}"
            return 1
            ;;
    esac

    echo -e "${YELLOW}[Tunnel] cloudflared not found; downloading (${cf})...${NC}"
    if curl -fsSL --connect-timeout 15 --max-time 300 \
        "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf}" \
        -o /home/container/cloudflared.part; then
        mv -f /home/container/cloudflared.part /home/container/cloudflared
        chmod +x /home/container/cloudflared
        echo -e "${GREEN}[Tunnel] cloudflared downloaded.${NC}"
        return 0
    fi

    rm -f /home/container/cloudflared.part
    echo -e "${RED}[Tunnel] Download failed; reinstall the server or upload the binary manually.${NC}"
    return 1
}

if [[ -x /home/container/cloudflared ]]; then
    cf_bin="/home/container/cloudflared"
elif command -v cloudflared >/dev/null 2>&1; then
    cf_bin="cloudflared"
elif download_cloudflared; then
    cf_bin="/home/container/cloudflared"
else
    exit 1
fi

mkdir -p "$(dirname "${CLOUDFLARED_LOG_FILE}")" "$(dirname "${CLOUDFLARED_PID_FILE}")"
: >"${CLOUDFLARED_LOG_FILE}"

"${cf_bin}" tunnel --no-autoupdate run --token "${CLOUDFLARED_TOKEN}" \
    >"${CLOUDFLARED_LOG_FILE}" 2>&1 &

pid=$!
echo "${pid}" >"${CLOUDFLARED_PID_FILE}"

read -ra TIMES <<< "${CLOUDFLARED_STATUS_TIMES}"
echo -e "${YELLOW}[Tunnel] Waiting for Cloudflared to establish connection...${NC}"

for ((i = 1; i <= CLOUDFLARED_MAX_ATTEMPTS; i++)); do
    sleep 1
    for t in "${TIMES[@]}"; do
        if [[ $i -eq $t ]]; then
            echo -e "${YELLOW}[Tunnel] Still waiting... (${i}s)${NC}"
        fi
    done

    if ! kill -0 "${pid}" 2>/dev/null; then
        echo -e "${RED}[Tunnel] Cloudflared process died; check logs: ${CLOUDFLARED_LOG_FILE}${NC}"
        tail -n 10 "${CLOUDFLARED_LOG_FILE}" 2>/dev/null || true
        exit 1
    fi

    if grep -qE 'Registered tunnel connection|Updated to new configuration' "${CLOUDFLARED_LOG_FILE}" 2>/dev/null; then
        echo -e "${GREEN}[Tunnel] Connected after ${i}s${NC}"
        echo -e "${GREEN}[Tunnel] Cloudflared is running successfully.${NC}"
        exit 0
    fi
done

echo -e "${RED}[Tunnel] No successful connection within ${CLOUDFLARED_MAX_ATTEMPTS}s; check ${CLOUDFLARED_LOG_FILE}${NC}"
tail -n 10 "${CLOUDFLARED_LOG_FILE}" 2>/dev/null || true
exit 1
