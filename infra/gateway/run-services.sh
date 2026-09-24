#!/bin/bash
# Manage the shared Traefik. Nothing to render: routes/<project>.yml files are
# written by each project's `run-services.sh render`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_CMD=(docker compose -f "$SCRIPT_DIR/docker-compose.yml" --project-directory "$SCRIPT_DIR")

usage() {
    cat <<EOF
Usage: $0 <command>

  up       up -d (creates the gateway network and routes/ if missing)
  kill     down --remove-orphans
  routes   List the route files Traefik is serving
  logs     Follow Traefik's logs
EOF
}

case "${1:-}" in
    up)
        docker network inspect gateway >/dev/null 2>&1 || docker network create gateway >/dev/null
        mkdir -p routes
        "${COMPOSE_CMD[@]}" up -d
        ;;
    kill)
        "${COMPOSE_CMD[@]}" down --remove-orphans
        ;;
    routes)
        ls -1 routes
        ;;
    logs)
        "${COMPOSE_CMD[@]}" logs -f traefik
        ;;
    *)
        usage
        exit 1
        ;;
esac
