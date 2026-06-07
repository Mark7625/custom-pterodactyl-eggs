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
    "name": "Pterodactyl Next.js Egg",
    "author": "mark7625@users.noreply.github.com",
    "description": (
        "Pterodactyl Next.js Egg\r\n\r\n"
        "One Next.js site per server. Supports Next.js 16. Pulls from Git on restart, "
        "runs next build + next start, and proxies through Nginx on your chosen port."
    ),
    "features": None,
    "docker_images": {
        "ghcr.io/mark7625/custom-pterodactyl-eggs/nextjs:16-latest": "ghcr.io/mark7625/custom-pterodactyl-eggs/nextjs:16-latest",
        "ghcr.io/mark7625/custom-pterodactyl-eggs/nextjs:22-latest": "ghcr.io/mark7625/custom-pterodactyl-eggs/nextjs:22-latest",
        "ghcr.io/mark7625/custom-pterodactyl-eggs/nextjs:20-latest": "ghcr.io/mark7625/custom-pterodactyl-eggs/nextjs:20-latest",
    },
    "file_denylist": [],
    "startup": "./start-modules.sh",
    "config": {
        "files": '{\r\n    "nginx/conf.d/default.conf": {\r\n        "parser": "file",\r\n        "find": {\r\n            "    listen": "    listen {{server.build.default.port}};"\r\n        }\r\n    }\r\n}',
        "startup": '{\r\n    "done": "Services successfully launched"\r\n}',
        "logs": '{\r\n    "location": "logs/latest.log"\r\n}',
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
        var("Enable Auto-Update", "Check for egg infrastructure updates on startup", "AUTOUPDATE_STATUS", "1", "required|boolean"),
        var("Force Auto-Update", "Automatically apply egg updates without confirmation", "AUTOUPDATE_FORCE", "1", "required|boolean"),
        var("Next.js Version", "Target Next.js version for your project (default 16). Ensure next is in your package.json.", "NEXTJS_VERSION", "16", "required|string|max:2"),
        var("Node.js Version", "Node.js runtime in the Docker image. Use 22 with 16-latest or 22-latest image. Use 20 with 20-latest image.", "NODE_VERSION", "22", "required|string|max:2"),
        var("Site Port", "Public port Nginx listens on. Set to your Pterodactyl allocation (e.g. 2034). Next.js stays on APP_PORT 3000 internally.", "SITE_PORT", "", "nullable|string"),
        var("Website Repository", "Git URL of your Next.js project", "WEBSITE_REPO", "", "nullable|string"),
        var("Website Branch", "Branch to deploy from your Next.js repo", "WEBSITE_BRANCH", "main", "nullable|string"),
        var("Website Access Token", "Personal Access Token for private repos. Leave blank for public repos.", "WEBSITE_TOKEN", "", "nullable|string"),
        var("Website Git Username", "Git username for private repo auth. Default: x-access-token", "WEBSITE_USERNAME", "x-access-token", "nullable|string"),
        var("Enable Website Deploy", "Pull Next.js repo updates on every restart. 0 = false, 1 = true", "GIT_STATUS", "1", "required|boolean"),
        var("Enable Next.js Build and Start", "Install deps, next build, and next start on restart. 0 = false, 1 = true", "NEXTJS_STATUS", "1", "required|boolean"),
        var("Install Command", "Command to install dependencies before build", "INSTALL_COMMAND", "npm install", "required|string"),
        var("Clean node_modules", "Delete node_modules before install on each restart. 0 = false, 1 = true", "CLEAN_NODE_MODULES", "0", "required|boolean"),
        var("Build Command", "Next.js production build command", "BUILD_COMMAND", "npx next build", "required|string"),
        var("Start Command", "Next.js production start command. Set to none for static export only.", "START_COMMAND", "npx next start", "required|string"),
        var("Serve Mode", "node = Nginx proxies to Next.js. static = serve static export only.", "SERVE_MODE", "node", "required|string"),
        var("Static Export Directory", "Output folder for static export mode only (default: out)", "BUILD_OUTPUT_DIR", "out", "required|string"),
        var("Enable LogCleaner Module", "Run log cleanup on container startup", "LOGCLEANER_STATUS", "1", "required|boolean"),
        var("Enable Cloudflare Tunnel", "Start Cloudflared tunnel on startup", "CLOUDFLARED_STATUS", "0", "required|boolean"),
        var("Cloudflared Tunnel Token", "Cloudflare Tunnel token", "CLOUDFLARED_TOKEN", "", r"nullable|string|regex:/^[A-Za-z0-9_-]+$/"),
        var("Enable Cron Module", "Enable cron job scheduling", "CRON_STATUS", "0", "required|boolean"),
        var("Cron Config File", "Path to crontab configuration file", "CRON_CONFIG_FILE", "/home/container/crontab", "required|string"),
        var("Enable Certbot SSL", "Enable Certbot SSL certificate management. 0 = false, 1 = true", "CERTBOT_STATUS", "0", "required|boolean"),
        var("Certbot Email", "Email for Let's Encrypt notifications", "CERTBOT_EMAIL", "", "nullable|email"),
        var("Certbot Domain", "Primary domain for SSL certificate", "CERTBOT_DOMAIN", "", r"nullable|string|regex:/^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?(?:\.[a-zA-Z]{2,})+$/"),
        var("Certbot Webroot Path", "Document root for webroot validation", "CERTBOT_WEBROOT_PATH", "/home/container/public", "nullable|string"),
        var("Certbot Staging Mode", "Use Let's Encrypt staging server. 0 = Production, 1 = Staging", "CERTBOT_STAGING", "0", "required|boolean"),
        var("Certbot Force Renewal", "Force certificate renewal. 0 = renew when needed, 1 = force", "CERTBOT_FORCE_RENEWAL", "0", "required|boolean"),
    ],
}

# Sanity checks matching Pterodactyl panel validation
assert re.match(r"^[^@]+@[^@]+\.[^@]+$", egg["author"]), "author must be a valid email"
for key in ("files", "startup", "logs"):
    json.loads(egg["config"][key])
reserved = {"SERVER_MEMORY", "SERVER_IP", "SERVER_PORT", "ENV", "HOME", "USER", "STARTUP", "SERVER_UUID", "UUID"}
for v in egg["variables"]:
    assert re.match(r"^[\w]{1,191}$", v["env_variable"])
    assert v["env_variable"] not in reserved

out = ROOT / "egg-nextjs-v1.json"
out.write_text(json.dumps(egg, indent=4), encoding="utf-8")
print(f"Generated {out.name}")
