# workspace-mcp-launchd

Launchd-managed wrappers for [taylorwilsdon/google_workspace_mcp](https://github.com/taylorwilsdon/google_workspace_mcp) (the `workspace-mcp` package), letting you run multiple Google accounts in parallel — each as its own long-lived service on its own port — with credentials sourced from per-account env files outside this repo.

This repo contains **no upstream code** and **no credentials**. Just the glue.

## Why this exists

`workspace-mcp` is a great Google MCP, but it's designed around one Google account per process. If you have several (work, personal, side project, client account…) and want them all live in Claude Desktop without a configuration shuffle, you need:

1. Multiple processes, each with its own OAuth client + refresh tokens, on different ports.
2. Each process running as a long-lived service so you're not babysitting terminal windows.
3. Credentials kept out of any shared / public repo.
4. Streamable-HTTP transport (not stdio) — `workspace-mcp` 3.2.4's stdio mode has a [broken OAuth callback state cache](https://github.com/taylorwilsdon/google_workspace_mcp/issues) where the tool-call handler and the minimal OAuth server it spins up don't share state, so consent redirects fail with "Invalid or expired OAuth state parameter". Streamable-HTTP uses a unified server and the auth flow Just Works.

This wrapper handles all four. Same launchd-managed pattern as my other MCP repos ([craft-mcp](https://github.com/justinritchie/craft-mcp), [xenetwork-wordpress-mcp](https://github.com/justinritchie/xenetwork-wordpress-mcp)) so the muscle memory transfers.

## Layout

```
workspace-mcp-launchd/
├── README.md
├── SETUP_NEW_MACHINE.md           # full new-machine runbook
├── LICENSE                        # MIT
├── start.sh <account>             # source env, exec uvx workspace-mcp
├── stop.sh <account>              # kill the listener
├── setup-account.sh <account>     # generate launchd plist + load it
├── uninstall-account.sh <account> # bootout + remove plist
├── templates/
│   └── launchd.plist.template
├── google-account.env.example     # template for per-account env file
└── .gitignore
```

## Setup

```bash
# Prereqs
brew install uv node                  # uvx + npx (npx is for mcp-remote later)
npm install -g mcp-remote             # only needed for Claude Desktop integration

# Clone this repo
git clone https://github.com/justinritchie/workspace-mcp-launchd.git \
  ~/justinritchie-mcp-servers/workspace-mcp-launchd
```

For each Google account you want to wire up:

```bash
mkdir -p ~/.mcp-credentials/google-<account>/credentials
chmod 700 ~/.mcp-credentials

# Drop OAuth client config from Google Cloud Console
cp /path/to/your/client_secret.json ~/.mcp-credentials/google-<account>/client_secret.json
chmod 600 ~/.mcp-credentials/google-<account>/client_secret.json

# Create the env file (copy + edit google-account.env.example)
cat > ~/.mcp-credentials/google-<account>.env <<'EOF'
GOOGLE_OAUTH_CLIENT_ID="...-...apps.googleusercontent.com"
GOOGLE_OAUTH_CLIENT_SECRET="GOCSPX-..."
USER_GOOGLE_EMAIL="you@example.com"
WORKSPACE_MCP_PORT=8001
EOF
chmod 600 ~/.mcp-credentials/google-<account>.env

# Install as a launchd service
cd ~/justinritchie-mcp-servers/workspace-mcp-launchd
./setup-account.sh <account>
```

Then add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
"google-<account>": {
  "command": "/opt/homebrew/bin/mcp-remote",
  "args": ["http://localhost:8001/mcp", "--allow-http"]
}
```

⌘Q + relaunch Claude Desktop. The first tool call against this account will trigger an OAuth consent flow in your browser; the refresh token gets cached at `~/.mcp-credentials/google-<account>/credentials/<email>.json` and reused thereafter.

## Why credentials live outside the repo

- The OAuth `client_secret.json` files are tied to specific Google Cloud projects you control. They shouldn't be in any shared repo.
- The `credentials/` subdirectory contains OAuth refresh tokens — per-machine, per-Google-account auth state.
- Public scaffolding + private credentials is the same pattern used in [craft-mcp](https://github.com/justinritchie/craft-mcp) / [mcp-credentials](#) (private repo).

A typical "private credentials" layout for several services looks like:

```
~/.mcp-credentials/
├── README.md
├── .gitignore                     # excludes */credentials/, *.json (transient OAuth tokens)
├── google-personal.env
├── google-personal/
│   ├── client_secret.json         # tracked
│   └── credentials/               # gitignored — refresh tokens
├── google-work.env
├── google-work/
│   ├── client_secret.json
│   └── credentials/
├── craft-personal.env             # other MCPs' env files
├── wordpress-root.env
└── ...
```

## Logs

```bash
tail -f /tmp/workspace-mcp-<account>.out.log
tail -f /tmp/workspace-mcp-<account>.err.log
```

## License

[MIT](LICENSE).
