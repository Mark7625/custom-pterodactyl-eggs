# Next.js Module

Installs dependencies, builds, and starts your Next.js app before Nginx proxies traffic to it.

## Configuration

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `NEXTJS_VERSION` | `16` | Target Next.js version |
| `NEXTJS_STATUS` | `true` | Enable build & start on startup |
| `INSTALL_COMMAND` | `npm install` | Install dependencies |
| `BUILD_COMMAND` | `npx next build` | Production build |
| `START_COMMAND` | `npx next start` | Run Next.js server |
| `SERVE_MODE` | `node` | `node` or `static` |
| `APP_PORT` | `3000` | Internal port (Nginx proxies from `SITE_PORT`) |

Set `SITE_PORT` in the panel to your Pterodactyl allocation port.
