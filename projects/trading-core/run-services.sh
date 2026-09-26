#!/bin/bash
# Manage trading-core's stack; the commands live in shared/scripts/run-services.sh.

# `gateway` is the shared Traefik's network; `storage` is joined by services that
# call storage-service. Whichever stack starts first creates them.
SHARED_NETWORKS=(gateway storage)

source "$(dirname "${BASH_SOURCE[0]}")/../../shared/scripts/run-services.sh"
