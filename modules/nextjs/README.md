# Next.js Module

Installs dependencies, builds, and starts your Next.js app before Nginx proxies traffic to it.

`npm install` and `next build` run only when:
- Git clone/pull brought in new commits
- `node_modules` or `.next` is missing (first start)
- `CLEAN_NODE_MODULES=1` or `.rebuild_requested` cron flag is set

Plain restarts with no git changes skip install and build for faster startup.

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
