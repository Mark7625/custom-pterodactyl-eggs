#!/bin/bash

EGG_REPO="https://github.com/Mark7625/custom-pterodactyl-eggs.git"
EGG_BRANCH="nextjs"

WEBSITE_REPO="${WEBSITE_REPO:-${GIT_ADDRESS:-}}"
WEBSITE_BRANCH="${WEBSITE_BRANCH:-${GIT_BRANCH:-}}"
WEBSITE_TOKEN="${WEBSITE_TOKEN:-${ACCESS_TOKEN:-}}"
WEBSITE_USERNAME="${WEBSITE_USERNAME:-${USERNAME:-}}"

echo -e "[SETUP] Install packages"
apt-get update -qq > /dev/null 2>&1 && apt-get install -qq > /dev/null 2>&1 -y git wget

git ls-remote "$EGG_REPO" "refs/heads/${EGG_BRANCH}" | awk '{print $1}' | head -1 > /mnt/server/VERSION

cd /mnt/server

echo -e "[SETUP] Create folders"
mkdir -p logs tmp www public

echo "[Git] Cloning egg repository '${EGG_REPO}' (branch: ${EGG_BRANCH})"
git clone --branch "$EGG_BRANCH" --single-branch "$EGG_REPO" /mnt/server/gtemp > /dev/null 2>&1 \
  && echo "[Git] Repository cloned successfully." \
  || { echo "[Git] Error: Default repository clone failed."; exit 21; }

echo "[Git] Copying egg files from repository."
cp -r /mnt/server/gtemp/nginx /mnt/server || { echo "[Git] Error: Copying 'nginx' folder failed."; exit 22; }
cp -r /mnt/server/gtemp/modules /mnt/server || { echo "[Git] Error: Copying 'modules' folder failed."; exit 22; }
cp /mnt/server/gtemp/start-modules.sh /mnt/server || { echo "[Git] Error: Copying 'start-modules.sh' file failed."; exit 22; }
cp /mnt/server/gtemp/LICENSE /mnt/server || { echo "[Git] Error: Copying 'LICENSE' file failed."; exit 22; }
chmod +x /mnt/server/start-modules.sh
find /mnt/server/modules -type f -name "*.sh" -exec chmod +x {} \;

rm -rf /mnt/server/gtemp

if [ -z "${WEBSITE_REPO}" ]; then
    echo "[Website] Info: WEBSITE_REPO is not set."
    echo "[Website] Website deploy is disabled during install."
    echo '<!DOCTYPE html><html><head><title>Next.js Egg</title></head><body><h1>Pterodactyl Next.js Egg</h1><p>Set WEBSITE_REPO to your Next.js repository and restart.</p></body></html>' > /mnt/server/www/index.html
    ln -sfn /mnt/server/www /mnt/server/public
else
    if [[ ${WEBSITE_REPO} != *.git ]]; then
        WEBSITE_REPO="${WEBSITE_REPO}.git"
    fi

    if [ -n "${WEBSITE_TOKEN}" ]; then
        GIT_DOMAIN=$(echo "${WEBSITE_REPO}" | sed -E 's|https://([^/]+)/.*|\1|')
        GIT_REPO_PATH=$(echo "${WEBSITE_REPO}" | sed -E 's|https://[^/]+/(.*)|\1|')
        AUTH_USER="${WEBSITE_USERNAME:-x-access-token}"
        CLONE_URL="https://${AUTH_USER}:${WEBSITE_TOKEN}@${GIT_DOMAIN}/${GIT_REPO_PATH}"
        echo "[Website] Using authenticated Git access."
    else
        CLONE_URL="${WEBSITE_REPO}"
        echo "[Website] Using anonymous Git access."
    fi

    rm -rf /mnt/server/www
    mkdir -p /mnt/server/www

    if [ -n "${WEBSITE_BRANCH}" ]; then
        git clone --branch "${WEBSITE_BRANCH}" --single-branch "${CLONE_URL}" /mnt/server/www > /dev/null 2>&1 \
          && echo "[Website] Repository cloned successfully (branch '${WEBSITE_BRANCH}')." \
          || { echo "[Website] Error: git clone failed (branch '${WEBSITE_BRANCH}')."; exit 14; }
    else
        git clone "${CLONE_URL}" /mnt/server/www > /dev/null 2>&1 \
          && echo "[Website] Repository cloned successfully." \
          || { echo "[Website] Error: git clone failed."; exit 14; }
    fi
fi

echo -e "[DONE] Everything has been installed successfully"
echo -e "[INFO] You can now start the Next.js server"
