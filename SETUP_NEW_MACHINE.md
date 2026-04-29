# Setting up workspace-mcp-launchd on a new machine

Step-by-step for bringing a fresh Mac up to speed across N Google accounts.

## 1. Prerequisites

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"  # if not installed
brew install uv node
npm install -g mcp-remote
```

## 2. Get the wrapper code

```bash
mkdir -p ~/justinritchie-mcp-servers
cd ~/justinritchie-mcp-servers
git clone https://github.com/justinritchie/workspace-mcp-launchd.git
```

## 3. Place credentials

For each account, you need three things in `~/.mcp-credentials/`:

```bash
mkdir -p ~/.mcp-credentials
chmod 700 ~/.mcp-credentials

# Per-account env file:
cat > ~/.mcp-credentials/google-personal.env <<'EOF'
GOOGLE_OAUTH_CLIENT_ID="...apps.googleusercontent.com"
GOOGLE_OAUTH_CLIENT_SECRET="GOCSPX-..."
USER_GOOGLE_EMAIL="you@example.com"
WORKSPACE_MCP_PORT=8001
EOF
chmod 600 ~/.mcp-credentials/google-personal.env

# Per-account OAuth client config (download from Google Cloud Console):
mkdir -p ~/.mcp-credentials/google-personal/credentials
cp /path/to/downloaded/client_secret*.json ~/.mcp-credentials/google-personal/client_secret.json
chmod 600 ~/.mcp-credentials/google-personal/client_secret.json
```

If you keep credentials in a private repo cloned to `~/.mcp-credentials/`, this is already done.

## 4. Install each account

```bash
cd ~/justinritchie-mcp-servers/workspace-mcp-launchd
./setup-account.sh personal
./setup-account.sh xenetwork
./setup-account.sh jumbo
# ... one per account
```

Each invocation generates `~/Library/LaunchAgents/com.<user>.workspace-mcp-<account>.plist` and loads it. Idempotent.

## 5. Wire Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
"mcpServers": {
  "google-personal":  { "command": "/opt/homebrew/bin/mcp-remote", "args": ["http://localhost:8001/mcp", "--allow-http"] },
  "google-xenetwork": { "command": "/opt/homebrew/bin/mcp-remote", "args": ["http://localhost:8000/mcp", "--allow-http"] },
  "google-jumbo":     { "command": "/opt/homebrew/bin/mcp-remote", "args": ["http://localhost:8002/mcp", "--allow-http"] }
}
```

⌘Q + relaunch Claude Desktop.

## 6. First-time auth (per account)

If you didn't bring the OAuth refresh tokens with you (they normally live at `~/.mcp-credentials/google-<account>/credentials/<email>.json` and are gitignored as per-machine state), the first tool call against an account will return an auth URL. Open it in your browser, grant consent, and the refresh token gets cached. Subsequent calls work without prompting.

## 7. Verify

```bash
# Quick health check (HTTP 406 means up + expects MCP-formatted requests)
for port in 8000 8001 8002; do curl -sI http://localhost:$port/mcp | head -1; done

# Launchd jobs
launchctl list | grep workspace-mcp

# Logs
tail -50 /tmp/workspace-mcp-personal.err.log
```

## Updating

```bash
cd ~/justinritchie-mcp-servers/workspace-mcp-launchd
git pull

# Reload all accounts
for acc in personal xenetwork jumbo; do ./setup-account.sh $acc; done
```

`uvx workspace-mcp` always grabs the latest published version, so updates to the upstream Google MCP are picked up on next process restart.

## Troubleshooting

**Port already in use** — change `WORKSPACE_MCP_PORT` in the env file and re-run `setup-account.sh`. If it's an old launchd job from a previous setup, find and bootout: `launchctl list | grep workspace-mcp`.

**OAuth flow loops to "Invalid or expired OAuth state parameter"** — this is the upstream stdio bug. Make sure you're using the streamable-http path (which `start.sh` defaults to). If you somehow ended up on stdio, that's why; switch back.

**`401: invalid_client`** — `GOOGLE_OAUTH_CLIENT_ID` or `..._CLIENT_SECRET` doesn't match the `client_secret.json`. Double-check both came from the same Google Cloud project / OAuth client.

**Server didn't come up within 15s** — `uvx workspace-mcp` is downloading the package on first run. Wait 30s and re-check. If still nothing, `tail -100 /tmp/workspace-mcp-<account>.err.log`.
