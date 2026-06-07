#!/usr/bin/env bash
sed -i 's/\r$//' "$0" 2>/dev/null || true

set -euo pipefail
trap 'echo -e "${RED}[AutoUpdate] Error on line $LINENO${NC}"' ERR

BLUE='\033[0;34m'; BOLD_BLUE='\033[1;34m'
WHITE='\033[0;37m'; GREEN='\033[0;32m'
YELLOW='\033[0;33m'; RED='\033[0;31m'
MAGENTA='\033[0;35m'; CYAN='\033[0;36m'
NC='\033[0m'

header() {
  echo -e "${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}[AutoUpdate] $1${NC}"
}

AUTOUPDATE_STATUS="${AUTOUPDATE_STATUS:-true}"
AUTOUPDATE_FORCE="${AUTOUPDATE_FORCE:-false}"
VERSION_FILE="/home/container/VERSION"
UPSTREAM_REPO="https://github.com/Mark7625/custom-pterodactyl-eggs.git"
UPSTREAM_BRANCH="ktor"
UPSTREAM_DIR="/home/container/.egg-upstream"
CONTAINER_ROOT="/home/container"
TEMP_DIR="/home/container/tmp/autoupdate"

enabled() { [[ "$1" =~ ^(true|1)$ ]]; }

check_staged_update() {
  local staging_dir="${CONTAINER_ROOT}/.autoupdate_staged"

  if [[ -d "$staging_dir/autoupdate" ]]; then
    echo -e "${YELLOW}[AutoUpdate] Staged self-update detected${NC}"
    local backup_dir="${CONTAINER_ROOT}/.autoupdate_backup_$(date +%s)"
    mkdir -p "$backup_dir"
    cp -r "${CONTAINER_ROOT}/modules/autoupdate" "$backup_dir/" 2>/dev/null || true

    if cp -r "$staging_dir/autoupdate" "${CONTAINER_ROOT}/modules/" 2>/dev/null; then
      chmod +x "${CONTAINER_ROOT}/modules/autoupdate/start.sh" 2>/dev/null || true
      echo -e "${GREEN}[AutoUpdate] Self-update applied successfully${NC}"
      rm -rf "$staging_dir" 2>/dev/null || true
    fi
  fi
}

get_current_version() {
  if [[ -f "$VERSION_FILE" ]] && [[ -s "$VERSION_FILE" ]]; then
    local version
    version=$(tr -d '\n\r' < "$VERSION_FILE" | head -1)
    if [[ -n "$version" && "$version" != "unknown" ]]; then
      echo "$version"
      return 0
    fi
  fi
  echo "unknown"
}

get_latest_version() {
  local latest
  latest=$(git ls-remote "$UPSTREAM_REPO" "refs/heads/${UPSTREAM_BRANCH}" 2>/dev/null | awk '{print $1}' | head -1)
  if [[ -n "$latest" ]]; then
    echo "$latest"
    return 0
  fi
  return 1
}

update_version_file() {
  local new_version="$1"
  if printf "%s\n" "$new_version" > "$VERSION_FILE" 2>/dev/null; then
    echo -e "${GREEN}[AutoUpdate] Version file updated to ${new_version:0:12}...${NC}"
  fi
}

create_pre_update_backup() {
  local extract_dir="$1"
  local from_version="$2"
  local to_version="$3"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_dir="${CONTAINER_ROOT}/.autoupdate_prebackup_${from_version:0:8}_to_${to_version:0:8}_${timestamp}"
  mkdir -p "$backup_dir"

  echo -e "${CYAN}[AutoUpdate] Creating pre-update backup...${NC}"
  local backed_up=0

  while IFS= read -r -d '' extracted_file; do
    local rel_path="${extracted_file#${extract_dir}/}"
    local live_file="${CONTAINER_ROOT}/${rel_path}"
    if [[ -f "$live_file" ]]; then
      mkdir -p "$(dirname "${backup_dir}/${rel_path}")"
      cp "$live_file" "${backup_dir}/${rel_path}"
      backed_up=$((backed_up + 1))
    fi
  done < <(find "$extract_dir" -type f -print0)

  if [[ $backed_up -gt 0 ]]; then
    {
      echo "Pre-update backup"
      echo "From commit : $from_version"
      echo "To commit   : $to_version"
      echo "Created at  : $(date)"
      echo "Files backed up: $backed_up"
    } > "${backup_dir}/.backup_info"
    echo -e "${GREEN}[AutoUpdate] Backed up ${backed_up} file(s)${NC}"
  else
    rmdir "$backup_dir" 2>/dev/null || true
  fi
}

sync_upstream() {
  if [[ ! -d "${UPSTREAM_DIR}/.git" ]]; then
    echo -e "${WHITE}[AutoUpdate] Cloning upstream repository (${UPSTREAM_BRANCH})...${NC}"
    git clone --branch "$UPSTREAM_BRANCH" --single-branch "$UPSTREAM_REPO" "$UPSTREAM_DIR"
    return 0
  fi

  echo -e "${WHITE}[AutoUpdate] Fetching upstream repository (${UPSTREAM_BRANCH})...${NC}"
  git -C "$UPSTREAM_DIR" fetch origin "$UPSTREAM_BRANCH" --prune
  git -C "$UPSTREAM_DIR" checkout "$UPSTREAM_BRANCH"
  git -C "$UPSTREAM_DIR" reset --hard "origin/${UPSTREAM_BRANCH}"
}

apply_update() {
  local from_version="$1"
  local to_version="$2"
  local extract_dir="${TEMP_DIR}/extracted"
  local allowed_dirs=("modules")
  local allowed_files=("start-modules.sh" "README.md" "LICENSE" "entrypoint.sh")
  local protected_files=()
  local self_update_required=false
  local updated_files=0

  sync_upstream

  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"

  for dir in "${allowed_dirs[@]}"; do
    if [[ -d "${UPSTREAM_DIR}/${dir}" ]]; then
      cp -r "${UPSTREAM_DIR}/${dir}" "$extract_dir/"
    fi
  done

  for file in "${allowed_files[@]}"; do
    if [[ -f "${UPSTREAM_DIR}/${file}" ]]; then
      cp "${UPSTREAM_DIR}/${file}" "$extract_dir/"
    fi
  done

  for protected in "${protected_files[@]}"; do
    rm -f "${extract_dir}/${protected}"
  done

  create_pre_update_backup "$extract_dir" "$from_version" "$to_version"

  if [[ -f "${extract_dir}/modules/autoupdate/start.sh" ]]; then
    self_update_required=true
  fi

  for dir in "${allowed_dirs[@]}"; do
    if [[ -d "${extract_dir}/${dir}" ]]; then
      if [[ "$dir" == "modules" && "$self_update_required" == "true" ]]; then
        for module_subdir in "${extract_dir}/${dir}"/*; do
          if [[ -d "$module_subdir" ]]; then
            local module_name
            module_name=$(basename "$module_subdir")
            if [[ "$module_name" != "autoupdate" ]]; then
              cp -r "$module_subdir" "${CONTAINER_ROOT}/${dir}/" 2>/dev/null || true
              find "${CONTAINER_ROOT}/${dir}/${module_name}" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
            fi
          fi
        done
        local staging_dir="${CONTAINER_ROOT}/.autoupdate_staged"
        mkdir -p "$staging_dir"
        cp -r "${extract_dir}/modules/autoupdate" "$staging_dir/" 2>/dev/null || true
        chmod +x "$staging_dir/autoupdate/start.sh" 2>/dev/null || true
      else
        cp -r "${extract_dir}/${dir}/"* "${CONTAINER_ROOT}/${dir}/" 2>/dev/null || true
        find "${CONTAINER_ROOT}/${dir}" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
      fi
      updated_files=$((updated_files + 1))
    fi
  done

  for file in "${allowed_files[@]}"; do
    if [[ -f "${extract_dir}/${file}" ]]; then
      cp "${extract_dir}/${file}" "${CONTAINER_ROOT}/${file}"
      if [[ "$file" == "start-modules.sh" ]]; then
        chmod +x "${CONTAINER_ROOT}/${file}"
      fi
      updated_files=$((updated_files + 1))
    fi
  done

  rm -rf "$extract_dir"

  if [[ $updated_files -gt 0 ]]; then
    update_version_file "$to_version"
    if [[ "$self_update_required" == "true" ]]; then
      echo -e "${YELLOW}[AutoUpdate] Auto-update module staged for next restart${NC}"
    fi
    return 0
  fi

  return 1
}

main() {
  if ! enabled "$AUTOUPDATE_STATUS"; then
    exit 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo -e "${YELLOW}[AutoUpdate] Git not available; skipping update check${NC}"
    exit 0
  fi

  check_staged_update
  header "Checking for Updates"

  mkdir -p "$TEMP_DIR"

  local current_version latest_version
  current_version=$(get_current_version)
  echo -e "${WHITE}[AutoUpdate] Current version: ${current_version}${NC}"
  echo -e "${CYAN}[AutoUpdate] Source: ${UPSTREAM_REPO} (${UPSTREAM_BRANCH})${NC}"

  if ! latest_version=$(get_latest_version); then
    echo -e "${YELLOW}[AutoUpdate] Could not fetch latest version from GitHub${NC}"
    return 0
  fi

  echo -e "${WHITE}[AutoUpdate] Latest version: ${latest_version:0:12}...${NC}"

  if [[ "$current_version" == "unknown" ]]; then
    update_version_file "$latest_version"
    echo -e "${GREEN}[AutoUpdate] Version tracking initialized${NC}"
    return 0
  fi

  if [[ "$current_version" == "$latest_version" ]]; then
    echo -e "${GREEN}[AutoUpdate] You are running the newest version${NC}"
    return 0
  fi

  echo -e "${YELLOW}[AutoUpdate] Update available${NC}"

  if enabled "$AUTOUPDATE_FORCE"; then
    header "Applying Update"
    if apply_update "$current_version" "$latest_version"; then
      echo -e "${GREEN}[AutoUpdate] Update completed successfully${NC}"
    else
      echo -e "${YELLOW}[AutoUpdate] Update failed, continuing with current version${NC}"
    fi
  else
    echo -e "${CYAN}[AutoUpdate] Set AUTOUPDATE_FORCE=true to apply updates automatically${NC}"
  fi
}

main || echo -e "${YELLOW}[AutoUpdate] Update check completed${NC}"
rm -rf "$TEMP_DIR" 2>/dev/null || true
