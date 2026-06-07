import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
script = (ROOT / "scripts" / "install-script.sh").read_text(encoding="utf-8")

egg = {
    "_comment": "DO NOT EDIT: FILE GENERATED AUTOMATICALLY BY PTERODACTYL PANEL - PTERODACTYL.IO",
    "meta": {"version": "PTDL_v2", "update_url": None},
    "exported_at": "2026-06-07T00:00:00+00:00",
    "name": "Pterodactyl Next.js Egg",
    "author": "Mark7625",
    "description": (
        "Pterodactyl Next.js Egg\r\n\r\n"
        "Deploy Next.js apps on Pterodactyl. Pulls your site from Git on every restart, "
        "runs next build + next start, and proxies traffic through Nginx. Supports SSR, "
        "API routes, and middleware. Includes Cloudflare Tunnel, Certbot SSL, cron jobs, "
        "and egg auto-updates.\r\n\r\n"
        "Key Features:\r\n\r\n"
        "\u2705 Next.js build & start (next build / next start)\r\n"
        "\u2705 Nginx reverse proxy for SSR and API routes\r\n"
        "\u2705 Website repo, branch, and token configuration\r\n"
        "\u2705 Git pull on restart\r\n"
        "\u2705 Cloudflare Tunnel + Certbot SSL\r\n"
        "\u2705 Optional static export mode"
    ),
    "features": None,
    "docker_images": {
        "ghcr.io/mark7625/pterodactyl-nextjs-egg:22-latest": "Node.js 22 LTS",
        "ghcr.io/mark7625/pterodactyl-nextjs-egg:20-latest": "Node.js 20 LTS",
    },
    "file_denylist": [],
    "startup": "./start-modules.sh",
    "config": {
        "files": '{\r\n    "nginx/conf.d/default.conf": {\r\n        "parser": "file",\r\n        "find": {\r\n            "    listen": "    listen {{server.build.default.port}};"\r\n        }\r\n    }\r\n}',
        "startup": '{\r\n    "done": "Services successfully launched"\r\n}',
        "logs": '{\r\n    "location": "logs/latest.log"\r\n}',
        "stop": "^C & ^C",
    },
    "scripts": {
        "installation": {
            "script": script.replace("\n", "\r\n"),
            "container": "debian:bookworm-slim",
            "entrypoint": "bash",
        }
    },
    "variables": [
        {"name": "Enable Auto-Update", "description": "Check for egg infrastructure updates on startup", "env_variable": "AUTOUPDATE_STATUS", "default_value": "1", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
        {"name": "Force Auto-Update", "description": "Automatically apply egg updates without confirmation", "env_variable": "AUTOUPDATE_FORCE", "default_value": "1", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
        {"name": "Node.js Version", "description": "Node.js version matching your Docker image (22 or 20)", "env_variable": "NODE_VERSION", "default_value": "22", "user_viewable": True, "user_editable": True, "rules": "required|string|max:2", "field_type": "text"},
        {"name": "Website Repository", "description": "Git URL of your Next.js project\r\nI.E. https://github.com/user/my-nextjs-site", "env_variable": "WEBSITE_REPO", "default_value": "", "user_viewable": True, "user_editable": True, "rules": "nullable|string", "field_type": "text"},
        {"name": "Website Branch", "description": "Branch to deploy from your Next.js repo", "env_variable": "WEBSITE_BRANCH", "default_value": "main", "user_viewable": True, "user_editable": True, "rules": "nullable|string", "field_type": "text"},
        {"name": "Website Access Token", "description": "Personal Access Token for private repos.\r\nLeave blank for public repositories.", "env_variable": "WEBSITE_TOKEN", "default_value": "", "user_viewable": True, "user_editable": True, "rules": "nullable|string", "field_type": "text"},
        {"name": "Website Git Username", "description": "Git username for private repo auth.\r\nDefault: x-access-token (GitHub PATs)", "env_variable": "WEBSITE_USERNAME", "default_value": "x-access-token", "user_viewable": True, "user_editable": True, "rules": "nullable|string", "field_type": "text"},
        {"name": "Enable Website Deploy", "description": "Pull Next.js repo updates on every restart.\r\n0 = false\r\n1 = true (default)", "env_variable": "GIT_STATUS", "default_value": "1", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
        {"name": "Enable Next.js Build & Start", "description": "Install deps, next build, and next start on every restart.\r\n0 = false\r\n1 = true (default)", "env_variable": "NEXTJS_STATUS", "default_value": "1", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
        {"name": "Install Command", "description": "Command to install dependencies before build", "env_variable": "INSTALL_COMMAND", "default_value": "npm install", "user_viewable": True, "user_editable": True, "rules": "required|string", "field_type": "text"},
        {"name": "Build Command", "description": "Next.js production build command", "env_variable": "BUILD_COMMAND", "default_value": "npx next build", "user_viewable": True, "user_editable": True, "rules": "required|string", "field_type": "text"},
        {"name": "Start Command", "description": "Next.js production start command.\r\nSet to none for static export only.", "env_variable": "START_COMMAND", "default_value": "npx next start", "user_viewable": True, "user_editable": True, "rules": "required|string", "field_type": "text"},
        {"name": "Serve Mode", "description": "How to serve the built Next.js app.\r\nnode = Nginx proxies to Next.js server (SSR/API — recommended)\r\nstatic = serve static export files only (requires output: export)", "env_variable": "SERVE_MODE", "default_value": "node", "user_viewable": True, "user_editable": True, "rules": "required|string|in:node,static", "field_type": "text"},
        {"name": "Next.js Port", "description": "Internal port Next.js listens on (default 3000).\r\nNginx proxies your server port to this.", "env_variable": "APP_PORT", "default_value": "3000", "user_viewable": True, "user_editable": True, "rules": "required|string", "field_type": "text"},
        {"name": "Static Export Directory", "description": "Output folder for static export mode only.\r\nDefault: out (Next.js static export)", "env_variable": "BUILD_OUTPUT_DIR", "default_value": "out", "user_viewable": True, "user_editable": True, "rules": "required|string", "field_type": "text"},
        {"name": "Enable LogCleaner Module", "description": "Run log cleanup on container startup", "env_variable": "LOGCLEANER_STATUS", "default_value": "1", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
        {"name": "Enable Cloudflare Tunnel", "description": "Start Cloudflared tunnel on startup", "env_variable": "CLOUDFLARED_STATUS", "default_value": "0", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
        {"name": "Cloudflared Tunnel Token", "description": "Cloudflare Tunnel token", "env_variable": "CLOUDFLARED_TOKEN", "default_value": "", "user_viewable": True, "user_editable": True, "rules": "nullable|string|regex:/^[A-Za-z0-9_-]+$/", "field_type": "text"},
        {"name": "Enable Cron Module", "description": "Enable cron job scheduling", "env_variable": "CRON_STATUS", "default_value": "0", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
        {"name": "Cron Config File", "description": "Path to crontab configuration file", "env_variable": "CRON_CONFIG_FILE", "default_value": "/home/container/crontab", "user_viewable": True, "user_editable": True, "rules": "required|string", "field_type": "text"},
        {"name": "Enable Certbot SSL", "description": "Enable Certbot SSL certificate management\r\n0 = false\r\n1 = true", "env_variable": "CERTBOT_STATUS", "default_value": "0", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
        {"name": "Certbot Email", "description": "Email for Let's Encrypt notifications", "env_variable": "CERTBOT_EMAIL", "default_value": "", "user_viewable": True, "user_editable": True, "rules": "nullable|email", "field_type": "text"},
        {"name": "Certbot Domain", "description": "Primary domain for SSL certificate", "env_variable": "CERTBOT_DOMAIN", "default_value": "", "user_viewable": True, "user_editable": True, "rules": "nullable|string|regex:/^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?(?:\\.[a-zA-Z]{2,})+$/", "field_type": "text"},
        {"name": "Certbot Webroot Path", "description": "Document root for webroot validation", "env_variable": "CERTBOT_WEBROOT_PATH", "default_value": "/home/container/public", "user_viewable": True, "user_editable": True, "rules": "nullable|string", "field_type": "text"},
        {"name": "Certbot Staging Mode", "description": "Use Let's Encrypt staging server\r\n0 = Production\r\n1 = Staging", "env_variable": "CERTBOT_STAGING", "default_value": "0", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
        {"name": "Certbot Force Renewal", "description": "Force certificate renewal\r\n0 = renew when needed\r\n1 = force renewal", "env_variable": "CERTBOT_FORCE_RENEWAL", "default_value": "0", "user_viewable": True, "user_editable": True, "rules": "required|boolean", "field_type": "text"},
    ],
}

(ROOT / "egg-nextjs-v1.json").write_text(json.dumps(egg, indent=4), encoding="utf-8")
print("Generated egg-nextjs-v1.json")
