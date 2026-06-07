#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "${YELLOW}[Startup] Error on line $LINENO${NC}"' ERR

RED='\033[0;31m'
BLUE='\033[0;34m'; BOLD_BLUE='\033[1;34m'
WHITE='\033[0;37m'; GREEN='\033[0;32m'
YELLOW='\033[0;33m'; NC='\033[0m'

header() {
  echo -e "${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}$1${NC}"
}

NGINX_CONF="${NGINX_CONF:-/home/container/nginx/nginx.conf}"
NGINX_PREFIX="${NGINX_PREFIX:-/home/container}"
NGINX_SITE_CONF="${NGINX_PREFIX}/nginx/conf.d/default.conf"
SERVE_MODE_FILE="/home/container/tmp/serve_mode"
APP_PORT="${APP_PORT:-3000}"
SERVE_ROOT="${SERVE_ROOT:-/home/container/public}"

apply_node_config() {
  local listen_port="${1:-80}"
  cat > "$NGINX_SITE_CONF" <<EOF
server {
    listen ${listen_port};
    server_name "";

    set_real_ip_from 127.0.0.1;
    set_real_ip_from 172.18.0.0/16;
    real_ip_header CF-Connecting-IP;
    real_ip_recursive on;

    client_max_body_size 100m;
    client_body_timeout 120s;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
}

apply_static_config() {
  local listen_port="${1:-80}"
  if [[ ! -d "$SERVE_ROOT" ]]; then
    echo -e "${YELLOW}[Startup] Serve root ${SERVE_ROOT} not found; falling back to /home/container/www${NC}"
    SERVE_ROOT="/home/container/www"
  fi

  cat > "$NGINX_SITE_CONF" <<EOF
server {
    listen ${listen_port};
    server_name "";

    set_real_ip_from 127.0.0.1;
    set_real_ip_from 172.18.0.0/16;
    real_ip_header CF-Connecting-IP;
    real_ip_recursive on;

    root ${SERVE_ROOT};
    index index.html;
    charset utf-8;

    absolute_redirect off;
    port_in_redirect off;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;
}
EOF
}

listen_port="80"
if [[ -f "$NGINX_SITE_CONF" ]]; then
  current_listen=$(grep -E '^\s*listen\s+' "$NGINX_SITE_CONF" | head -1 | awk '{print $2}' | tr -d ';')
  if [[ -n "$current_listen" ]]; then
    listen_port="$current_listen"
  fi
fi

serve_mode="node"
if [[ -f "$SERVE_MODE_FILE" ]]; then
  serve_mode=$(tr -d '\n\r' < "$SERVE_MODE_FILE")
fi

header "[Startup] Starting Nginx"
if [[ "$serve_mode" == "static" ]]; then
  apply_static_config "$listen_port"
  echo -e "${WHITE}[Startup] Mode: static export from ${SERVE_ROOT}${NC}"
else
  apply_node_config "$listen_port"
  echo -e "${WHITE}[Startup] Mode: proxying to Next.js on 127.0.0.1:${APP_PORT}${NC}"
fi

echo -e "${GREEN}[Startup] Services successfully launched!${NC}"
sleep 1

nginx -c "$NGINX_CONF" -p "$NGINX_PREFIX" -e /dev/stderr
