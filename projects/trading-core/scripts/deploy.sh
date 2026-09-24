#!/usr/bin/env bash
# Render locally for the server domains (*.home), sync code + rendered files
# to the server, then build and start trading-core there behind the shared
# Traefik (infra/gateway). Secrets never leave this machine except as the
# rendered .env files; secrets.yml and .vault_pass are not synced.
#
# Server layout mirrors the local one, since the build context is the parent
# of formation-playbooks:
#   $REMOTE_ROOT/formation-playbooks/
#   $REMOTE_ROOT/trading-core/trading-backend/
#   $REMOTE_ROOT/trading-core/trading-frontend/
#
# storage-service must be deployed too (projects/storage-service) for report
# uploads; the stacks can start in either order.
set -euo pipefail

SERVER="${SERVER:-kduong-server}"
REMOTE_ROOT="${REMOTE_ROOT:-/opt/formation}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORMATION_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"
APPS_DIR="$(cd "$FORMATION_DIR/.." && pwd)"
REMOTE_PROJECT="$REMOTE_ROOT/formation-playbooks/projects/trading-core"
REMOTE_GATEWAY="$REMOTE_ROOT/formation-playbooks/infra/gateway"
SERVICES=(account-service stock-screener authentication-service bot-service reporting-service journal-service)

echo "Rendering for the server domains..."
"$PROJECT_DIR/run-services.sh" render --local

echo "Checking $SERVER:$REMOTE_ROOT..."
if ! ssh "$SERVER" "mkdir -p '$REMOTE_ROOT/trading-core' && test -w '$REMOTE_ROOT'"; then
    echo "Can't write to $REMOTE_ROOT on $SERVER. Once, on the server:" >&2
    echo "  sudo mkdir -p $REMOTE_ROOT && sudo chown \$USER $REMOTE_ROOT" >&2
    exit 1
fi

echo "Syncing code..."
"$FORMATION_DIR/shared/scripts/sync-formation.sh" "$SERVER" "$REMOTE_ROOT"
# The backend's Makefile is rendered with secrets inlined, and local .env
# files would end up in the frontend image, so neither goes up.
rsync -az --delete --exclude .git --exclude tmp --exclude Makefile \
    "$APPS_DIR/trading-core/trading-backend/" "$SERVER:$REMOTE_ROOT/trading-core/trading-backend/"
rsync -az --delete --exclude .git --exclude node_modules --exclude .next --exclude '.env*' \
    "$APPS_DIR/trading-core/trading-frontend/" "$SERVER:$REMOTE_ROOT/trading-core/trading-frontend/"

echo "Syncing rendered files..."
dirs=("$REMOTE_PROJECT/frontend" "$REMOTE_GATEWAY/routes")
for svc in "${SERVICES[@]}"; do dirs+=("$REMOTE_PROJECT/backend/$svc"); done
ssh "$SERVER" "mkdir -p ${dirs[*]}"
scp -q "$PROJECT_DIR/docker-compose.yml" "$SERVER:$REMOTE_PROJECT/docker-compose.yml"
scp -q "$PROJECT_DIR/frontend/.env" "$SERVER:$REMOTE_PROJECT/frontend/.env"
for svc in "${SERVICES[@]}"; do
    scp -q "$PROJECT_DIR/backend/$svc/.env" "$SERVER:$REMOTE_PROJECT/backend/$svc/.env"
done
ssh "$SERVER" "chmod 600 '$REMOTE_PROJECT'/backend/*/.env '$REMOTE_PROJECT/frontend/.env'"
scp -q "$FORMATION_DIR/infra/gateway/routes/trading-core.yml" "$SERVER:$REMOTE_GATEWAY/routes/trading-core.yml"

echo "Building and starting on $SERVER..."
ssh "$SERVER" "cd '$REMOTE_PROJECT' && docker compose build && ./run-services.sh up"
ssh "$SERVER" "'$REMOTE_GATEWAY/run-services.sh' up"

echo "Checking trading-core responds..."
sleep 5
not_running="$(ssh "$SERVER" "cd '$REMOTE_PROJECT' && docker compose ps -a --format '{{.Service}} {{.State}}' | grep -v ' running\$'" || true)"
frontend="$(ssh "$SERVER" "curl -s -o /dev/null -w '%{http_code}' -H 'Host: trading-core.home' http://127.0.0.1/" || true)"
if [[ -z "$not_running" && "$frontend" == "200" ]]; then
    echo "trading-core is up: every container running, http://trading-core.home answers 200."
else
    echo "Not healthy — frontend via gateway: '$frontend'; containers not running:" >&2
    echo "${not_running:-(none)}" >&2
    ssh "$SERVER" "cd '$REMOTE_PROJECT' && docker compose logs --tail 20" >&2
    exit 1
fi
