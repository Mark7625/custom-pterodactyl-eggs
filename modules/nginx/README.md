# Nginx Module

Starts Nginx in the foreground and routes traffic to your Next.js server.

## Modes

| Mode | Nginx behaviour |
|------|-----------------|
| `node` (default) | Reverse proxy to Next.js on `APP_PORT` (SSR, API routes, middleware) |
| `static` | Serves static export files from `/home/container/public` |

Mode is set by the Next.js module via `/home/container/tmp/serve_mode`.

## Configuration

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `NGINX_CONF` | `/home/container/nginx/nginx.conf` | Nginx config path |
| `NGINX_PREFIX` | `/home/container` | Nginx prefix (`-p`) |
| `APP_PORT` | `3000` | Next.js port to proxy to (node mode) |
| `SERVE_ROOT` | `/home/container/public` | Static files root (static mode) |
