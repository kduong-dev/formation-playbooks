#!/bin/bash
# Sourced by each project's run-services.sh, which sets SHARED_NETWORKS first.
# Manages the project's compose stack; all external traffic goes through the
# shared Traefik (infra/gateway) on :80.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMATION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"

COMPOSE_CMD=(docker compose -f "$PROJECT_DIR/docker-compose.yml" --project-directory "$PROJECT_DIR")

require_compose_file() {
    if [[ ! -f docker-compose.yml ]]; then
        echo "docker-compose.yml not found. Run './run-services.sh render' first." >&2
        exit 1
    fi
}

ensure_networks() {
    for net in "${SHARED_NETWORKS[@]}"; do
        docker network inspect "$net" >/dev/null 2>&1 || docker network create "$net" >/dev/null
    done
}

render() {
    local local_mode=localhost
    [[ "${1:-}" == "--local" ]] && local_mode=local
    ansible-playbook playbook.yml -e "local_mode=$local_mode"
}

# Every project's routes are served by the shared Traefik (infra/gateway), so
# without it nothing answers on :80. Starts it if it isn't already running.
ensure_gateway() {
    if [[ -z "$(docker ps -q \
        --filter label=com.docker.compose.project=gateway \
        --filter label=com.docker.compose.service=traefik)" ]]; then
        echo "Starting the shared gateway (infra/gateway)..."
        "$FORMATION_ROOT/infra/gateway/run-services.sh" up
    fi
}

bring_up() {
    local build_flag="${1:-}"
    require_compose_file
    ensure_networks
    ensure_gateway
    "${COMPOSE_CMD[@]}" up ${build_flag} -d --remove-orphans
}

usage() {
    cat <<EOF
Usage: $0 <command>

  render [--local]  Generate .env files, docker-compose.yml and Traefik routes
                    via ansible-playbook. Rendered URLs use the .localhost
                    domains by default, the server domains (*.home) with --local.
  start             render, then build + up -d
  up                up -d, no rebuild
  kill              down --remove-orphans
  delete            purge containers, images and volumes
EOF
}

case "${1:-}" in
    render) render "${2:-}" ;;
    start)
        render
        bring_up --build
        ;;
    up) bring_up ;;
    kill)   "${COMPOSE_CMD[@]}" down --remove-orphans ;;
    delete) "${COMPOSE_CMD[@]}" down --remove-orphans --rmi all --volumes ;;
    *)
        usage
        exit 1
        ;;
esac
