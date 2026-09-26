#!/bin/bash
# Manage remarkable-shelf's stack; the commands live in shared/scripts/run-services.sh.

# Created by whichever stack starts first; infra/gateway's Traefik routes over it.
SHARED_NETWORKS=(gateway)

source "$(dirname "${BASH_SOURCE[0]}")/../../shared/scripts/run-services.sh"
