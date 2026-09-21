#!/usr/bin/env bash
# Deploy pre-built images to the server. Aborts if the build isn't ready.
#
# TODO(migration): WORK_DIR still points at the old trading-formation
# server-side path — see the note in build.sh. Update once this project has
# cut over.
set -euo pipefail

SERVER="kduong-server"
STATUS_FILE="/opt/trading-core/.build-status"
WORK_DIR="/opt/trading-core/trading-formation"

main() {
    local status
    status=$(ssh "$SERVER" "cat $STATUS_FILE 2>/dev/null || echo 'none'")

    if [[ "$status" != ready* ]]; then
        echo "Build not ready (status: $status). Run ./scripts/build.sh first."
        return
    fi

    echo "Deploying to $SERVER..."
    ssh "$SERVER" "cd $WORK_DIR && ./run-services.sh up"
    echo "Deploy complete."
}

main "$@"
