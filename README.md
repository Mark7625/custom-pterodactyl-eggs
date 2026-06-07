# Pterodactyl Ktor / JAR Egg

Runs **Ktor, Spring Boot, or any JAR** from GitHub Releases. Egg infra on branch **`ktor`**.

## Modules

1. **autoupdate** — sync egg scripts from `ktor` branch
2. **jarupdate** — download JAR from GitHub Releases
3. **cloudflared** — optional Cloudflare Tunnel
4. **ktor** — `java -jar` on your allocation port

## Docker Images

```
ghcr.io/mark7625/custom-pterodactyl-eggs/ktor:22-latest
ghcr.io/mark7625/custom-pterodactyl-eggs/ktor:11-latest
```

## OpenRune WebServer

| Variable | Value |
|----------|-------|
| Image | `ktor:11-latest` |
| `JAR_UPDATE_REPO` | `Mark7625/OpenRune-WebServer` |
| `SERVER_JAR` | `openrune-server.jar` |
| `JAR_RELEASE_FILTER` | `diff` (matches `2026-06-07-diff-...` releases) |
| `JAR_UPDATE_TAG` | leave blank for latest `diff`, or `v1.0.0` to pin |
| `APP_PORT_METHOD` | `cli` |
| `APP_ARGS` | `-1 OLDSCHOOL LIVE` |

## Cloudflare Tunnel

`CLOUDFLARED_STATUS=1` + `CLOUDFLARED_TOKEN` → route hostname to `http://localhost:<APP_PORT>`

## Regenerate egg

```bash
python scripts/generate-egg.py
```

MIT License
