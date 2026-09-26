# Sourced by every deploy script. Sets SERVER and REMOTE_ROOT from, in order:
# the environment, then deploy.env at the repo root (gitignored; copy
# deploy.env.example), then REMOTE_ROOT's default. SERVER has no default.

_deploy_env="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/deploy.env"
_server="${SERVER:-}"
_remote_root="${REMOTE_ROOT:-}"
if [[ -f "$_deploy_env" ]]; then
    # shellcheck source=/dev/null
    source "$_deploy_env"
fi
SERVER="${_server:-${SERVER:-}}"
REMOTE_ROOT="${_remote_root:-${REMOTE_ROOT:-/opt/formation}}"
unset _server _remote_root

if [[ -z "$SERVER" ]]; then
    echo "No deploy server set. Either:" >&2
    echo "  cp deploy.env.example deploy.env   # at $(dirname "$_deploy_env"), then set SERVER" >&2
    echo "  SERVER=<ssh-host> $0 ..." >&2
    exit 1
fi
unset _deploy_env
