---
name: logs
description: This skill should be used when the user asks "show logs", "view logs", "what are the logs", "download logs", "debug my app", or wants to see application/job logs from TrueFoundry.
allowed-tools: Bash(*/tfy-api.sh *)
---

# Logs

View and download application and job logs from TrueFoundry.

## When to Use

- User asks "show logs", "view logs for my app"
- User wants to debug a deployment
- User says "what went wrong", "why did it fail"
- User asks to download logs for a time range
- After a deploy, to check if the app started correctly

## Download Logs

When using direct API, use the **full path** to this skill's `scripts/tfy-api.sh`. The path depends on which agent is installed (e.g. `~/.claude/skills/truefoundry-logs/scripts/tfy-api.sh` for Claude Code, `~/.cursor/skills/truefoundry-logs/scripts/tfy-api.sh` for Cursor). In the examples below, replace `TFY_API_SH` with the full path.

### Via MCP

```
tfy_logs_download(payload={
    "workspace_id": "ws-id",
    "application_fqn": "app-fqn",
    "start_ts": "2026-02-10T00:00:00Z",
    "end_ts": "2026-02-10T23:59:59Z"
})
```

### Via Direct API

```bash
# Set the path to tfy-api.sh for your agent (example for Claude Code):
TFY_API_SH=~/.claude/skills/truefoundry-logs/scripts/tfy-api.sh

# Download logs for an app in a workspace
$TFY_API_SH GET '/api/svc/v1/logs/WORKSPACE_ID/download?applicationFqn=APP_FQN&startTs=START&endTs=END'

# With search filter
$TFY_API_SH GET '/api/svc/v1/logs/WORKSPACE_ID/download?applicationId=APP_ID&searchString=error&searchType=contains'
```

### Parameters

| Parameter | API Key | Description |
|-----------|---------|-------------|
| `workspace_id` | (path) | Workspace ID (**required**) |
| `application_id` | `applicationId` | Filter by app ID |
| `application_fqn` | `applicationFqn` | Filter by app FQN |
| `deployment_id` | `deploymentId` | Filter by deployment |
| `job_run_name` | `jobRunName` | Filter by job run |
| `start_ts` | `startTs` | Start timestamp (ISO 8601) |
| `end_ts` | `endTs` | End timestamp (ISO 8601) |
| `search_string` | `searchString` | Search within logs |
| `search_type` | `searchType` | `contains`, `regex` |
| `pod_name` | `podName` | Filter by pod |

## Presenting Logs

Show logs in chronological order. For long output, show the last N lines or summarize errors:

```
Logs for tfy-mcp-server (last 20 lines):
2026-02-10 14:30:01 INFO  Server starting on port 8000
2026-02-10 14:30:02 INFO  MCP endpoint ready at /mcp
2026-02-10 14:30:05 INFO  Health check: OK
```

## Composability

- **Find app first**: Use `applications` skill to get app ID or FQN
- **Find workspace**: Use `workspaces` skill to get workspace ID
- **After deploy**: Check logs to verify the app started
- **Debug failures**: Download logs with `searchString=error`

## Error Handling

### Missing workspace_id
```
workspace_id is required for log downloads.
Use the workspaces skill to find your workspace ID.
```

### No Logs Found
```
No logs found for the given filters. Check:
- Time range is correct
- Application ID/FQN is correct
- The app has actually run during this period
```

### Permission Denied
```
Cannot access logs. Check your API key permissions for this workspace.
```
