# OpenRune Game Server

Pterodactyl egg for the **OpenRune Game Server**. On each start it syncs egg scripts from GitHub, downloads the latest matching release (if enabled), writes `game.yml` from panel variables, and runs `java -jar server.jar`.

Branch: **`openrune-game-server`**  
Scripts: [Mark7625/custom-pterodactyl-eggs](https://github.com/Mark7625/custom-pterodactyl-eggs/tree/openrune-game-server)

## What it does

### Install (Pterodactyl reinstall)

1. Pulls startup scripts from the `openrune-game-server` branch (embedded copy as fallback if GitHub is unreachable).
2. Creates `modules/` (`autoupdate`, `jarupdate`, `config`, `logcleaner`), `start.sh`, and `start-modules.sh`.

### Every server start

Modules run in this order:

| Module | Purpose |
|--------|---------|
| **autoupdate** | Syncs egg scripts from GitHub when the branch has a new commit |
| **jarupdate** | Downloads `server-release.zip` from GitHub Releases, extracts it, installs server files |
| **config** | Writes `/home/container/game.yml` from Pterodactyl Startup variables |
| **logcleaner** | Clears old logs and stale temp files (optional) |

Then `start.sh` launches Java:

```bash
java -jar server.jar
```

### Release download & extract

When **Server update** is enabled, **jarupdate**:

1. Finds the latest GitHub Release on `OpenRune/OpenRune-Server` matching **Build type** (e.g. tag containing `-production-`).
2. Downloads **`server-release.zip`** (or your **Release asset** name).
3. Extracts the zip and installs:
   - `server.jar` → `/home/container/server.jar`
   - `.data/` → cache and server data (requires `.data/cache/SERVER`)
   - `game.yml` from the zip, if present (overwritten on next start by **config** unless you change that flow)
4. Backs up replaced files before updating.

First install always downloads automatically. Later updates follow **Server update** mode: Automatic, Notification, or Disabled.

Private release repos need **GitHub token** (PAT with `repo` read access).

## Configuration

### `game.yml` (generated every start)

The **config** module builds `game.yml` from panel variables. These are **required** before the server will start:

| Panel variable | Env var | Description |
|----------------|---------|-------------|
| Revision | `OPENRUNE_REVISION` | OSRS client revision |
| Environment | `OPENRUNE_ENVIRONMENT` | Cache environment (e.g. `LIVE`) |
| World id | `OPENRUNE_WORLD` | World number |
| Central world key | `OPENRUNE_CENTRAL_WORLD_KEY` | Auth key for central server |
| Central DB password | `OPENRUNE_CENTRAL_DB_PASSWORD` | PostgreSQL password |

Fixed values (edit in `modules/config/start.sh` before pushing):

- Central host, link port, JDBC URL, DB user — currently placeholders (`central.openrune.example`, `db.openrune.example`, user `openrune`).

### Pterodactyl Startup variables

| Variable | Default | Notes |
|----------|---------|-------|
| Server JAR file | `server.jar` | JAR filename in `/home/container` |
| JVM Extra Flags | *(empty)* | Extra JVM args (e.g. `-Xmx4G`) |
| Script update | Automatic | Sync egg scripts: Automatic / Notification / Disabled |
| Server update | Automatic | Release download: Automatic / Notification / Disabled |
| Release repository | `OpenRune/OpenRune-Server` | GitHub repo for release zips |
| Script repository | `Mark7625/custom-pterodactyl-eggs` | Egg scripts repo (not the game server repo) |
| Build type | `production` | Matches release tag suffix |
| Release asset | `server-release.zip` | Zip filename on GitHub Releases |
| GitHub token | *(empty)* | PAT for private releases |
| Enable Logcleaner Module | `1` | Clean logs/tmp on start |

## Docker image

Uses official Pterodactyl Java yolk:

```
ghcr.io/pterodactyl/yolks:java_21
```

## Import

1. Import **`egg-openrune-game-server.json`** into the Pterodactyl panel (Admin → Nests → Import Egg).
2. Create a server with the egg.
3. Set **Revision**, **Environment**, **World id**, **Central world key**, and **Central DB password** in Startup.
4. Start the server — first run downloads the release and generates `game.yml`.

## Develop

After editing scripts in this repo:

```bash
python embed-install.py
```

This regenerates `install.sh` and embeds the latest scripts into `egg-openrune-game-server.json`.

Commit and push to **`openrune-game-server`** so running servers can pull updates via **autoupdate**.
