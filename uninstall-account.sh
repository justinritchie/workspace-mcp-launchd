#!/usr/bin/env bash
# Tear down a workspace-mcp account's launchd job and remove its plist.
# Credentials in ~/.mcp-credentials/google-<account>* are NOT touched.
#
# Usage: ./uninstall-account.sh <account>
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <account>" >&2
  exit 64
fi

ACCOUNT="$1"
USER_NAME="${USER:-user}"
LABEL="com.${USER_NAME}.workspace-mcp-${ACCOUNT}"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
GUI_DOMAIN="gui/$(id -u)"

if launchctl print "${GUI_DOMAIN}/${LABEL}" >/dev/null 2>&1; then
  launchctl bootout "${GUI_DOMAIN}/${LABEL}" || true
  echo "[ok] booted out ${LABEL}"
else
  echo "[noop] ${LABEL} was not loaded"
fi

if [[ -f "$PLIST_PATH" ]]; then
  rm "$PLIST_PATH"
  echo "[ok] removed $PLIST_PATH"
fi

echo
echo "Note: ~/.mcp-credentials/google-${ACCOUNT}* was NOT touched."
