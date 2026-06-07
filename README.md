# Pterodactyl Next.js Egg

A Pterodactyl egg for hosting **Next.js** applications. Pulls your site from Git on every restart, runs `next build` + `next start`, and proxies traffic through Nginx for full SSR, API routes, and middleware support. Also includes Cloudflare Tunnel, Certbot SSL, cron jobs, and auto-updates.

<br>

## Table of Contents
- [Features](#features)
- [Installation](#installation)
- [How It Works](#how-it-works)
- [Website Repository](#website-repository)
- [Next.js Commands](#nextjs-commands)
- [Serve Modes](#serve-modes)
- [Auto-Update System](#auto-update-system)
- [SSL Certificate with Certbot](#ssl-certificate-setup-tutorial)
- [Cloudflared Tunnel Tutorial](#-cloudflared-tunnel-tutorial)
- [Cronjob](#cronjob)
- [Docker Images](#docker-images)
- [Notes](#notes)
- [License](#license)

<br>

## Features

- ▲ **Next.js**: `next build` + `next start` on every restart
- 🔀 **Nginx proxy**: Full SSR, API routes, middleware (not just static files)
- 🔄 **Git deploy**: Pull latest from your repo before each build
- 🌐 **Cloudflare Tunnel**: Secure remote access without port forwarding
- 🔐 **Certbot SSL**: DNS-01 challenge support
- 🖥️ **Multi-arch**: AMD64 & ARM64
- 🎯 **Node.js**: 20 LTS and 22 LTS

<br>

## Installation

1. Download `egg-nextjs-v1.json`
2. In Pterodactyl, go to **Nests** → **Import Egg**
3. Create a server with the **Pterodactyl Next.js Egg**
4. Select a Docker image (Node.js 22 or 20)
5. Configure your website repo variables (below)

<br>

## How It Works

On each server start:

1. **Auto-update** — egg infrastructure updates from GitHub
2. **Website deploy** — `git pull` your Next.js repo into `www/`
3. **Next.js module** — `npm install` → `next build` → `next start`
4. **Nginx** — proxies your Pterodactyl port → Next.js on port 3000

<br>

## Website Repository

| Variable | Default | Description |
|----------|---------|-------------|
| `WEBSITE_REPO` | — | Git URL of your Next.js project |
| `WEBSITE_BRANCH` | `main` | Branch to deploy |
| `WEBSITE_TOKEN` | — | PAT for private repos |
| `WEBSITE_USERNAME` | `x-access-token` | Git auth username |
| `GIT_STATUS` | `1` | Pull updates on every restart |

<br>

## Next.js Commands

| Variable | Default | Description |
|----------|---------|-------------|
| `NEXTJS_STATUS` | `1` | Enable build & start on restart |
| `INSTALL_COMMAND` | `npm install` | Install dependencies |
| `BUILD_COMMAND` | `npx next build` | Production build |
| `START_COMMAND` | `npx next start` | Run Next.js server |
| `APP_PORT` | `3000` | Internal port Next.js listens on |

<br>

## Serve Modes

| Mode | When to use |
|------|-------------|
| **`node`** (default) | Normal Next.js — SSR, API routes, middleware. Nginx proxies to `next start`. |
| **`static`** | Next.js static export only. Set `output: 'export'` in `next.config`, use `SERVE_MODE=static` and `START_COMMAND=none`. |

For a standard Next.js app, keep `SERVE_MODE=node`.

<br>

## Auto-Update System

Egg infrastructure (not your website) updates from:

- **Repository**: [Mark7625/custom-pterodactyl-eggs](https://github.com/Mark7625/custom-pterodactyl-eggs)
- **Branch**: `nextjs`

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTOUPDATE_STATUS` | `1` | Check for egg updates |
| `AUTOUPDATE_FORCE` | `1` | Apply updates automatically |

<br>

## SSL Certificate Setup Tutorial

With **Certbot DNS-01**, create SSL certificates without opening ports 80/443.
[Let's Encrypt | Getting Started](https://letsencrypt.org/getting-started/)

1. Set `CERTBOT_STATUS=true`, `CERTBOT_EMAIL`, `CERTBOT_DOMAIN`
2. Restart and follow DNS TXT record instructions in console
3. Copy `nginx/conf.d/default-ssl.conf.example` into `default.conf`
4. Replace `<port>` and `<domain>` placeholders
5. Restart

<br>

## 🚀 Cloudflared Tunnel Tutorial

[Cloudflared docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/)

1. Create a tunnel in Cloudflare Zero Trust
2. Set `CLOUDFLARED_STATUS=1` and paste token into `CLOUDFLARED_TOKEN`
3. Add hostname: **HTTP** → `localhost` + your server port
4. Restart

<br>

## Cronjob

Enable with `CRON_STATUS=1`, edit `/home/container/crontab`:

```bash
0 3 * * * touch /home/container/.rebuild_requested
```

<br>

## Docker Images

```bash
docker build --build-arg NODE_VERSION=22 -t ghcr.io/mark7625/pterodactyl-nextjs-egg:22-latest .
docker build --build-arg NODE_VERSION=20 -t ghcr.io/mark7625/pterodactyl-nextjs-egg:20-latest .
```

<br>

## Notes

- Source: `/home/container/www/`
- Next.js logs: `/home/container/logs/nextjs.log`
- Nginx proxies to Next.js on `APP_PORT` (default 3000)
- `REACT_STATUS` still works as a legacy alias for `NEXTJS_STATUS`

<br>

## License

[MIT License](https://choosealicense.com/licenses/mit/)

Forked and adapted from: https://gitlab.com/tenten8401/pterodactyl-nginx
