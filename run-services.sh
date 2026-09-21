#!/bin/bash
# Manage docker-compose for formation-playbooks. All external traffic goes
# through Traefik on :80 at <subdomain>.<domain>.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_CMD=(docker compose -f "$SCRIPT_DIR/docker-compose.yml" --project-directory "$SCRIPT_DIR")

usage() {
    cat <<EOF
Usage: $0 <command>

  render   Run the Ansible playbook to regenerate .env files, docker-compose.yml,
           and Traefik routes from secrets.yml / services.yml / resources.yml / library.yml
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
        "${COMPOSE_CMD[@]}" up -d --build
        ;;
    up)
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
