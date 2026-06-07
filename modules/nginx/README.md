# Nginx Module

Starts Nginx and routes traffic to your Next.js app on `SITE_PORT`.

## Configuration

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `SITE_PORT` | from nginx config | Port Nginx listens on — set to your Pterodactyl allocation |
| `APP_PORT` | `3000` | Internal Next.js port (fixed, not user-facing) |
| `NGINX_CONF` | `/home/container/nginx/nginx.conf` | Nginx config path |

Traffic: `SITE_PORT` (Nginx) → `APP_PORT` (Next.js)
