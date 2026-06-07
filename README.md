# Pterodactyl Basic JAR Egg

Minimal egg: **update scripts** → **update JAR from GitHub Releases** → **run JAR**.

Branch: **`basic-jar`**

## Modules

1. **autoupdate** — sync egg scripts from GitHub
2. **jarupdate** — download JAR from GitHub Releases
3. **jar** — `java -jar`

## Docker Images

Uses official [Pterodactyl Java yolks](https://github.com/pterodactyl/yolks) (built for game server eggs):

```
ghcr.io/pterodactyl/yolks:java_21
ghcr.io/pterodactyl/yolks:java_17
ghcr.io/pterodactyl/yolks:java_11
```

Do **not** use raw `eclipse-temurin` images — they exit immediately (exit code 0) because they lack the Pterodactyl entrypoint.

## Example (OpenRune WebServer)

| Variable | Value |
|----------|-------|
| Image | `Java 11` |
| `JAR_UPDATE_REPO` | `Mark7625/OpenRune-WebServer` |
| `SERVER_JAR` | `openrune-server.jar` |
| `JAR_RELEASE_FILTER` | `production` |
| `APP_ARGS` | `235 OLDSCHOOL LIVE` |

Port from your Pterodactyl allocation is appended automatically if not in `APP_ARGS`.

## Regenerate egg

```bash
python scripts/generate-egg.py
```

Import `egg-jar-v1.json` into Pterodactyl.

MIT License
