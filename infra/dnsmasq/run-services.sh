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

# dnsmasq binds only to the interface in dnsmasq.conf and exits when it's
# missing, which restart: unless-stopped turns into a loop. It only exists on
# the server, so anywhere else (e.g. Docker Desktop) refuse up front.
require_interface() {
    local iface
    iface="$(sed -n 's/^interface=//p' dnsmasq.conf | head -n1)"
    if [[ -n "$iface" && ! -e "/sys/class/net/$iface" ]]; then
        echo "No '$iface' interface here: dnsmasq only runs on the server." >&2
        echo "Deploy it from your machine with: infra/deploy.sh dnsmasq" >&2
        exit 1
    fi
}

case "${1:-}" in
    up)
        require_interface
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
