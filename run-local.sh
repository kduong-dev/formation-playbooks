#!/bin/bash
# Runs a command across every project, plus the shared gateway, on your own
# machine (the server deploys with the deploy scripts). storage-service goes
# first since other projects call it.
# dnsmasq is left out: it only runs on the server (infra/deploy.sh dnsmasq).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATEWAY="$ROOT/infra/gateway/run-services.sh"

projects() {
    local dir
    [[ -x "$ROOT/projects/storage-service/run-services.sh" ]] && echo storage-service
    for dir in "$ROOT"/projects/*/; do
        dir="$(basename "$dir")"
        [[ "$dir" != storage-service && -x "$ROOT/projects/$dir/run-services.sh" ]] && echo "$dir"
    done
}

usage() {
    cat <<EOF
Usage: $0 <command>

  start    gateway up, then every project's start (render + build + up -d)
  up       gateway up, then every project's up (no render, no rebuild)
  kill     every project's kill, then the gateway's
  status   running containers of every stack
EOF
}

failed=()

# Keeps going past a failing project so one bad stack doesn't block the rest.
run_projects() {
    local cmd="$1" project
    for project in $(projects); do
        echo "=== $project: $cmd"
        "$ROOT/projects/$project/run-services.sh" "$cmd" || failed+=("$project")
    done
}

case "${1:-}" in
    start|up)
        echo "=== gateway: up"
        "$GATEWAY" up || failed+=(gateway)
        run_projects "$1"
        ;;
    kill)
        run_projects kill
        echo "=== gateway: kill"
        "$GATEWAY" kill || failed+=(gateway)
        ;;
    status)
        docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
        ;;
    *)
        usage
        exit 1
        ;;
esac

if [[ ${#failed[@]} -gt 0 ]]; then
    echo "Failed: ${failed[*]}" >&2
    exit 1
fi
