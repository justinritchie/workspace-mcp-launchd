#!/usr/bin/env bash
# Stop a workspace-mcp account by killing whatever's bound to its port.
#
# Usage: ./stop.sh <account>
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <account>" >&2
  exit 64
fi

ACCOUNT="$1"
ENV_FILE="${HOME}/.mcp-credentials/google-${ACCOUNT}.env"
[[ -f "$ENV_FILE" ]] || { echo "ERROR: $ENV_FILE missing" >&2; exit 65; }

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a
: "${WORKSPACE_MCP_PORT:?must be set in $ENV_FILE}"

PIDS=$(lsof -i ":$WORKSPACE_MCP_PORT" -sTCP:LISTEN -t 2>/dev/null || true)
if [[ -z "$PIDS" ]]; then
  echo "Nothing on port $WORKSPACE_MCP_PORT for google-${ACCOUNT}."
  exit 0
fi
echo "Stopping google-${ACCOUNT} (PIDs: $PIDS)"
# shellcheck disable=SC2086
kill $PIDS; sleep 1
if lsof -i ":$WORKSPACE_MCP_PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
  # shellcheck disable=SC2086
  kill -9 $PIDS || true
fi
echo "Done."
