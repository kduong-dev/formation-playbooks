#!/bin/bash
# Manage storage-service's stack; the commands live in shared/scripts/run-services.sh.
# Other projects' containers reach it over the shared `storage` network.

# Shared with other stacks; whichever starts first creates them.
SHARED_NETWORKS=(gateway storage)

source "$(dirname "${BASH_SOURCE[0]}")/../../shared/scripts/run-services.sh"
