#!/usr/bin/env bash
set -euo pipefail
trap 'echo -e "${RED}[Website] Error on line $LINENO${NC}"' ERR

BLUE='\033[0;34m'; BOLD_BLUE='\033[1;34m'
WHITE='\033[0;37m'; GREEN='\033[0;32m'
YELLOW='\033[0;33m'; RED='\033[0;31m'
NC='\033[0m'

header() {
  echo -e "${BLUE}───────────────────────────────────────────────${NC}"
  echo -e "${BOLD_BLUE}[Website] $1${NC}"
}

GIT_STATUS="${GIT_STATUS:-true}"
WEBSITE_DIR="${WEBSITE_DIR:-/home/container/www}"

WEBSITE_REPO="${WEBSITE_REPO:-${GIT_ADDRESS:-}}"
WEBSITE_BRANCH="${WEBSITE_BRANCH:-${GIT_BRANCH:-}}"
WEBSITE_TOKEN="${WEBSITE_TOKEN:-${ACCESS_TOKEN:-}}"
WEBSITE_USERNAME="${WEBSITE_USERNAME:-${USERNAME:-}}"

enabled() { [[ "$1" =~ ^(true|1)$ ]]; }

if ! enabled "$GIT_STATUS"; then
  exit 0
fi

if [[ -z "$WEBSITE_REPO" ]]; then
  echo -e "${YELLOW}[Website] WEBSITE_REPO is not set; skipping deploy.${NC}"
  exit 0
fi

command -v git >/dev/null 2>&1 || { echo -e "${RED}[Website] Git not installed; skipping.${NC}"; exit 0; }

build_auth_url() {
  local repo_url="$1"
  local clean_url
  clean_url=$(echo "$repo_url" | sed -E 's|https://[^@]*@|https://|')

  if [[ "$clean_url" != *.git ]]; then
    clean_url="${clean_url}.git"
  fi

  if [[ -z "$WEBSITE_TOKEN" ]]; then
    echo "$clean_url"
    return 0
  fi

  local domain repo_path username
  domain=$(echo "$clean_url" | sed -E 's|https://([^/]+)/.*|\1|')
  repo_path=$(echo "$clean_url" | sed -E 's|https://[^/]+/(.*)|\1|')
  username="${WEBSITE_USERNAME:-x-access-token}"

  echo "https://${username}:${WEBSITE_TOKEN}@${domain}/${repo_path}"
}

AUTH_URL=$(build_auth_url "$WEBSITE_REPO")

header "Deploying Website Repository"
mkdir -p "$WEBSITE_DIR"

if [[ ! -d "${WEBSITE_DIR}/.git" ]]; then
  echo -e "${WHITE}[Website] Cloning repository into ${WEBSITE_DIR}...${NC}"
  if [[ -n "$WEBSITE_BRANCH" ]]; then
    git clone --branch "$WEBSITE_BRANCH" --single-branch "$AUTH_URL" "$WEBSITE_DIR"
  else
    git clone "$AUTH_URL" "$WEBSITE_DIR"
  fi
  echo -e "${GREEN}[Website] Repository cloned successfully.${NC}"
  exit 0
fi

cd "$WEBSITE_DIR"

if [[ -n "$WEBSITE_TOKEN" ]]; then
  git remote set-url origin "$AUTH_URL"
  echo -e "${GREEN}[Website] Remote URL updated with credentials.${NC}"
fi

if [[ -n "$WEBSITE_BRANCH" ]]; then
  echo -e "${WHITE}[Website] Fetching branch '${WEBSITE_BRANCH}'...${NC}"
  git fetch --prune origin "$WEBSITE_BRANCH"
  if git show-ref --verify --quiet "refs/heads/${WEBSITE_BRANCH}"; then
    git checkout "$WEBSITE_BRANCH"
  else
    git checkout -b "$WEBSITE_BRANCH" "origin/${WEBSITE_BRANCH}"
  fi
  git pull --ff-only origin "$WEBSITE_BRANCH"
else
  echo -e "${WHITE}[Website] Pulling latest changes...${NC}"
  git fetch --prune origin
  git pull --ff-only
fi

echo -e "${GREEN}[Website] Repository updated successfully.${NC}"
