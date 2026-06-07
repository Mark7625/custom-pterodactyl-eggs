# Next.js Module

Installs dependencies, builds, and starts your Next.js app before Nginx proxies traffic to it.

## Default flow

1. `npm install`
2. `npx next build`
3. `npx next start` on port 3000
4. Nginx proxies your Pterodactyl port → Next.js

## Configuration

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `NEXTJS_STATUS` | `true` | Enable build & start on startup |
| `INSTALL_COMMAND` | `npm install` | Install dependencies |
| `BUILD_COMMAND` | `npx next build` | Production build |
| `START_COMMAND` | `npx next start` | Run Next.js server (`none` to disable) |
| `SERVE_MODE` | `node` | `node` = SSR/API via Next.js server (recommended) |
| `SERVE_MODE` | `static` | Serve static export only (`output: 'export'`) |
| `APP_PORT` | `3000` | Port Next.js listens on internally |
| `BUILD_OUTPUT_DIR` | `out` | Static export folder (static mode only) |

`REACT_STATUS` is still accepted as a legacy alias for `NEXTJS_STATUS`.
