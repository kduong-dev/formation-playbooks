#!/usr/bin/env bash
# Usage: infra/deploy.sh [gateway|dnsmasq]...   (default: both)
#
# Syncs this repo to the server and (re)starts the given infra stacks from
# $REMOTE_ROOT/formation-playbooks/infra/<name>. Nothing here is rendered or
# secret, so there's no render step.
set -euo pipefail

SERVER="${SERVER:-kduong-server}"
REMOTE_ROOT="${REMOTE_ROOT:-/opt/formation}"
INFRA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

stacks=("$@")
[[ ${#stacks[@]} -gt 0 ]] || stacks=(gateway dnsmasq)

echo "Syncing code to $SERVER..."
"$INFRA_DIR/../shared/scripts/sync-formation.sh" "$SERVER" "$REMOTE_ROOT"

for stack in "${stacks[@]}"; do
    echo "Starting $stack on $SERVER..."
    ssh "$SERVER" "'$REMOTE_ROOT/formation-playbooks/infra/$stack/run-services.sh' up"
done
