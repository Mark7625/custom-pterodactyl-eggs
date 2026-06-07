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
- 🎯 **Next.js 16** with Node.js 20 LTS and 22 LTS

<br>

## Installation

1. Download `egg-nextjs-v1.json`
2. In Pterodactyl, go to **Nests** → **Import Egg**
3. Create a server with the **Pterodactyl Next.js Egg**
4. Select a Docker image (`16-latest` for Next.js 16, or Node 22 / 20)
5. Configure your website repo variables (below)

<br>

## How It Works

On each server start:

1. **Auto-update** — egg infrastructure updates from GitHub
2. **Website deploy** — `git pull` your Next.js repo into `www/`
3. **Next.js module** — `npm install` → `next build` → `next start`
4. **Nginx** — proxies your Pterodactyl port → Next.js on port 3000

<br>

## Website Repository (Site 1)

| Variable | Default | Description |
|----------|---------|-------------|
| `WEBSITE_REPO` | — | Git URL of your Next.js project |
| `WEBSITE_BRANCH` | `main` | Branch to deploy |
| `WEBSITE_TOKEN` | — | PAT for private repos |
| `WEBSITE_USERNAME` | `x-access-token` | Git auth username |
| `GIT_STATUS` | `1` | Pull updates on every restart |

<br>

## Site Port

| Variable | Description |
|----------|-------------|
| `SITE_PORT` | Port your site runs on — set to your **Pterodactyl allocation port** (e.g. `25565`) |

Nginx listens on `SITE_PORT` and proxies to Next.js internally. For Cloudflare Tunnel, point to `localhost:<SITE_PORT>`.

One site per server — create separate Pterodactyl servers for additional sites, each with its own port.

<br>

## Next.js Commands

| Variable | Default | Description |
|----------|---------|-------------|
| `NEXTJS_VERSION` | `16` | Target Next.js version (ensure `next` is in your `package.json`) |
| `NEXTJS_STATUS` | `1` | Enable build & start on restart |
| `INSTALL_COMMAND` | `npm install` | Install dependencies |
| `BUILD_COMMAND` | `npx next build` | Production build |
| `START_COMMAND` | `npx next start` | Run Next.js server |

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

Images are published to GHCR when you push to the `nextjs` branch (see `.github/workflows/docker-publish.yml`).

| Tag | Node.js | Use for |
|-----|---------|---------|
| `16-latest` | 22 | **Recommended** — Next.js 16 |
| `22-latest` | 22 | Node 22 runtime |
| `20-latest` | 20 | Node 20 LTS |

```
ghcr.io/mark7625/custom-pterodactyl-eggs:16-latest
ghcr.io/mark7625/pterodactyl-nextjs-egg:16-latest   # alias (same image)
```

Both names point to the same image. Use **`16-latest`** for Next.js 16.

### If you see `error from registry: denied`

Wings cannot start until the image exists on a registry it can reach.

1. **Publish via GitHub Actions** — push this repo to `Mark7625/custom-pterodactyl-eggs` on branch `nextjs`, then open **Actions** → **Publish Docker images** and confirm the run succeeded.
2. **Make the package public** — on GitHub go to your profile → **Packages** → `custom-pterodactyl-eggs` → **Package settings** → **Change visibility** → Public. (Private packages require a GHCR token on each Wings node.)
3. **Re-import the egg** — use `egg-nextjs-v1.json` so Docker image names match GHCR.
4. **Manual publish** (if CI is not set up yet):

```bash
echo YOUR_GITHUB_PAT | docker login ghcr.io -u Mark7625 --password-stdin

docker build --build-arg NODE_VERSION=22 --build-arg NEXTJS_VERSION=16 -t ghcr.io/mark7625/custom-pterodactyl-eggs:16-latest .
docker push ghcr.io/mark7625/custom-pterodactyl-eggs:16-latest

docker build --build-arg NODE_VERSION=22 -t ghcr.io/mark7625/custom-pterodactyl-eggs:22-latest .
docker push ghcr.io/mark7625/custom-pterodactyl-eggs:22-latest

docker build --build-arg NODE_VERSION=20 -t ghcr.io/mark7625/custom-pterodactyl-eggs:20-latest .
docker push ghcr.io/mark7625/custom-pterodactyl-eggs:20-latest
```

After images are public, in the panel set the server Docker image to **`16-latest`** (not `22-latest` unless you specifically want that tag).

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
