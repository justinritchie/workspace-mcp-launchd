#!/usr/bin/env bash
# Run taylorwilsdon/google_workspace_mcp ("workspace-mcp") for one Google
# account, sourcing config from ~/.mcp-credentials/google-<account>.env.
#
# Usage: ./start.sh <account>
#
# Required keys in the env file:
#   GOOGLE_OAUTH_CLIENT_ID="<client-id>.apps.googleusercontent.com"
#   GOOGLE_OAUTH_CLIENT_SECRET="GOCSPX-..."
#   USER_GOOGLE_EMAIL="user@example.com"
#   WORKSPACE_MCP_PORT=8001
#
# Required files alongside the env file:
#   ~/.mcp-credentials/google-<account>/client_secret.json
#   ~/.mcp-credentials/google-<account>/credentials/      (auto-created if missing —
#                                                          OAuth refresh tokens land here)
#
# Optional in the env file:
#   WORKSPACE_MCP_TOOLS  — space-separated list (default: "gmail drive calendar docs sheets tasks")
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <account>" >&2
  echo "  e.g. $0 personal" >&2
  exit 64
fi

ACCOUNT="$1"
ENV_FILE="${HOME}/.mcp-credentials/google-${ACCOUNT}.env"
CRED_DIR_PARENT="${HOME}/.mcp-credentials/google-${ACCOUNT}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: env file not found at $ENV_FILE" >&2
  exit 65
fi

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

: "${GOOGLE_OAUTH_CLIENT_ID:?must be set in $ENV_FILE}"
: "${GOOGLE_OAUTH_CLIENT_SECRET:?must be set in $ENV_FILE}"
: "${USER_GOOGLE_EMAIL:?must be set in $ENV_FILE}"
: "${WORKSPACE_MCP_PORT:?must be set in $ENV_FILE}"

# Resolve client_secret.json + credentials dir relative to the per-account
# subdirectory. Allows ENV-file overrides if needed.
export GOOGLE_CLIENT_SECRET_PATH="${GOOGLE_CLIENT_SECRET_PATH:-${CRED_DIR_PARENT}/client_secret.json}"
export GOOGLE_MCP_CREDENTIALS_DIR="${GOOGLE_MCP_CREDENTIALS_DIR:-${CRED_DIR_PARENT}/credentials}"
export OAUTHLIB_INSECURE_TRANSPORT="${OAUTHLIB_INSECURE_TRANSPORT:-1}"
export GOOGLE_OAUTH_REDIRECT_URI="${GOOGLE_OAUTH_REDIRECT_URI:-http://localhost:${WORKSPACE_MCP_PORT}/oauth2callback}"
export WORKSPACE_MCP_PORT="$WORKSPACE_MCP_PORT"

if [[ ! -f "$GOOGLE_CLIENT_SECRET_PATH" ]]; then
  echo "ERROR: client_secret.json not found at $GOOGLE_CLIENT_SECRET_PATH" >&2
  exit 65
fi
mkdir -p "$GOOGLE_MCP_CREDENTIALS_DIR"

# Tools default to all six (gmail/drive/calendar/docs/sheets/tasks)
TOOLS="${WORKSPACE_MCP_TOOLS:-gmail drive calendar docs sheets tasks}"

# Refuse to start if port is already bound.
if lsof -i ":$WORKSPACE_MCP_PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "Port $WORKSPACE_MCP_PORT is already in use. PID(s):"
  lsof -i ":$WORKSPACE_MCP_PORT" -sTCP:LISTEN
  exit 1
fi

echo "Starting google-${ACCOUNT} workspace-mcp on http://localhost:${WORKSPACE_MCP_PORT}/mcp"
echo "Account:        $USER_GOOGLE_EMAIL"
echo "Credentials:    $GOOGLE_MCP_CREDENTIALS_DIR"
echo "Tools:          $TOOLS"
echo

# shellcheck disable=SC2086
exec uvx workspace-mcp \
  --single-user \
  --transport streamable-http \
  --tools $TOOLS
