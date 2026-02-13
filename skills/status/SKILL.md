---
name: status
description: This skill should be used when the user asks "is truefoundry connected", "check my truefoundry config", "truefoundry status", "am I authenticated", or wants to verify credentials before any TrueFoundry operation.
allowed-tools: Bash(*/tfy-api.sh *)
---

# TrueFoundry Status

Check TrueFoundry connection and verify credentials are configured.

## When to Use

- User asks about TrueFoundry connection status
- Before any TrueFoundry operation (deploy, list apps, etc.)
- User says "check my TFY config", "am I connected to TrueFoundry"
- Troubleshooting authentication issues

## When NOT to Use

- User wants to list workspaces → use `workspaces` skill
- User wants to deploy → use `deploy` skill
- User wants to see running apps → use `applications` skill

## Check Credentials

### Via MCP (if tfy-mcp-server is configured)

If the TrueFoundry MCP server is available, use the MCP tool:

```
tfy_config_status
```

This returns connection status, configured base URL, and whether an API key is set.

### Via Direct API

Check environment variables and test the connection. Use the **full path** to this skill's `scripts/tfy-api.sh` when your CWD is the project root. The path depends on which agent is installed:

- Claude Code: `~/.claude/skills/truefoundry-status/scripts/tfy-api.sh`
- Cursor: `~/.cursor/skills/truefoundry-status/scripts/tfy-api.sh`
- OpenCode: `~/.opencode/skills/truefoundry-status/scripts/tfy-api.sh`
- Codex: `~/.codex/skills/truefoundry-status/scripts/tfy-api.sh`

```bash
# Check env vars are set
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"

# Test connection — list workspaces (lightweight call). Use full path shown above.
# Example for Claude Code:
~/.claude/skills/truefoundry-status/scripts/tfy-api.sh GET '/api/svc/v1/workspaces?limit=1'
```

### Via .env File

If env vars are not set, check for a `.env` file:

```bash
[ -f .env ] && echo ".env found" || echo "No .env file"
```

## Presenting Status

```
TrueFoundry Status:
- Base URL: https://tfy-eo.truefoundry.cloud ✓
- API Key: configured ✓
- Connection: OK (listed 1 workspace)
```

Or if something is wrong:

```
TrueFoundry Status:
- Base URL: (not set) ✗
- API Key: (not set) ✗

Set TFY_BASE_URL and TFY_API_KEY in your environment or .env file.
Get an API key: https://docs.truefoundry.com/docs/generating-truefoundry-api-keys
```

## Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `TFY_BASE_URL` | TrueFoundry platform URL | `https://tfy-eo.truefoundry.cloud` |
| `TFY_API_KEY` | API key (raw, no Bearer prefix) | `tfy-...` |
| `TFY_CLUSTER_ID` | (optional) Default cluster ID | `tfy-ea-dev-eo-az` |

## Error Handling

### 401 Unauthorized
```
API key is invalid or expired. Generate a new one:
https://docs.truefoundry.com/docs/generating-truefoundry-api-keys
```

### Connection Refused / Timeout
```
Cannot reach TFY_BASE_URL. Check:
- URL is correct (include https://)
- Network/VPN is connected
```

### Missing Variables
```
TFY_BASE_URL and TFY_API_KEY are required.
Set them via environment variables or add to .env in project root.
```

## Composability

- **After status OK**: Use any other skill (workspaces, applications, deploy, etc.)
- **To set credentials**: Export env vars or create .env file
- **If using MCP**: Use `tfy_config_set` to persist credentials
