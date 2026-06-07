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
    "name": "Pterodactyl Basic JAR Egg",
    "author": "egg@openrune.dev",
    "description": (
        "Pterodactyl Basic JAR Egg\r\n\r\n"
        "Update egg scripts, pull JAR from GitHub Releases, run java -jar. Branch: basic-jar."
    ),
    "features": [],
    "docker_images": {
        "Java 21": "ghcr.io/pterodactyl/yolks:java_21",
        "Java 17": "ghcr.io/pterodactyl/yolks:java_17",
        "Java 11": "ghcr.io/pterodactyl/yolks:java_11",
    },
    "file_denylist": [],
    "startup": "bash ./start-modules.sh",
    "config": {
        "files": "{}",
        "startup": '{\r\n    "done": "Services successfully launched"\r\n}',
        "logs": '{\r\n    "location": "logs/jar.log"\r\n}',
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
        var("Enable Script Update", "Pull latest egg scripts from GitHub on startup", "AUTOUPDATE_STATUS", "1", "required|boolean"),
        var("Force Script Update", "Apply script updates without confirmation", "AUTOUPDATE_FORCE", "1", "required|boolean"),
        var("Enable JAR Update", "Download JAR from GitHub Releases on startup", "JAR_UPDATE_STATUS", "1", "required|boolean"),
        var("JAR Update Mode", "Automatic, Notification, or Disabled", "JAR_UPDATE_MODE", "Automatic", "required|string"),
        var("GitHub Repo", "owner/repo or GitHub URL for releases", "JAR_UPDATE_REPO", "", "nullable|string"),
        var("Release Filter", "Match tag/title for latest (e.g. production). Blank = newest", "JAR_RELEASE_FILTER", "", "nullable|string"),
        var("Release Tag", "Pin exact tag. Overrides filter", "JAR_UPDATE_TAG", "", "nullable|string"),
        var("JAR Filename", "Release asset filename", "SERVER_JAR", "app.jar", "required|string"),
        var("GitHub Token", "Optional PAT for private repos / rate limits", "GITHUB_TOKEN", "", "nullable|string"),
        var("App Arguments", "Args after -jar (port auto-appended from allocation if missing)", "APP_ARGS", "", "nullable|string"),
        var("Java Options", "JVM flags", "JAVA_OPTS", "-Xms128M -XX:MaxRAMPercentage=95.0", "required|string"),
        var("Java Startup Override", "Full java command override. Leave blank for auto", "JAVA_STARTUP", "", "nullable|string"),
    ],
}

assert re.match(r"^[^@]+@[^@]+\.[^@]+$", egg["author"])
for key in ("files", "startup", "logs"):
    json.loads(egg["config"][key])
reserved = {"SERVER_MEMORY", "SERVER_IP", "SERVER_PORT", "ENV", "HOME", "USER", "STARTUP", "SERVER_UUID", "UUID"}
for v in egg["variables"]:
    assert re.match(r"^[\w]{1,191}$", v["env_variable"])
    assert v["env_variable"] not in reserved

out = ROOT / "egg-jar-v1.json"
out.write_text(json.dumps(egg, indent=4), encoding="utf-8")
print(f"Generated {out.name}")
