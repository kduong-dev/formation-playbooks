#!/bin/bash
# Manage docker-compose for storage-service. There is no Traefik here: other
# projects' containers reach storage-service over the shared docker network.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_CMD=(docker compose -f "$SCRIPT_DIR/docker-compose.yml" --project-directory "$SCRIPT_DIR")
# Shared with the calling projects; each of their run-services.sh creates it too,
# so stacks can start in any order.
SHARED_NETWORK="storage"

ensure_network() {
    docker network inspect "$SHARED_NETWORK" >/dev/null 2>&1 || docker network create "$SHARED_NETWORK" >/dev/null
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
        ensure_network
        "${COMPOSE_CMD[@]}" up -d --build
        ;;
    up)
        ensure_network
        "${COMPOSE_CMD[@]}" up -d
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
