#!/bin/bash
# Manage docker-compose for storage-service. Other projects' containers reach
# it over the shared `storage` network; everything else through the shared
# Traefik (infra/gateway) at api.storage-service.home.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_CMD=(docker compose -f "$SCRIPT_DIR/docker-compose.yml" --project-directory "$SCRIPT_DIR")
# Shared with other stacks; whichever starts first creates them.
SHARED_NETWORKS=(gateway storage)

ensure_networks() {
    for net in "${SHARED_NETWORKS[@]}"; do
        docker network inspect "$net" >/dev/null 2>&1 || docker network create "$net" >/dev/null
    done
}

usage() {
    cat <<EOF
Usage: $0 <command>

  render   Run the Ansible playbook to regenerate the .env file and
           docker-compose.yml from secrets.yml / services.yml / resources.yml / library.yml
  start    render, then build + up -d
  up       up -d (no rebuild)
  kill     down --remove-orphans
  delete   purge containers, images, volumes
EOF
}

case "${1:-}" in
    render)
        ansible-playbook playbook.yml
        ;;
    start)
        ansible-playbook playbook.yml
        ensure_networks
        "${COMPOSE_CMD[@]}" up -d --build --remove-orphans
        ;;
    up)
        ensure_networks
        "${COMPOSE_CMD[@]}" up -d --remove-orphans
        ;;
    kill)
        "${COMPOSE_CMD[@]}" down --remove-orphans
        ;;
    delete)
        "${COMPOSE_CMD[@]}" down --remove-orphans --rmi all --volumes
        ;;
    *)
        usage
        exit 1
        ;;
esac
