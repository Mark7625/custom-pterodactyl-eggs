#!/usr/bin/env bash
# Download OpenRune game server release zip from GitHub Releases (latest matching build type).

OPENRUNE_SERVER_UPDATE="${OPENRUNE_SERVER_UPDATE:-}"
OPENRUNE_RELEASE_REPO="${OPENRUNE_RELEASE_REPO:-OpenRune/OpenRune-Server}"
OPENRUNE_BUILD_TYPE="${OPENRUNE_BUILD_TYPE:-production}"
OPENRUNE_RELEASE_ASSET="${OPENRUNE_RELEASE_ASSET:-server-release.zip}"
JAR_UPDATE_INCLUDE_PRERELEASE="${JAR_UPDATE_INCLUDE_PRERELEASE:-0}"
JAR_UPDATE_PROMPT_SEC="${JAR_UPDATE_PROMPT_SEC:-60}"

SERVER_JAR="${SERVER_JAR:-server.jar}"
CONTAINER_ROOT="/home/container"
JAR_PATH="${CONTAINER_ROOT}/${SERVER_JAR}"
STATE_FILE="${CONTAINER_ROOT}/.jarupdate_release"
STAGING_DIR="${CONTAINER_ROOT}/.release_staging"
DOWNLOAD_ZIP="${CONTAINER_ROOT}/.release.download.zip"

BLUE='\033[0;34m'
BOLD_BLUE='\033[1;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

enabled() { [[ "${1}" =~ ^(true|1|yes|on)$ ]]; }

resolve_update_mode() {
    local raw="${OPENRUNE_SERVER_UPDATE}"
    if [[ -z "${raw}" ]]; then
        if enabled "${JAR_UPDATE_DISABLE:-0}" || ! enabled "${JAR_UPDATE_STATUS:-1}"; then
            echo "disabled"
            return
        fi
        if enabled "${JAR_UPDATE_AUTO:-0}" || enabled "${JAR_UPDATE_APPROVE:-0}"; then
            echo "automatic"
            return
        fi
        echo "notification"
        return
    fi
    raw="${raw,,}"
    case "${raw}" in
        disabled|disable|off|0|false|no) echo "disabled" ;;
        automatic|auto|1|true|yes|on) echo "automatic" ;;
        notification|notify|prompt|ask|required|"notification required") echo "notification" ;;
        *)
            echo -e "${YELLOW}[JarUpdate] Unknown OPENRUNE_SERVER_UPDATE='${OPENRUNE_SERVER_UPDATE}'; using notification.${NC}"
            echo "notification"
            ;;
    esac
}

header() {
    echo -e "${BLUE}───────────────────────────────────────────────${NC}"
    echo -e "${BOLD_BLUE}[JarUpdate] $1${NC}"
}

github_curl() {
    local url="$1"
    local -a args=(
        -fsSL
        --max-time 45
        -H "Accept: application/vnd.github+json"
        -H "User-Agent: OpenRune-GameServer-JarUpdate"
    )
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi
    curl "${args[@]}" "${url}" 2>/dev/null
}

debug_print_releases_api() {
    local api_url="$1"
    local releases_json="$2"
    echo -e "${CYAN}[JarUpdate] DEBUG GET ${api_url}${NC}"
    echo -e "${CYAN}[JarUpdate] DEBUG OPENRUNE_RELEASE_REPO=${OPENRUNE_RELEASE_REPO}${NC}"
    echo -e "${CYAN}[JarUpdate] DEBUG OPENRUNE_BUILD_TYPE=${OPENRUNE_BUILD_TYPE}${NC}"
    echo -e "${CYAN}[JarUpdate] DEBUG OPENRUNE_RELEASE_ASSET=${OPENRUNE_RELEASE_ASSET}${NC}"
    echo -e "${CYAN}[JarUpdate] DEBUG GITHUB_TOKEN set: $( [[ -n "${GITHUB_TOKEN:-}" ]] && echo yes || echo no )${NC}"
    echo -e "${CYAN}[JarUpdate] DEBUG response bytes: ${#releases_json}${NC}"
    echo -e "${CYAN}[JarUpdate] DEBUG releases JSON:${NC}"
    printf '%s\n' "${releases_json}"
}

tag_matches_build_type() {
    local tag="$1"
    local build_type="$2"
    local tag_l="${tag,,}"
    local bt="${build_type,,}"
    [[ "${tag_l}" == *"-${bt}-"* ]] || [[ "${tag_l}" == *"-${bt}" ]]
}

split_release_blocks() {
    local releases_json="$1"
    local tmp="$2"
    printf '%s' "${releases_json}" | tr -d '\n' |
        sed -E 's/\},\{"url":"https:\/\/api\.github\.com\/repos\/[^\/]+\/[^\/]+\/releases\/[0-9]+"/\
{"url":"https:\/\/api.github.com\/repos/g' |
        sed 's/^\[//' |
        sed 's/\]$//' >"${tmp}"
}

extract_asset_download_url() {
    local block="$1"
    local asset_name="$2"
    local url api_url

    if ! printf '%s' "${block}" | grep -q '"name"[[:space:]]*:[[:space:]]*"'"${asset_name}"'"'; then
        return 1
    fi

    url=$(
        printf '%s' "${block}" |
            grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' |
            head -1 |
            sed 's/.*"\(https[^"]*\)".*/\1/'
    )

    api_url=$(
        printf '%s' "${block}" |
            grep -o '"url"[[:space:]]*:[[:space:]]*"https://api\.github\.com/repos/[^"]*/releases/assets/[0-9]*"' |
            head -1 |
            sed 's/.*"\(https[^"]*\)".*/\1/'
    )

    if [[ -n "${GITHUB_TOKEN:-}" && -n "${api_url}" ]]; then
        printf '%s' "${api_url}"
        return 0
    fi

    [[ -n "${url}" ]] && printf '%s' "${url}"
}

extract_release_published_at() {
    local block="$1"
    local published created

    published=$(
        printf '%s' "${block}" |
            grep -o '"published_at"[[:space:]]*:[[:space:]]*"[^"]*"' |
            head -1 |
            sed 's/.*"\([^"]*\)"$/\1/'
    )
    if [[ -n "${published}" ]]; then
        printf '%s' "${published}"
        return 0
    fi

    created=$(
        printf '%s' "${block}" |
            grep -o '"created_at"[[:space:]]*:[[:space:]]*"[^"]*"' |
            head -1 |
            sed 's/.*"\([^"]*\)"$/\1/'
    )
    printf '%s' "${created}"
}

extract_release_id() {
    local block="$1"
    printf '%s' "${block}" |
        grep -o '"id"[[:space:]]*:[[:space:]]*[0-9][0-9]*' |
        head -1 |
        sed 's/.*:[[:space:]]*//'
}

find_matching_release_bash() {
    local releases_json="$1"
    local build_type="$2"
    local asset_name="$3"
    local tmp block tag name url published release_id
    local best_published="" best_tag="" best_url="" best_name="" best_id=0

    tmp=$(mktemp)
    split_release_blocks "${releases_json}" "${tmp}"

    while IFS= read -r block; do
        [[ -z "${block}" ]] && continue
        [[ "${block}" != "{"* ]] && block="{${block}}"

        tag=$(printf '%s' "${block}" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
        name=$(printf '%s' "${block}" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"[^"]*".*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        [[ -z "${tag}" ]] && continue

        if ! tag_matches_build_type "${tag}" "${build_type}"; then
            continue
        fi

        url=$(extract_asset_download_url "${block}" "${asset_name}") || url=""
        [[ -z "${url}" ]] && continue

        published=$(extract_release_published_at "${block}")
        release_id=$(extract_release_id "${block}")
        [[ -z "${release_id}" ]] && release_id=0

        if [[ -z "${best_published}" || "${published}" > "${best_published}" || ( "${published}" == "${best_published}" && "${release_id}" -gt "${best_id}" ) ]]; then
            best_published="${published}"
            best_tag="${tag}"
            best_url="${url}"
            best_name="${name:-${tag}}"
            best_id="${release_id}"
        fi
    done <"${tmp}"

    rm -f "${tmp}"

    if [[ -n "${best_tag}" && -n "${best_url}" ]]; then
        printf '%s\n' "${best_tag}" "${best_url}" "${best_name}"
        return 0
    fi

    return 1
}

find_matching_release() {
    local releases_json="$1"
    local build_type="$2"
    local asset_name="$3"

    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "${releases_json}" | python3 -c "
import json, sys
build_type = sys.argv[1].strip().lower()
asset_name = sys.argv[2]
releases = json.load(sys.stdin)
if not isinstance(releases, list):
    releases = [releases]

def tag_matches(tag):
    tag = (tag or '').strip().lower()
    return f'-{build_type}-' in tag or tag.endswith(f'-{build_type}')

best = None
for release in releases:
    if not tag_matches(release.get('tag_name')):
        continue
    for asset in release.get('assets', []):
        if asset.get('name') != asset_name:
            continue
        published = release.get('published_at') or release.get('created_at') or ''
        release_id = release.get('id') or 0
        api_url = asset.get('url') or ''
        browser_url = asset.get('browser_download_url') or ''
        download_url = api_url or browser_url
        candidate = (published, release_id, release.get('tag_name', ''), download_url, release.get('name', ''))
        if best is None or candidate[:2] > best[:2]:
            best = candidate
        break

if best is None:
    sys.exit(1)

print(best[2])
print(best[3])
print(best[4])
" "${build_type}" "${asset_name}" 2>/dev/null && return 0
    fi

    if command -v jq >/dev/null 2>&1; then
        local result
        result=$(printf '%s' "${releases_json}" | jq -r --arg bt "${build_type}" --arg asset "${asset_name}" '
            (if type == "array" then . else [.] end)
            | [.[] | select((.tag_name // "" | ascii_downcase | test("-" + $bt + "(-|$)")))
                | . as $r
                | ($r.assets[] | select(.name == $asset) | {
                    published: ($r.published_at // $r.created_at // ""),
                    id: ($r.id // 0),
                    tag: $r.tag_name,
                    name: $r.name,
                    url: (.url // .browser_download_url)
                  })
              ]
            | sort_by(.published, .id) | reverse
            | .[0]
            | if . == null then empty else [.tag, .url, .name] | @tsv end
        ' | head -1)
        if [[ -n "${result}" ]]; then
            printf '%s\n' "${result}" | tr '\t' '\n'
            return 0
        fi
    fi

    if find_matching_release_bash "${releases_json}" "${build_type}" "${asset_name}"; then
        return 0
    fi

    return 1
}

get_local_tag() {
    if [[ -f "${STATE_FILE}" ]] && [[ -s "${STATE_FILE}" ]]; then
        tr -d '\n\r' <"${STATE_FILE}" | head -1
        return
    fi
    echo ""
}

is_first_load() {
    [[ ! -f "${JAR_PATH}" ]] || [[ ! -s "${JAR_PATH}" ]] || [[ ! -f "${STATE_FILE}" ]] || [[ ! -s "${STATE_FILE}" ]]
}

prompt_user_yes_no() {
    local message="$1"
    if [[ ! -e /dev/tty ]]; then
        return 1
    fi
    echo -e "${YELLOW}${message}${NC}" >/dev/tty
    echo -e "${CYAN}[JarUpdate] Reply y/yes on the console within ${JAR_UPDATE_PROMPT_SEC}s.${NC}" >/dev/tty
    local answer=""
    if ! read -r -t "${JAR_UPDATE_PROMPT_SEC}" answer </dev/tty; then
        return 1
    fi
    case "${answer,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

remove_old_deployment() {
    echo -e "${CYAN}[JarUpdate] Removing previous server files...${NC}"
    rm -rf "${CONTAINER_ROOT}/.data"
    rm -f "${CONTAINER_ROOT}/game.yml"
    rm -f "${JAR_PATH}"
}

extract_release_zip() {
    local zip_file="$1"
    local dest_dir="$2"

    if command -v unzip >/dev/null 2>&1; then
        unzip -oq "${zip_file}" -d "${dest_dir}"
        return $?
    fi

    if command -v jar >/dev/null 2>&1; then
        echo -e "${CYAN}[JarUpdate] unzip missing — extracting with jar (JDK).${NC}"
        (cd "${dest_dir}" && jar xf "${zip_file}")
        return $?
    fi

    if command -v python3 >/dev/null 2>&1; then
        echo -e "${CYAN}[JarUpdate] unzip missing — extracting with python3.${NC}"
        python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "${zip_file}" "${dest_dir}"
        return $?
    fi

    echo -e "${RED}[JarUpdate] No zip extractor available (need unzip, jar, or python3).${NC}"
    return 1
}

install_release_zip() {
    local url="$1"
    local tag="$2"
    local backup_dir="${CONTAINER_ROOT}/.jarupdate_backup_$(date +%Y%m%d_%H%M%S)"

    if [[ -f "${JAR_PATH}" || -d "${CONTAINER_ROOT}/.data" || -f "${CONTAINER_ROOT}/game.yml" ]]; then
        mkdir -p "${backup_dir}"
        [[ -f "${JAR_PATH}" ]] && cp -a "${JAR_PATH}" "${backup_dir}/" 2>/dev/null || true
        [[ -f "${CONTAINER_ROOT}/game.yml" ]] && cp -a "${CONTAINER_ROOT}/game.yml" "${backup_dir}/" 2>/dev/null || true
        [[ -d "${CONTAINER_ROOT}/.data" ]] && cp -a "${CONTAINER_ROOT}/.data" "${backup_dir}/" 2>/dev/null || true
        echo -e "${CYAN}[JarUpdate] Backed up previous files to ${backup_dir}${NC}"
    fi

    remove_old_deployment
    rm -rf "${STAGING_DIR}"
    mkdir -p "${STAGING_DIR}"

    echo -e "${CYAN}[JarUpdate] Downloading ${OPENRUNE_RELEASE_ASSET} (${tag})...${NC}"
    local -a dl_args=(-fsSL --max-time 600 -L -o "${DOWNLOAD_ZIP}")
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        dl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/octet-stream")
    fi
    if ! curl "${dl_args[@]}" "${url}"; then
        echo -e "${RED}[JarUpdate] Download failed.${NC}"
        rm -f "${DOWNLOAD_ZIP}"
        return 1
    fi

    if [[ ! -s "${DOWNLOAD_ZIP}" ]]; then
        echo -e "${RED}[JarUpdate] Downloaded zip is empty.${NC}"
        rm -f "${DOWNLOAD_ZIP}"
        return 1
    fi

    if ! extract_release_zip "${DOWNLOAD_ZIP}" "${STAGING_DIR}"; then
        echo -e "${RED}[JarUpdate] Failed to extract ${OPENRUNE_RELEASE_ASSET}.${NC}"
        rm -f "${DOWNLOAD_ZIP}"
        rm -rf "${STAGING_DIR}"
        return 1
    fi

    if [[ -f "${STAGING_DIR}/${SERVER_JAR}" ]]; then
        mv -f "${STAGING_DIR}/${SERVER_JAR}" "${JAR_PATH}"
    elif [[ -f "${STAGING_DIR}/server.jar" ]]; then
        mv -f "${STAGING_DIR}/server.jar" "${JAR_PATH}"
    else
        echo -e "${RED}[JarUpdate] ${SERVER_JAR} not found inside ${OPENRUNE_RELEASE_ASSET}.${NC}"
        rm -f "${DOWNLOAD_ZIP}"
        rm -rf "${STAGING_DIR}"
        return 1
    fi

    if [[ -f "${STAGING_DIR}/game.yml" ]]; then
        mv -f "${STAGING_DIR}/game.yml" "${CONTAINER_ROOT}/game.yml"
    fi

    if [[ -d "${STAGING_DIR}/.data" ]]; then
        mv -f "${STAGING_DIR}/.data" "${CONTAINER_ROOT}/.data"
    elif [[ -d "${STAGING_DIR}/data" ]]; then
        mv -f "${STAGING_DIR}/data" "${CONTAINER_ROOT}/.data"
    else
        echo -e "${RED}[JarUpdate] .data directory not found inside ${OPENRUNE_RELEASE_ASSET}.${NC}"
        rm -f "${DOWNLOAD_ZIP}"
        rm -rf "${STAGING_DIR}"
        return 1
    fi

    rm -f "${DOWNLOAD_ZIP}"
    rm -rf "${STAGING_DIR}"
    printf '%s\n' "${tag}" >"${STATE_FILE}"
    echo -e "${GREEN}[JarUpdate] Installed release ${tag} (${OPENRUNE_RELEASE_ASSET})${NC}"
    return 0
}

UPDATE_MODE=$(resolve_update_mode)

if [[ "${UPDATE_MODE}" == "disabled" ]]; then
    echo -e "${CYAN}[JarUpdate] Disabled (OPENRUNE_SERVER_UPDATE=disabled). Upload server files yourself.${NC}"
    if [[ ! -f "${JAR_PATH}" ]]; then
        echo -e "${RED}[JarUpdate] No JAR at ${SERVER_JAR}. Upload one or enable Server update.${NC}"
        exit 1
    fi
    exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
    echo -e "${YELLOW}[JarUpdate] curl not available; skipping release update.${NC}"
    exit 0
fi

header "Checking GitHub Releases"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo -e "${YELLOW}[JarUpdate] GITHUB_TOKEN is not set — required to list/download releases from private repo ${OPENRUNE_RELEASE_REPO}.${NC}"
fi

if enabled "${JAR_UPDATE_INCLUDE_PRERELEASE}"; then
    api_url="https://api.github.com/repos/${OPENRUNE_RELEASE_REPO}/releases?per_page=30"
else
    api_url="https://api.github.com/repos/${OPENRUNE_RELEASE_REPO}/releases?per_page=30"
fi

releases_json=$(github_curl "${api_url}") || releases_json=""
if enabled "${JAR_UPDATE_DEBUG:-0}"; then
    debug_print_releases_api "${api_url}" "${releases_json:-}"
fi
if [[ -z "${releases_json}" || "${releases_json}" == "[]" ]]; then
    echo -e "${RED}[JarUpdate] No releases returned from ${OPENRUNE_RELEASE_REPO}.${NC}"
    echo -e "${CYAN}[JarUpdate] Private repos require GITHUB_TOKEN (PAT with repo read access).${NC}"
    if [[ ! -f "${JAR_PATH}" ]]; then
        exit 1
    fi
    exit 0
fi

parsed=$(find_matching_release "${releases_json}" "${OPENRUNE_BUILD_TYPE}" "${OPENRUNE_RELEASE_ASSET}") || parsed=""
remote_tag=$(echo "${parsed}" | sed -n '1p')
download_url=$(echo "${parsed}" | sed -n '2p')
release_name=$(echo "${parsed}" | sed -n '3p')

if [[ -z "${remote_tag}" || -z "${download_url}" ]]; then
    echo -e "${YELLOW}[JarUpdate] No release found for build type '${OPENRUNE_BUILD_TYPE}' with asset '${OPENRUNE_RELEASE_ASSET}'.${NC}"
    echo -e "${CYAN}[JarUpdate] Expected tag containing '-${OPENRUNE_BUILD_TYPE}-' or ending with '-${OPENRUNE_BUILD_TYPE}'.${NC}"
    echo -e "${CYAN}[JarUpdate] Set OPENRUNE_BUILD_TYPE, OPENRUNE_RELEASE_REPO, and GITHUB_TOKEN (private repo).${NC}"
    if [[ ! -f "${JAR_PATH}" ]]; then
        exit 1
    fi
    exit 0
fi

local_tag=$(get_local_tag)
echo -e "${CYAN}[JarUpdate] Mode: ${UPDATE_MODE}${NC}"
echo -e "${CYAN}[JarUpdate] Repository: ${OPENRUNE_RELEASE_REPO}${NC}"
echo -e "${CYAN}[JarUpdate] Build type: ${OPENRUNE_BUILD_TYPE}${NC}"
echo -e "${CYAN}[JarUpdate] Asset: ${OPENRUNE_RELEASE_ASSET}${NC}"
echo -e "${CYAN}[JarUpdate] Installed: ${local_tag:-<none>}${NC}"
echo -e "${CYAN}[JarUpdate] Latest:   ${remote_tag} (${release_name})${NC}"

if [[ "${local_tag}" == "${remote_tag}" ]] && [[ -f "${JAR_PATH}" ]] && [[ -d "${CONTAINER_ROOT}/.data/cache/SERVER" ]]; then
    echo -e "${GREEN}[JarUpdate] Server is up to date (${remote_tag}).${NC}"
    exit 0
fi

if is_first_load; then
    echo -e "${YELLOW}[JarUpdate] First install — downloading latest matching release automatically.${NC}"
    install_release_zip "${download_url}" "${remote_tag}" || exit 1
    exit 0
fi

if [[ "${UPDATE_MODE}" == "automatic" ]]; then
    echo -e "${YELLOW}[JarUpdate] Automatic — updating to ${remote_tag}.${NC}"
    install_release_zip "${download_url}" "${remote_tag}" || exit 0
    exit 0
fi

echo -e "${YELLOW}[JarUpdate] New release available: ${local_tag} → ${remote_tag}${NC}"
if prompt_user_yes_no "[JarUpdate] Download and replace server files? [y/N]"; then
    install_release_zip "${download_url}" "${remote_tag}" || true
else
    echo -e "${CYAN}[JarUpdate] Skipped update; still running ${local_tag:-previous build}.${NC}"
    echo -e "${CYAN}[JarUpdate] Set Server update to Automatic in Startup and restart to apply without a prompt.${NC}"
fi

exit 0
