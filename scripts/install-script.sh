#!/bin/bash

EGG_REPO="https://github.com/Mark7625/custom-pterodactyl-eggs.git"
EGG_BRANCH="basic-jar"

echo -e "[SETUP] Install packages"
apt-get update -qq > /dev/null 2>&1 && apt-get install -qq -y git wget curl > /dev/null 2>&1

git ls-remote "$EGG_REPO" "refs/heads/${EGG_BRANCH}" | awk '{print $1}' | head -1 > /mnt/server/VERSION

cd /mnt/server

echo -e "[SETUP] Create folders"
mkdir -p logs tmp

echo "[Git] Cloning egg repository '${EGG_REPO}' (branch: ${EGG_BRANCH})"
git clone --branch "$EGG_BRANCH" --single-branch "$EGG_REPO" /mnt/server/gtemp > /dev/null 2>&1 \
  && echo "[Git] Repository cloned successfully." \
  || { echo "[Git] Error: Could not clone branch '${EGG_BRANCH}'."; exit 1; }

echo "[SETUP] Copying egg files"
cp -r /mnt/server/gtemp/modules /mnt/server/
cp -r /mnt/server/gtemp/scripts /mnt/server/
cp /mnt/server/gtemp/start-modules.sh /mnt/server/
cp /mnt/server/gtemp/entrypoint.sh /mnt/server/ 2>/dev/null || true
chmod +x /mnt/server/scripts/*.sh 2>/dev/null || true
chmod +x /mnt/server/start-modules.sh
find /mnt/server/modules -type f -name "*.sh" -exec chmod +x {} +

rm -rf /mnt/server/gtemp

echo "[SETUP] Basic JAR egg installed. Set JAR_UPDATE_REPO, SERVER_JAR, and APP_ARGS in Startup."
