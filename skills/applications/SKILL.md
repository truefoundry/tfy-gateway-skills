---
name: applications
description: This skill should be used when the user asks "what's deployed", "list my apps", "show services", "deployment status", "is my app running", or wants to inspect application deployments on TrueFoundry. NOT for deploying local code — use deploy skill for that.
allowed-tools: Bash(*/tfy-api.sh *)
---

# Applications

List, inspect, and manage applications and deployments on TrueFoundry.

## When to Use

- User asks "what's deployed", "list apps", "show my services"
- User asks "is my app running", "deployment status"
- User asks to inspect a specific application or deployment
- User wants to create a deployment via API manifest
- Checking status after a deploy

## When NOT to Use

- User wants to deploy local code → use `deploy` skill
- User wants workspace/cluster info → use `workspaces` skill

## List Applications

When using direct API, use the **full path** to this skill's `scripts/tfy-api.sh`. The path depends on which agent is installed (e.g. `~/.claude/skills/truefoundry-applications/scripts/tfy-api.sh` for Claude Code, `~/.cursor/skills/truefoundry-applications/scripts/tfy-api.sh` for Cursor). In the examples below, replace `TFY_API_SH` with the full path.

### Via MCP

```
tfy_applications_list()
tfy_applications_list(filters={"workspace_fqn": "tfy-ea-dev-eo-az:my-ws"})
tfy_applications_list(filters={"application_name": "my-app"})
tfy_applications_list(app_id="app-id-here")
```

### Via Direct API

```bash
# Set the path to tfy-api.sh for your agent (example for Claude Code):
TFY_API_SH=~/.claude/skills/truefoundry-applications/scripts/tfy-api.sh

# List all
$TFY_API_SH GET /api/svc/v1/apps

# Filter by workspace
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=tfy-ea-dev-eo-az:my-ws'

# Filter by name
$TFY_API_SH GET '/api/svc/v1/apps?applicationName=my-app'

# Get by ID
$TFY_API_SH GET /api/svc/v1/apps/APP_ID
```

### Filter Parameters

| Parameter | API Key | Description |
|-----------|---------|-------------|
| `workspace_fqn` | `workspaceFqn` | Filter by workspace FQN |
| `application_name` | `applicationName` | Filter by app name |
| `cluster_id` | `clusterId` | Filter by cluster |
| `application_type` | `applicationType` | Filter: service, job, etc. |
| `name_search_query` | `nameSearchQuery` | Search by name substring |

## Presenting Applications

Show as a table. Use `updatedAt` from the API response for "Last Deployed" (ISO 8601 timestamp — format as date/time for readability). Use `kind` for Type and `status` for Status.

```
Applications in tfy-ea-dev-eo-az:my-ws:
| Name           | Type    | Status   | Last Deployed      |
|----------------|---------|----------|--------------------|
| tfy-mcp-server | service | RUNNING  | 2026-02-10 14:30   |
| data-pipeline  | job     | STOPPED  | 2026-02-08 09:15   |
```

## List Deployments

### Via MCP

```
tfy_applications_list_deployments(app_id="app-id")
tfy_applications_list_deployments(app_id="app-id", deployment_id="dep-id")
```

### Via Direct API

```bash
# List deployments for an app
$TFY_API_SH GET /api/svc/v1/apps/APP_ID/deployments

# Get specific deployment
$TFY_API_SH GET /api/svc/v1/apps/APP_ID/deployments/DEPLOYMENT_ID
```

## Create Deployment (API)

For creating a deployment via API manifest (advanced — most users should use the `deploy` skill).

**Use this section when:**
- User has their own manifest/JSON and wants direct API deployment
- User explicitly requests API-based deployment instead of SDK/Python
- User wants to deploy from a pre-built image (not local code)

**For deploying local code, use the `deploy` skill instead.**

### Service Manifest Structure

A basic TrueFoundry service manifest looks like this:

```json
{
  "manifest": {
    "kind": "Service",
    "name": "my-app",
    "image": {
      "type": "image",
      "image_uri": "nginx:latest"
    },
    "ports": [
      {
        "port": 8000,
        "protocol": "TCP",
        "expose": false
      }
    ],
    "resources": {
      "cpu_request": 0.25,
      "cpu_limit": 0.5,
      "memory_request": 256,
      "memory_limit": 512
    },
    "env": {
      "KEY": "value",
      "ANOTHER_KEY": "another_value"
    },
    "replicas": {
      "min": 1,
      "max": 1
    }
  },
  "workspaceId": "ws-id-here"
}
```

**Key Fields:**
- `kind` — "Service" for long-running services, "Job" for batch jobs
- `name` — Unique application name
- `image.image_uri` — Docker image (e.g., `nginx:latest`, `ghcr.io/org/app:v1.0`)
- `ports` — Array of port configs (port, protocol, expose flag)
- `resources` — CPU (cores) and memory (MB) requests/limits
- `env` — Environment variables as key-value pairs
- `replicas` — Min/max replica count (for autoscaling)
- `workspaceId` — Workspace ID (not FQN) where the app will be deployed

### Before Submitting

**ALWAYS confirm with the user before creating a deployment:**

1. **Service name** — What should the app be called?
2. **Image** — Full image URI (e.g., `nginx:latest`, `ghcr.io/user/app:tag`)
3. **Resources** — CPU request/limit (cores), memory request/limit (MB)
4. **Ports** — Which ports to expose, protocols (TCP/UDP), expose to internet?
5. **Environment variables** — Any env vars needed? (API keys, config values)
6. **Replicas** — How many instances? (min/max for autoscaling)
7. **Workspace ID** — Which workspace to deploy to?

Present this summary and ask for confirmation before making the API call.

### Via MCP

```
tfy_applications_create_deployment(
    manifest={
        "kind": "Service",
        "name": "my-app",
        "image": {"type": "image", "image_uri": "nginx:latest"},
        "ports": [{"port": 8000, "protocol": "TCP", "expose": false}],
        "resources": {"cpu_request": 0.25, "cpu_limit": 0.5, "memory_request": 256, "memory_limit": 512},
        "env": {"KEY": "value"},
        "replicas": {"min": 1, "max": 1}
    },
    options={"workspace_id": "ws-id-here", "force_deploy": true}
)
```

**Note:** This requires human approval (HITL) when using MCP.

### Via Direct API

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "kind": "Service",
    "name": "my-app",
    "image": {"type": "image", "image_uri": "nginx:latest"},
    "ports": [{"port": 8000, "protocol": "TCP", "expose": false}],
    "resources": {"cpu_request": 0.25, "cpu_limit": 0.5, "memory_request": 256, "memory_limit": 512},
    "env": {"KEY": "value"},
    "replicas": {"min": 1, "max": 1}
  },
  "workspaceId": "ws-id-here"
}'
```

### Common Deployment Patterns

**Web service (exposed to internet with public URL):**

The `host` must match one of the cluster's `base_domains`. Look up base domains first:
```bash
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
# → look for base_domains, pick the wildcard one (e.g., "*.ml.tfy-eo.truefoundry.cloud")
# → strip "*." to get the base domain: "ml.tfy-eo.truefoundry.cloud"
# → construct host: "{service-name}-{workspace-name}.{base_domain}"
```

```json
{
  "ports": [{
    "port": 8080,
    "protocol": "TCP",
    "expose": true,
    "host": "my-app-dev-ws.ml.tfy-eo.truefoundry.cloud",
    "app_protocol": "http"
  }],
  "replicas": {"min": 2, "max": 5}
}
```

**If `host` does not match a cluster base domain, deploy will fail with: "Provided host is not configured in cluster".**

**Internal service (not exposed):**
```json
{
  "ports": [{"port": 8000, "protocol": "TCP", "expose": false}],
  "replicas": {"min": 1, "max": 1}
}
```

**Resource-intensive service:**
```json
{
  "resources": {
    "cpu_request": 1.0,
    "cpu_limit": 2.0,
    "memory_request": 2048,
    "memory_limit": 4096
  }
}
```

## Composability

- **After listing apps**: Use `logs` skill to check logs, `deploy` skill to redeploy
- **After deploy**: Use this skill to verify the deployment succeeded
- **Check jobs**: Use `jobs` skill for job-specific run details
- **Find workspace first**: Use `workspaces` skill to get workspace FQN for filtering

## Error Handling

### No Applications Found
```
No applications found. Check:
- Workspace FQN is correct
- You have apps deployed in this workspace
- Your API key has access to this workspace
```

### Application Not Found
```
Application ID not found. List apps first to find the correct ID.
```

### Permission Denied
```
Cannot access this application. Check your API key permissions.
```
