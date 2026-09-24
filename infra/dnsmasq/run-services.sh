#!/bin/bash
# Manage the LAN DNS server. dnsmasq only reads dnsmasq.conf at startup, so
# `up` recreates the container to pick up config changes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_CMD=(docker compose -f "$SCRIPT_DIR/docker-compose.yml" --project-directory "$SCRIPT_DIR")

usage() {
    cat <<EOF
Usage: $0 <command>

  up       up -d, recreating the container so dnsmasq.conf changes apply
  kill     down --remove-orphans
  logs     Follow dnsmasq's logs
EOF
}

case "${1:-}" in
    up)
        "${COMPOSE_CMD[@]}" up -d --force-recreate
        ;;
    kill)
        "${COMPOSE_CMD[@]}" down --remove-orphans
        ;;
    logs)
        "${COMPOSE_CMD[@]}" logs -f dnsmasq
        ;;
    *)
        usage
        exit 1
        ;;
esac
