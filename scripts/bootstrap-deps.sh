#!/usr/bin/env bash
# Install tools missing from slim Java images (git/curl/python3 for autoupdate + jarupdate).

need_install=0
for cmd in git curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || need_install=1
done
[[ "$need_install" -eq 0 ]] && exit 0

if ! command -v apt-get >/dev/null 2>&1; then
  echo "[Bootstrap] git, curl, or python3 missing and apt-get unavailable."
  exit 1
fi

echo "[Bootstrap] Installing git, curl, python3..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl python3 ca-certificates
rm -rf /var/lib/apt/lists/*
