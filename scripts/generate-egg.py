import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
script = (ROOT / "scripts" / "install-script.sh").read_text(encoding="utf-8")


def var(name, description, env_variable, default_value="", rules="nullable|string", viewable=True, editable=True):
    return {
        "name": name,
        "description": description,
        "env_variable": env_variable,
        "default_value": default_value,
        "user_viewable": viewable,
        "user_editable": editable,
        "rules": rules,
        "field_type": "text",
    }


egg = {
    "_comment": "DO NOT EDIT: FILE GENERATED AUTOMATICALLY BY PTERODACTYL PANEL - PTERODACTYL.IO",
    "meta": {"version": "PTDL_v2", "update_url": None},
    "exported_at": "2026-06-07T00:00:00+00:00",
    "name": "Pterodactyl Ktor / JAR Egg",
    "author": "mark7625@users.noreply.github.com",
    "description": (
        "Pterodactyl Ktor / JAR Egg\r\n\r\n"
        "Runs pre-built JARs from GitHub Releases with Java 11 or 22. "
        "Egg autoupdate, JAR updates, and optional Cloudflare Tunnel. Branch: ktor."
    ),
    "features": None,
    "docker_images": {
        "ghcr.io/mark7625/custom-pterodactyl-eggs/ktor:22-latest": "ghcr.io/mark7625/custom-pterodactyl-eggs/ktor:22-latest",
        "ghcr.io/mark7625/custom-pterodactyl-eggs/ktor:11-latest": "ghcr.io/mark7625/custom-pterodactyl-eggs/ktor:11-latest",
    },
    "file_denylist": [],
    "startup": "./start-modules.sh",
    "config": {
        "files": "{}",
        "startup": '{\r\n    "done": "Services successfully launched"\r\n}',
        "logs": '{\r\n    "location": "logs/ktor.log"\r\n}',
        "stop": "^C",
    },
    "scripts": {
        "installation": {
            "script": script.replace("\n", "\r\n"),
            "container": "debian:bookworm-slim",
            "entrypoint": "bash",
        }
    },
    "variables": [
        var("Enable Auto-Update", "Update egg scripts from GitHub branch ktor on startup", "AUTOUPDATE_STATUS", "1", "required|boolean"),
        var("Force Auto-Update", "Apply egg script updates without confirmation", "AUTOUPDATE_FORCE", "1", "required|boolean"),
        var("Enable JAR Update", "Download JAR from GitHub Releases on startup", "JAR_UPDATE_STATUS", "1", "required|boolean"),
        var("JAR Update Mode", "Automatic, Notification, or Disabled", "JAR_UPDATE_MODE", "Automatic", "required|string"),
        var("GitHub Repo", "owner/repo or GitHub URL (e.g. Mark7625/OpenRune-WebServer)", "JAR_UPDATE_REPO", "", "nullable|string"),
        var("Release Filter", "Match text in release tag or title for latest (e.g. diff, production). Blank = newest release", "JAR_RELEASE_FILTER", "", "nullable|string"),
        var("Release Tag", "Pin exact tag (e.g. v1.0.0 or 2026-06-07-diff-abc1234). Overrides filter", "JAR_UPDATE_TAG", "", "nullable|string"),
        var("JAR Filename", "Release asset filename (e.g. openrune-server.jar)", "SERVER_JAR", "app.jar", "required|string"),
        var("GitHub Token", "Optional PAT for API rate limits / private repos", "GITHUB_TOKEN", "", "nullable|string"),
        var("Include Prereleases", "Use newest prerelease when no tag pinned", "JAR_UPDATE_INCLUDE_PRERELEASE", "0", "required|boolean"),
        var("App Port", "Port the JAR listens on. Defaults to Pterodactyl allocation (SERVER_PORT)", "APP_PORT", "", "nullable|string|max:5"),
        var("App Port Method", "property = -Dktor.deployment.port, cli = append port as JAR arg", "APP_PORT_METHOD", "property", "required|string"),
        var("App Arguments", "Args after -jar (e.g. -1 OLDSCHOOL LIVE for OpenRune WebServer)", "APP_ARGS", "", "nullable|string"),
        var("Java Options", "JVM flags", "JAVA_OPTS", "-Xms128M -XX:MaxRAMPercentage=95.0", "required|string"),
        var("Extra JVM Flags", "Additional JVM flags", "JVM_EXTRA_FLAGS", "", "nullable|string"),
        var("Java Startup Override", "Full java command override. Leave blank for auto", "JAVA_STARTUP", "", "nullable|string"),
        var("Enable Ktor Module", "Start the JAR", "KTOR_STATUS", "1", "required|boolean"),
        var("Enable Cloudflare Tunnel", "Cloudflared tunnel for HTTPS / split ingress", "CLOUDFLARED_STATUS", "0", "required|boolean"),
        var("Cloudflare Tunnel Token", "Tunnel token from Cloudflare Zero Trust", "CLOUDFLARED_TOKEN", "", r"nullable|string|regex:/^[A-Za-z0-9_-]+$/"),
    ],
}

assert re.match(r"^[^@]+@[^@]+\.[^@]+$", egg["author"])
for key in ("files", "startup", "logs"):
    json.loads(egg["config"][key])
reserved = {"SERVER_MEMORY", "SERVER_IP", "SERVER_PORT", "ENV", "HOME", "USER", "STARTUP", "SERVER_UUID", "UUID"}
for v in egg["variables"]:
    assert re.match(r"^[\w]{1,191}$", v["env_variable"])
    assert v["env_variable"] not in reserved

out = ROOT / "egg-ktor-v1.json"
out.write_text(json.dumps(egg, indent=4), encoding="utf-8")
print(f"Generated {out.name}")
