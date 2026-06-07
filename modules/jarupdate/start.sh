#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "${RED}[JarUpdate] Error on line $LINENO${NC}"' ERR

BLUE='\033[0;34m'; BOLD_BLUE='\033[1;34m'
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'

header() {
  echo -e "${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}[JarUpdate] $1${NC}"
}

enabled() { [[ "$1" =~ ^(true|1|yes|on)$ ]]; }

JAR_UPDATE_STATUS="${JAR_UPDATE_STATUS:-1}"
JAR_UPDATE_MODE="${JAR_UPDATE_MODE:-Automatic}"
JAR_UPDATE_REPO="${JAR_UPDATE_REPO:-}"
JAR_UPDATE_TAG="${JAR_UPDATE_TAG:-}"
JAR_RELEASE_FILTER="${JAR_RELEASE_FILTER:-}"
JAR_UPDATE_INCLUDE_PRERELEASE="${JAR_UPDATE_INCLUDE_PRERELEASE:-0}"
JAR_UPDATE_PROMPT_SEC="${JAR_UPDATE_PROMPT_SEC:-60}"
JAR_UPDATE_DEBUG="${JAR_UPDATE_DEBUG:-0}"
SERVER_JAR="${SERVER_JAR:-app.jar}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

CONTAINER_ROOT="/home/container"
JAR_PATH="${CONTAINER_ROOT}/${SERVER_JAR}"
STATE_FILE="${CONTAINER_ROOT}/.jarupdate_release"

resolve_update_mode() {
  if ! enabled "$JAR_UPDATE_STATUS"; then
    echo "disabled"
    return
  fi
  case "$(echo "${JAR_UPDATE_MODE}" | tr '[:upper:]' '[:lower:]')" in
    disabled|disable|off|0|false|no) echo "disabled" ;;
    automatic|auto|1|true|yes|on) echo "automatic" ;;
    notification|notify|prompt|ask) echo "notification" ;;
    *) echo "automatic" ;;
  esac
}

github_curl() {
  local url="$1"
  local -a args=(
    -fsSL --max-time 45
    -H "Accept: application/vnd.github+json"
    -H "User-Agent: Pterodactyl-Ktor-JarUpdate"
  )
  [[ -n "$GITHUB_TOKEN" ]] && args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  curl "${args[@]}" "$url" 2>/dev/null
}

find_matching_release() {
  local releases_json="$1"
  local filter_text="$2"
  local asset_name="$3"

  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}[JarUpdate] python3 required for release filtering.${NC}"
    return 1
  fi

  printf '%s' "$releases_json" | python3 -c "
import json, sys

filter_text = (sys.argv[1] or '').strip().lower()
asset_name = sys.argv[2]
include_prerelease = sys.argv[3] == '1'
releases = json.load(sys.stdin)
if not isinstance(releases, list):
    releases = [releases]

def release_matches(release):
    if not filter_text:
        return True
    tag = (release.get('tag_name') or '').lower()
    name = (release.get('name') or '').lower()
    if filter_text in tag or filter_text in name:
        return True
    if f'-{filter_text}-' in tag or tag.endswith(f'-{filter_text}'):
        return True
    return False

best = None
for release in releases:
    if release.get('draft'):
        continue
    if release.get('prerelease') and not include_prerelease:
        continue
    if not release_matches(release):
        continue
    for asset in release.get('assets', []):
        if asset.get('name') != asset_name:
            continue
        published = release.get('published_at') or release.get('created_at') or ''
        release_id = release.get('id') or 0
        download_url = asset.get('browser_download_url') or asset.get('url') or ''
        candidate = (published, release_id, release.get('tag_name', ''), download_url, release.get('name', ''))
        if best is None or candidate[:2] > best[:2]:
            best = candidate
        break

if best is None:
    sys.exit(1)

print(best[2])
print(best[3])
print(best[4])
" "$filter_text" "$asset_name" "$JAR_UPDATE_INCLUDE_PRERELEASE"
}

list_matching_releases() {
  local releases_json="$1"
  local filter_text="$2"
  printf '%s' "$releases_json" | python3 -c "
import json, sys
filter_text = (sys.argv[1] or '').strip().lower()
releases = json.load(sys.stdin)
for r in releases:
    tag = (r.get('tag_name') or '')
    name = (r.get('name') or '')
    if not filter_text or filter_text in tag.lower() or filter_text in name.lower():
        print(f\"  - {tag} | {name}\")
" "$filter_text" 2>/dev/null || true
}

get_local_tag() {
  [[ -f "$STATE_FILE" && -s "$STATE_FILE" ]] && tr -d '\n\r' <"$STATE_FILE" | head -1
}

is_first_load() {
  [[ ! -f "$JAR_PATH" || ! -s "$JAR_PATH" || ! -f "$STATE_FILE" || ! -s "$STATE_FILE" ]]
}

prompt_user_yes_no() {
  local message="$1"
  [[ ! -e /dev/tty ]] && return 1
  echo -e "${YELLOW}${message}${NC}" >/dev/tty
  echo -e "${CYAN}[JarUpdate] Reply y/yes within ${JAR_UPDATE_PROMPT_SEC}s.${NC}" >/dev/tty
  local answer=""
  read -r -t "$JAR_UPDATE_PROMPT_SEC" answer </dev/tty || return 1
  case "$(echo "$answer" | tr '[:upper:]' '[:lower:]')" in y|yes) return 0 ;; *) return 1 ;; esac
}

download_jar() {
  local url="$1"
  local tag="$2"
  local tmp="${JAR_PATH}.download"
  echo -e "${CYAN}[JarUpdate] Downloading ${SERVER_JAR} (${tag})...${NC}"
  if ! curl -fsSL --max-time 300 -o "$tmp" "$url"; then
    echo -e "${RED}[JarUpdate] Download failed.${NC}"
    rm -f "$tmp"
    return 1
  fi
  [[ -s "$tmp" ]] || { echo -e "${RED}[JarUpdate] Downloaded file is empty.${NC}"; rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$JAR_PATH"
  printf '%s\n' "$tag" >"$STATE_FILE"
  echo -e "${GREEN}[JarUpdate] Installed ${SERVER_JAR} @ ${tag}${NC}"
}

UPDATE_MODE=$(resolve_update_mode)

if [[ "$UPDATE_MODE" == "disabled" ]]; then
  echo -e "${CYAN}[JarUpdate] Disabled. Manage ${SERVER_JAR} manually.${NC}"
  [[ -f "$JAR_PATH" ]] || { echo -e "${RED}[JarUpdate] No JAR at ${SERVER_JAR}.${NC}"; exit 1; }
  exit 0
fi

if [[ -z "$JAR_UPDATE_REPO" ]]; then
  echo -e "${YELLOW}[JarUpdate] JAR_UPDATE_REPO not set; using existing JAR.${NC}"
  [[ -f "$JAR_PATH" ]] || { echo -e "${RED}[JarUpdate] No JAR. Set JAR_UPDATE_REPO or upload ${SERVER_JAR}.${NC}"; exit 1; }
  exit 0
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
  echo -e "${YELLOW}[JarUpdate] curl and python3 required; skipping.${NC}"
  exit 0
fi

header "Checking GitHub Releases"

remote_tag=""
download_url=""
release_name=""

if [[ -n "$JAR_UPDATE_TAG" ]]; then
  echo -e "${CYAN}[JarUpdate] Pinned tag: ${JAR_UPDATE_TAG}${NC}"
  release_json=$(github_curl "https://api.github.com/repos/${JAR_UPDATE_REPO}/releases/tags/${JAR_UPDATE_TAG}") || release_json=""
  if [[ -n "$release_json" ]]; then
    parsed=$(printf '%s' "$release_json" | python3 -c "
import json, sys
asset = sys.argv[1]
data = json.load(sys.stdin)
for a in data.get('assets', []):
    if a.get('name') == asset:
        print(data.get('tag_name', ''))
        print(a.get('browser_download_url', ''))
        print(data.get('name', ''))
        sys.exit(0)
sys.exit(1)
" "$SERVER_JAR" 2>/dev/null) || parsed=""
    remote_tag=$(echo "$parsed" | sed -n '1p')
    download_url=$(echo "$parsed" | sed -n '2p')
    release_name=$(echo "$parsed" | sed -n '3p')
  fi
else
  releases_json=$(github_curl "https://api.github.com/repos/${JAR_UPDATE_REPO}/releases?per_page=30") || releases_json=""
  if enabled "$JAR_UPDATE_DEBUG"; then
    echo -e "${CYAN}[JarUpdate] Filter: ${JAR_RELEASE_FILTER:-<none>}${NC}"
    echo -e "${CYAN}[JarUpdate] Releases API response (${#releases_json} bytes)${NC}"
  fi
  if [[ -n "$releases_json" && "$releases_json" != "[]" ]]; then
    parsed=$(find_matching_release "$releases_json" "$JAR_RELEASE_FILTER" "$SERVER_JAR") || parsed=""
    remote_tag=$(echo "$parsed" | sed -n '1p')
    download_url=$(echo "$parsed" | sed -n '2p')
    release_name=$(echo "$parsed" | sed -n '3p')
  fi
fi

if [[ -z "$remote_tag" || -z "$download_url" ]]; then
  echo -e "${YELLOW}[JarUpdate] No matching release found.${NC}"
  if [[ -n "$JAR_UPDATE_TAG" ]]; then
    echo -e "${CYAN}[JarUpdate] Tag '${JAR_UPDATE_TAG}' missing or '${SERVER_JAR}' not attached.${NC}"
  elif [[ -n "$JAR_RELEASE_FILTER" ]]; then
    echo -e "${CYAN}[JarUpdate] No release with filter '${JAR_RELEASE_FILTER}' in tag/title and asset '${SERVER_JAR}'.${NC}"
    echo -e "${CYAN}[JarUpdate] Recent releases:${NC}"
    list_matching_releases "${releases_json:-[]}" ""
  else
    echo -e "${CYAN}[JarUpdate] Set JAR_RELEASE_FILTER (e.g. diff, production) or JAR_UPDATE_TAG (e.g. v1.0.0).${NC}"
  fi
  [[ -f "$JAR_PATH" ]] || exit 1
  exit 0
fi

local_tag=$(get_local_tag)
echo -e "${CYAN}[JarUpdate] Repo: ${JAR_UPDATE_REPO}${NC}"
echo -e "${CYAN}[JarUpdate] Asset: ${SERVER_JAR}${NC}"
[[ -n "$JAR_RELEASE_FILTER" && -z "$JAR_UPDATE_TAG" ]] && echo -e "${CYAN}[JarUpdate] Filter: ${JAR_RELEASE_FILTER}${NC}"
echo -e "${CYAN}[JarUpdate] Installed: ${local_tag:-<none>}${NC}"
echo -e "${CYAN}[JarUpdate] Remote:    ${remote_tag} (${release_name})${NC}"

if [[ "$local_tag" == "$remote_tag" && -f "$JAR_PATH" ]]; then
  echo -e "${GREEN}[JarUpdate] JAR is up to date (${remote_tag}).${NC}"
  exit 0
fi

if is_first_load || [[ "$UPDATE_MODE" == "automatic" ]]; then
  download_jar "$download_url" "$remote_tag" || exit 1
  exit 0
fi

echo -e "${YELLOW}[JarUpdate] Update available: ${local_tag:-<none>} -> ${remote_tag}${NC}"
if prompt_user_yes_no "[JarUpdate] Download ${SERVER_JAR}? [y/N]"; then
  download_jar "$download_url" "$remote_tag" || true
else
  echo -e "${CYAN}[JarUpdate] Skipped; still on ${local_tag:-previous build}.${NC}"
fi

exit 0
