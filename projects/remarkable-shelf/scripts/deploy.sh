#!/usr/bin/env bash
# Render locally, sync code + rendered files to the server, then build and
# start remarkable-shelf there behind the shared Traefik (infra/gateway).
# Secrets never leave this machine except as the rendered .env; secrets.yml
# and .vault_pass are not synced.
#
# Server layout mirrors the local one, since the build context is the parent
# of formation-playbooks:
#   $REMOTE_ROOT/formation-playbooks/
#   $REMOTE_ROOT/reMarkableShelf/backend/
#   $REMOTE_ROOT/reMarkableShelf/frontend/
#
# storage-service must be deployed too (projects/storage-service), with this
# project's key hash in its storage_clients_b64_json, for book files; the
# stacks can start in either order.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMATION_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
APPS_DIR="$(cd "$FORMATION_DIR/.." && pwd)"
source "$FORMATION_DIR/shared/scripts/deploy-target.sh"
REMOTE_PROJECT="$REMOTE_ROOT/formation-playbooks/projects/remarkable-shelf"
REMOTE_GATEWAY="$REMOTE_ROOT/formation-playbooks/infra/gateway"

# The frontend calls its API by relative path, so nothing rendered depends on
# the domain; routes cover both remarkable-shelf.home and .localhost.
echo "Rendering..."
"$PROJECT_DIR/run-services.sh" render

echo "Checking $SERVER:$REMOTE_ROOT..."
if ! ssh "$SERVER" "mkdir -p '$REMOTE_ROOT/reMarkableShelf' && test -w '$REMOTE_ROOT'"; then
    echo "Can't write to $REMOTE_ROOT on $SERVER. Once, on the server:" >&2
    echo "  sudo mkdir -p $REMOTE_ROOT && sudo chown \$USER $REMOTE_ROOT" >&2
    exit 1
fi

echo "Syncing code..."
"$FORMATION_DIR/shared/scripts/sync-formation.sh" "$SERVER" "$REMOTE_ROOT"
rsync -az --delete --exclude .git --exclude tmp \
    "$APPS_DIR/reMarkableShelf/backend/" "$SERVER:$REMOTE_ROOT/reMarkableShelf/backend/"
rsync -az --delete --exclude .git --exclude node_modules --exclude dist --exclude '.env*' \
    "$APPS_DIR/reMarkableShelf/frontend/" "$SERVER:$REMOTE_ROOT/reMarkableShelf/frontend/"

echo "Syncing rendered files..."
ssh "$SERVER" "mkdir -p '$REMOTE_PROJECT/backend/server' '$REMOTE_GATEWAY/routes'"
scp -q "$PROJECT_DIR/docker-compose.yml" "$SERVER:$REMOTE_PROJECT/docker-compose.yml"
scp -q "$PROJECT_DIR/backend/server/.env" "$SERVER:$REMOTE_PROJECT/backend/server/.env"
ssh "$SERVER" "chmod 600 '$REMOTE_PROJECT/backend/server/.env'"
scp -q "$FORMATION_DIR/infra/gateway/routes/remarkable-shelf.yml" "$SERVER:$REMOTE_GATEWAY/routes/remarkable-shelf.yml"

echo "Building and starting on $SERVER..."
ssh "$SERVER" "cd '$REMOTE_PROJECT' && docker compose build && ./run-services.sh up"
ssh "$SERVER" "'$REMOTE_GATEWAY/run-services.sh' up"

echo "Checking remarkable-shelf responds..."
sleep 5
not_running="$(ssh "$SERVER" "cd '$REMOTE_PROJECT' && docker compose ps -a --format '{{.Service}} {{.State}}' | grep -v ' running\$'" || true)"
frontend="$(ssh "$SERVER" "curl -s -o /dev/null -w '%{http_code}' -H 'Host: remarkable-shelf.home' http://127.0.0.1/" || true)"
api="$(ssh "$SERVER" "curl -s -o /dev/null -w '%{http_code}' -H 'Host: remarkable-shelf.home' http://127.0.0.1/api/books" || true)"
if [[ -z "$not_running" && "$frontend" == "200" && "$api" == "200" ]]; then
    echo "remarkable-shelf is up: every container running, http://remarkable-shelf.home and /api/books answer 200."
else
    echo "Not healthy — frontend: '$frontend', /api/books: '$api'; containers not running:" >&2
    echo "${not_running:-(none)}" >&2
    ssh "$SERVER" "cd '$REMOTE_PROJECT' && docker compose logs --tail 20" >&2
    exit 1
fi
