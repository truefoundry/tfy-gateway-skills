---
name: status
description: This skill should be used when the user asks "is truefoundry connected", "check my truefoundry config", "truefoundry status", "am I authenticated", "test my TFY connection", "verify API key", "check TFY credentials", "is my TFY setup working", "TrueFoundry health check", "can I reach truefoundry", or wants to verify credentials, diagnose authentication issues, or confirm connectivity before any TrueFoundry operation.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

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

</objective>

<context>

## Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `TFY_BASE_URL` | TrueFoundry platform URL | `https://your-org.truefoundry.cloud` |
| `TFY_API_KEY` | API key (raw, no Bearer prefix) | `tfy-...` |
| `TFY_CLUSTER_ID` | (optional) Default cluster ID | `my-cluster` |

</context>

<instructions>

## Check Credentials

### Via MCP (if tfy-mcp-server is configured)

If the TrueFoundry MCP server is available, use the MCP tool:

```
tfy_config_status
```

This returns connection status, configured base URL, and whether an API key is set.

### Via Direct API

Check environment variables and test the connection. Set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

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
- Base URL: https://your-org.truefoundry.cloud ✓
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

</instructions>

<success_criteria>

- The user can confirm whether TFY_BASE_URL and TFY_API_KEY are correctly set
- The agent has tested the API connection with a lightweight call and reported the result
- The user can see a clear status summary showing which components are configured and which are missing
- The agent has provided actionable next steps if any credential or connectivity issue was found
- The user knows which skill to use next based on their goal (deploy, list workspaces, etc.)

</success_criteria>

<troubleshooting>

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

</troubleshooting>

<references>

## Composability

- **After status OK**: Use any other skill (workspaces, applications, deploy, etc.)
- **To set credentials**: Export env vars or create .env file
- **If using MCP**: Use `tfy_config_set` to persist credentials

</references>
