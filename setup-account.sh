#!/usr/bin/env bash
# Wire up one Google Workspace account as a launchd-managed workspace-mcp.
#
# Usage: ./setup-account.sh <account>
#
# Prerequisites:
#   1. brew install uv && brew install node   (uvx + npx — npx is for mcp-remote later)
#   2. ~/.mcp-credentials/google-<account>.env with the OAuth + port config
#   3. ~/.mcp-credentials/google-<account>/client_secret.json from Google Cloud Console
#
# Idempotent.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <account>" >&2
  exit 64
fi

ACCOUNT="$1"
HERE="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${HOME}/.mcp-credentials/google-${ACCOUNT}.env"
CLIENT_SECRET="${HOME}/.mcp-credentials/google-${ACCOUNT}/client_secret.json"
TEMPLATE="$HERE/templates/launchd.plist.template"

USER_NAME="${USER:-user}"
LABEL="com.${USER_NAME}.workspace-mcp-${ACCOUNT}"
PLIST_DEST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
GUI_DOMAIN="gui/$(id -u)"

# Pre-flight checks
[[ -f "$ENV_FILE" ]] || { echo "ERROR: $ENV_FILE not found"; exit 65; }
[[ -f "$CLIENT_SECRET" ]] || { echo "ERROR: $CLIENT_SECRET not found"; exit 65; }
[[ -f "$TEMPLATE" ]] || { echo "ERROR: template missing at $TEMPLATE"; exit 1; }
command -v uvx >/dev/null 2>&1 || { echo "ERROR: 'uvx' not in PATH (brew install uv)"; exit 1; }

# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a
: "${WORKSPACE_MCP_PORT:?must be set in $ENV_FILE}"
: "${USER_GOOGLE_EMAIL:?must be set in $ENV_FILE}"

chmod +x "$HERE/start.sh" "$HERE/stop.sh"
chmod 600 "$CLIENT_SECRET"
mkdir -p "${HOME}/.mcp-credentials/google-${ACCOUNT}/credentials"

# Generate plist from template
mkdir -p "${HOME}/Library/LaunchAgents"
TMP_PLIST="$(mktemp)"
trap 'rm -f "$TMP_PLIST"' EXIT
sed -e "s|__LABEL__|${LABEL}|g" \
    -e "s|__REPO_ROOT__|${HERE}|g" \
    -e "s|__ACCOUNT__|${ACCOUNT}|g" \
    "$TEMPLATE" > "$TMP_PLIST"
mv "$TMP_PLIST" "$PLIST_DEST"
trap - EXIT
echo "[ok] wrote $PLIST_DEST"

# Reload launchd job
launchctl bootout "${GUI_DOMAIN}/${LABEL}" 2>/dev/null || true
sleep 1
launchctl bootstrap "${GUI_DOMAIN}" "$PLIST_DEST"
echo "[ok] launchd job loaded: ${LABEL}"

# Wait for port
echo -n "Waiting for workspace-mcp on port ${WORKSPACE_MCP_PORT}"
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  if lsof -i ":${WORKSPACE_MCP_PORT}" -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo
    echo "[ok] workspace-mcp ${ACCOUNT} (${USER_GOOGLE_EMAIL}) listening on http://localhost:${WORKSPACE_MCP_PORT}/mcp"
    echo
    echo "Logs:"
    echo "  tail -f /tmp/workspace-mcp-${ACCOUNT}.out.log"
    echo "  tail -f /tmp/workspace-mcp-${ACCOUNT}.err.log"
    echo
    echo "Wire into Claude Desktop:"
    echo "  \"google-${ACCOUNT}\": {"
    echo "    \"command\": \"/opt/homebrew/bin/mcp-remote\","
    echo "    \"args\": [\"http://localhost:${WORKSPACE_MCP_PORT}/mcp\", \"--allow-http\"]"
    echo "  }"
    exit 0
  fi
  echo -n "."
  sleep 1
done
echo
echo "WARNING: server didn't come up within 15s. Check logs:"
echo "  tail -100 /tmp/workspace-mcp-${ACCOUNT}.err.log"
exit 2
