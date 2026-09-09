#!/usr/bin/env python3
"""Build install.sh (GitHub fetch + embedded fallback) and sync egg-openrune-game-server.json."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent

SCRIPT_REPO = "Mark7625/custom-pterodactyl-eggs"
SCRIPT_BRANCH = "openrune-game-server"
RAW_BASE = f"https://raw.githubusercontent.com/{SCRIPT_REPO}/{SCRIPT_BRANCH}"

EMBED_FILES = [
    "start.sh",
    "start-modules.sh",
    "modules/autoupdate/start.sh",
    "modules/jarupdate/start.sh",
    "modules/config/start.sh",
    "modules/logcleaner/start.sh",
    "modules/cloudflared/start.sh",
    "autoupdate-files.txt",
]

INSTALL_STUB = """\
#!/bin/ash
# Reinstall via Pterodactyl panel to refresh scripts from the egg or GitHub.
echo "[Install] ${OPENRUNE_BRAND:-OpenRune} Game Server — scripts from Mark7625/custom-pterodactyl-eggs @ openrune-game-server"
exit 0
"""


def shell_paths_list() -> str:
    return " ".join(f'"{p}"' for p in EMBED_FILES)


def build_install_sh() -> str:
    lines = [
        "#!/bin/ash",
        f"# Prefer scripts from {RAW_BASE} (public). Embedded copy is fallback.",
        "# Regenerate: python embed-install.py",
        "",
        'INSTALL_DIR="/mnt/server"',
        f'RAW="{RAW_BASE}"',
        "",
        'cd "${INSTALL_DIR}" 2>/dev/null || {',
        '  echo "[Install] ERROR: cannot cd ${INSTALL_DIR}"',
        "  exit 1",
        "}",
        "",
        "set -e",
        "",
        'mkdir -p modules/autoupdate modules/jarupdate modules/config modules/logcleaner modules/cloudflared',
        "",
        'fetch_file() {',
        '  path="$1"',
        '  mkdir -p "$(dirname "${path}")"',
        '  curl -fsSL --connect-timeout 15 --max-time 120 "${RAW}/${path}" -o "${path}.part"',
        '  mv -f "${path}.part" "${path}"',
        "}",
        "",
        "install_cloudflared() {",
        '  if [ -x cloudflared ]; then',
        "    return 0",
        "  fi",
        '  arch=$(uname -m)',
        '  case "${arch}" in',
        "    x86_64|amd64) cf=amd64 ;;",
        "    aarch64|arm64) cf=arm64 ;;",
        "    *)",
        '      echo "[Install] WARNING: unsupported arch ${arch}; skipping cloudflared"',
        "      return 0",
        "      ;;",
        "  esac",
        '  echo "[Install] GET cloudflared (${cf})"',
        "  if curl -fsSL --connect-timeout 15 --max-time 300 \\",
        '    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cf}" \\',
        "    -o cloudflared.part; then",
        "    mv -f cloudflared.part cloudflared",
        "    chmod +x cloudflared",
        "  else",
        "    rm -f cloudflared.part",
        '    echo "[Install] WARNING: cloudflared download failed; the tunnel module will not start"',
        "  fi",
        "  return 0",
        "}",
        "",
        "try_github_install() {",
        '  if ! command -v curl >/dev/null 2>&1; then',
        "    return 1",
        "  fi",
        f"  for path in {shell_paths_list()}; do",
        '    echo "[Install] GET ${path}"',
        '    fetch_file "${path}" || return 1',
        "  done",
        '  chmod +x start.sh start-modules.sh modules/*/start.sh 2>/dev/null || true',
        '  if fetch_file "install.sh"; then',
        '    chmod +x install.sh',
        "  fi",
        "  return 0",
        "}",
        "",
        'echo "[Install] ${OPENRUNE_BRAND:-OpenRune} Game Server"',
        "",
        'if try_github_install; then',
        '  echo "[Install] Pulled scripts from ${RAW}"',
        "  install_cloudflared",
        '  echo "[Install] done"',
        "  exit 0",
        "fi",
        "",
        'echo "[Install] GitHub fetch failed — installing embedded scripts"',
        "",
    ]

    for rel in EMBED_FILES:
        content = (ROOT / rel).read_text(encoding="utf-8").replace("\r\n", "\n").rstrip("\n")
        lines.append(f'mkdir -p "$(dirname "{rel}")"')
        lines.append(f'cat >"{rel}" <<\'__OPENRUNE_EMBED__\'')
        lines.append(content)
        lines.append("__OPENRUNE_EMBED__")
        if rel.endswith(".sh"):
            lines.append(f'chmod +x "{rel}"')
        lines.append("")

    lines.append('cat >"install.sh" <<\'__OPENRUNE_EMBED__\'')
    lines.append(INSTALL_STUB.rstrip("\n"))
    lines.append("__OPENRUNE_EMBED__")
    lines.append('chmod +x "install.sh"')
    lines.append("")
    lines.append("install_cloudflared")
    lines.append('echo "[Install] done"')
    lines.append("")
    return "\n".join(lines)


def sync_egg(install_sh: str) -> None:
    egg_path = ROOT / "egg-openrune-game-server.json"
    egg = json.loads(egg_path.read_text(encoding="utf-8"))
    egg["scripts"]["installation"]["script"] = install_sh.replace("\n", "\r\n")
    egg_path.write_text(json.dumps(egg, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    install_sh = build_install_sh()
    (ROOT / "install.sh").write_text(install_sh, encoding="utf-8", newline="\n")
    sync_egg(install_sh)
    print(f"Wrote {ROOT / 'install.sh'}")
    print(f"Updated {ROOT / 'egg-openrune-game-server.json'}")


if __name__ == "__main__":
    main()
