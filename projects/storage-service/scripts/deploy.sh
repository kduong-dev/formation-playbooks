#!/usr/bin/env bash
# Render locally, sync code + rendered files to the server, then build and
# start storage-service there and make sure the shared Traefik
# (infra/gateway) is up to route api.storage-service.home to it. Secrets
# never leave this machine except as the rendered .env; secrets.yml and
# .vault_pass are not synced.
#
# Server layout mirrors the local one, since the build context is the parent
# of formation-playbooks:
#   $REMOTE_ROOT/formation-playbooks/
#   $REMOTE_ROOT/storage-service/
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMATION_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
APPS_DIR="$(cd "$FORMATION_DIR/.." && pwd)"
source "$FORMATION_DIR/shared/scripts/deploy-target.sh"
REMOTE_PROJECT="$REMOTE_ROOT/formation-playbooks/projects/storage-service"
REMOTE_GATEWAY="$REMOTE_ROOT/formation-playbooks/infra/gateway"

echo "Rendering..."
"$PROJECT_DIR/run-services.sh" render

echo "Checking $SERVER:$REMOTE_ROOT..."
if ! ssh "$SERVER" "mkdir -p '$REMOTE_ROOT' && test -w '$REMOTE_ROOT'"; then
    echo "Can't write to $REMOTE_ROOT on $SERVER. Once, on the server:" >&2
    echo "  sudo mkdir -p $REMOTE_ROOT && sudo chown \$USER $REMOTE_ROOT" >&2
    exit 1
fi

echo "Syncing code..."
"$FORMATION_DIR/shared/scripts/sync-formation.sh" "$SERVER" "$REMOTE_ROOT"
rsync -az --delete --exclude .git --exclude tmp \
    "$APPS_DIR/storage-service/" "$SERVER:$REMOTE_ROOT/storage-service/"

echo "Syncing rendered files..."
ssh "$SERVER" "mkdir -p '$REMOTE_PROJECT/backend/api'"
scp -q "$PROJECT_DIR/docker-compose.yml" "$SERVER:$REMOTE_PROJECT/docker-compose.yml"
scp -q "$PROJECT_DIR/backend/api/.env" "$SERVER:$REMOTE_PROJECT/backend/api/.env"
ssh "$SERVER" "chmod 600 '$REMOTE_PROJECT/backend/api/.env' && mkdir -p '$REMOTE_GATEWAY/routes'"
scp -q "$FORMATION_DIR/infra/gateway/routes/storage-service.yml" "$SERVER:$REMOTE_GATEWAY/routes/storage-service.yml"

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
    ssh "$SERVER" "cd '$REMOTE_PROJECT' && docker compose logs --tail 30 api; cd '$REMOTE_GATEWAY' && docker compose logs --tail 30 traefik" >&2
    exit 1
fi
