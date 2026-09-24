#!/usr/bin/env bash
# Usage: sync-formation.sh <server> <remote-root>
#
# Syncs this repo's code to <server>:<remote-root>/formation-playbooks. Only
# code goes up: secrets, vault passwords and every project's rendered files
# stay behind (they carry secrets), and the server's gateway routes are left
# alone since each project's deploy uploads its own.
set -euo pipefail

SERVER="$1"
REMOTE_ROOT="$2"
FORMATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

rsync -az --delete \
    --exclude .git \
    --exclude secrets.yml \
    --exclude .vault_pass \
    --exclude 'projects/*/docker-compose.yml' \
    --exclude 'infra/gateway/routes/' \
    --exclude 'projects/*/backend/*/.env' \
    --exclude 'projects/*/frontend/.env' \
    --exclude 'projects/*/proxy.conf' \
    --exclude 'projects/*/.proxy-port-*' \
    "$FORMATION_DIR/" "$SERVER:$REMOTE_ROOT/formation-playbooks/"
