#!/usr/bin/env bash
# Render locally, sync code + rendered files to the server, then build and
# start storage-service there and make sure the shared Traefik
# (projects/gateway) is up to route api.storage-service.home to it. Secrets
# never leave this machine except as the rendered .env; secrets.yml and
# .vault_pass are not synced.
#
# Server layout mirrors the local one, since the build context is the parent
# of formation-playbooks:
#   $REMOTE_ROOT/formation-playbooks/
#   $REMOTE_ROOT/storage-service/
set -euo pipefail

SERVER="${SERVER:-kduong-server}"
REMOTE_ROOT="${REMOTE_ROOT:-/opt/formation}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMATION_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
APPS_DIR="$(cd "$FORMATION_DIR/.." && pwd)"
REMOTE_PROJECT="$REMOTE_ROOT/formation-playbooks/projects/storage-service"
REMOTE_GATEWAY="$REMOTE_ROOT/formation-playbooks/projects/gateway"

echo "Rendering..."
"$PROJECT_DIR/run-services.sh" render

echo "Checking $SERVER:$REMOTE_ROOT..."
if ! ssh "$SERVER" "mkdir -p '$REMOTE_ROOT' && test -w '$REMOTE_ROOT'"; then
    echo "Can't write to $REMOTE_ROOT on $SERVER. Once, on the server:" >&2
    echo "  sudo mkdir -p $REMOTE_ROOT && sudo chown \$USER $REMOTE_ROOT" >&2
    exit 1
fi

echo "Syncing code..."
# Other projects' rendered files carry their secrets, so only code goes up here.
rsync -az --delete \
    --exclude .git \
    --exclude secrets.yml \
    --exclude .vault_pass \
    --include 'projects/gateway/docker-compose.yml' \
    --exclude 'projects/*/docker-compose.yml' \
    --exclude 'projects/gateway/routes/' \
    --exclude 'projects/*/backend/*/.env' \
    --exclude 'projects/*/frontend/.env' \
    --exclude 'projects/*/proxy.conf' \
    --exclude 'projects/*/.proxy-port-*' \
    "$FORMATION_DIR/" "$SERVER:$REMOTE_ROOT/formation-playbooks/"
rsync -az --delete --exclude .git --exclude tmp \
    "$APPS_DIR/storage-service/" "$SERVER:$REMOTE_ROOT/storage-service/"

echo "Syncing rendered files..."
ssh "$SERVER" "mkdir -p '$REMOTE_PROJECT/backend/storage-service'"
scp -q "$PROJECT_DIR/docker-compose.yml" "$SERVER:$REMOTE_PROJECT/docker-compose.yml"
scp -q "$PROJECT_DIR/backend/storage-service/.env" "$SERVER:$REMOTE_PROJECT/backend/storage-service/.env"
ssh "$SERVER" "chmod 600 '$REMOTE_PROJECT/backend/storage-service/.env' && mkdir -p '$REMOTE_GATEWAY/routes'"
scp -q "$FORMATION_DIR/projects/gateway/routes/storage-service.yml" "$SERVER:$REMOTE_GATEWAY/routes/storage-service.yml"

echo "Building and starting on $SERVER..."
ssh "$SERVER" "cd '$REMOTE_PROJECT' && docker compose build && ./run-services.sh up"
ssh "$SERVER" "'$REMOTE_GATEWAY/run-services.sh' up"

echo "Checking storage-service responds..."
# No key, so 401 means it's up and enforcing auth. Checked directly and through
# the gateway (Host header, so it doesn't depend on DNS).
direct="$(ssh "$SERVER" "sleep 3; curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8083/storage/v1/files" || true)"
routed="$(ssh "$SERVER" "curl -s -o /dev/null -w '%{http_code}' -H 'Host: api.storage-service.home' http://127.0.0.1/storage/v1/files" || true)"
if [[ "$direct" == "401" && "$routed" == "401" ]]; then
    echo "storage-service is up, directly and via api.storage-service.home (401 without an API key, as expected)."
else
    echo "Unexpected responses — direct: '$direct', via gateway: '$routed'. Logs:" >&2
    ssh "$SERVER" "cd '$REMOTE_PROJECT' && docker compose logs --tail 30 storage-service; cd '$REMOTE_GATEWAY' && docker compose logs --tail 30 traefik" >&2
    exit 1
fi
