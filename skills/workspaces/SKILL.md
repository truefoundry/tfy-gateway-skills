---
name: workspaces
description: This skill should be used when the user asks "list workspaces", "show clusters", "what workspaces are available", "which workspace", or needs a workspace FQN for deployment or filtering.
allowed-tools: Bash(*/tfy-api.sh *)
---

# Workspaces & Clusters

List TrueFoundry workspaces and clusters. Workspaces are the deploy targets; clusters are the underlying infrastructure.

## When to Use

- User asks "list workspaces", "show my workspaces", "which workspace"
- User needs a `workspace_fqn` for deploy or filtering
- User asks "list clusters", "show clusters", "cluster status"
- Before deploying, to confirm target workspace

## List Workspaces

When using direct API, use the **full path** to this skill's `scripts/tfy-api.sh`. The path depends on which agent is installed (e.g. `~/.claude/skills/truefoundry-workspaces/scripts/tfy-api.sh` for Claude Code, `~/.cursor/skills/truefoundry-workspaces/scripts/tfy-api.sh` for Cursor). In the examples below, replace `TFY_API_SH` with the full path.

### Via MCP

```
tfy_workspaces_list(filters={"cluster_id": "optional-cluster-id"})
```

### Via Direct API

```bash
# Set the path to tfy-api.sh for your agent (example for Claude Code):
TFY_API_SH=~/.claude/skills/truefoundry-workspaces/scripts/tfy-api.sh

# List all workspaces
$TFY_API_SH GET /api/svc/v1/workspaces

# Filter by cluster
$TFY_API_SH GET '/api/svc/v1/workspaces?clusterId=CLUSTER_ID'

# Filter by name
$TFY_API_SH GET '/api/svc/v1/workspaces?name=my-workspace'

# Filter by FQN
$TFY_API_SH GET '/api/svc/v1/workspaces?fqn=tfy-ea-dev-eo-az:my-ws'
```

### Get Specific Workspace

```bash
# Via MCP
tfy_workspaces_list(workspace_id="ws-id-here")

# Via API
$TFY_API_SH GET /api/svc/v1/workspaces/WORKSPACE_ID
```

## Presenting Workspaces

Show as a table:

```
Workspaces:
| Name       | FQN                        | Cluster          |
|------------|----------------------------|------------------|
| dev-ws     | tfy-ea-dev-eo-az:dev-ws    | tfy-ea-dev-eo-az |
| staging-ws | tfy-ea-dev-eo-az:staging   | tfy-ea-dev-eo-az |
```

**Key field**: `fqn` — this is what `TFY_WORKSPACE_FQN` needs for deploy.

## List Clusters

### Via MCP

```
tfy_clusters_list()
tfy_clusters_list(cluster_id="cluster-id")  # with status + addons
```

### Via Direct API

```bash
# List all clusters
$TFY_API_SH GET /api/svc/v1/clusters

# Get cluster details + status
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID/is-connected
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID/get-addons
```

## Presenting Clusters

```
Clusters:
| Name             | ID               | Connected |
|------------------|------------------|-----------|
| tfy-ea-dev-eo-az | tfy-ea-dev-eo-az | Yes ✓     |
```

## Cluster Base Domains (for Public URLs)

When a user wants to expose a service publicly, you need the cluster's base domains to construct a valid hostname. **Invalid hosts cause deploy failures.**

### How to Look Up

```bash
# Via MCP
tfy_clusters_list(cluster_id="CLUSTER_ID")

# Via Direct API
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

The response includes a `base_domains` array:
```json
"base_domains": [
  "ml.tfy-eo.truefoundry.cloud",
  "*.ml.tfy-eo.truefoundry.cloud"
]
```

### How to Use

1. Pick the **wildcard entry** (starts with `*.`) — e.g., `*.ml.tfy-eo.truefoundry.cloud`
2. Strip the `*.` prefix to get the base domain: `ml.tfy-eo.truefoundry.cloud`
3. Construct the host: `{service-name}-{workspace-name}.{base_domain}`
4. Example: `my-app-dev-ws.ml.tfy-eo.truefoundry.cloud`

### Extracting Cluster ID from Workspace FQN

The cluster ID is the part before the colon in the workspace FQN:
- Workspace FQN: `tfy-ea-dev-eo-az:sai-ws` → Cluster ID: `tfy-ea-dev-eo-az`

If `TFY_CLUSTER_ID` is set in the environment, use that directly.

## Available GPU Types

When a user needs GPU resources, discover what's available on the cluster before offering options.

### How to Discover

The cluster API doesn't directly list GPU types, but you can discover them in two ways:

**Option A: Check cluster addons/node pools**
```bash
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID/get-addons
```

**Option B: The SDK/API error message tells you**

If you deploy with an unsupported GPU type, the error message lists all valid ones:
```
"None of the nodepools support A10G. Valid devices are [T4, A10_4GB, A10_8GB, A10_12GB, A10_24GB, H100_94GB]"
```

### GPU Type Reference

Common GPU types in TrueFoundry (availability depends on the cluster):

| GPU Type | VRAM | Typical Use |
|----------|------|-------------|
| `T4` | 16 GB | Inference, small models |
| `A10_4GB` | 4 GB (fractional) | Light inference |
| `A10_8GB` | 8 GB (fractional) | Medium inference |
| `A10_12GB` | 12 GB (fractional) | Medium models |
| `A10_24GB` | 24 GB (full A10) | Large inference, fine-tuning |
| `A10G` | 24 GB | Similar to A10_24GB |
| `A100_40GB` | 40 GB | Large models, training |
| `A100_80GB` | 80 GB | Very large models |
| `L4` | 24 GB | Inference optimized |
| `L40S` | 48 GB | Large inference |
| `H100_80GB` | 80 GB | Training, large models |
| `H100_94GB` | 94 GB | Training, largest models |
| `H200` | 141 GB | Next-gen training |

**Not all types are available on every cluster.** Always check before presenting options to the user.

### Python SDK Usage

```python
from truefoundry.deploy import NvidiaGPU, GPUType, Resources

resources = Resources(
    cpu_request=4, cpu_limit=4,
    memory_request=16384, memory_limit=16384,
    devices=[NvidiaGPU(name=GPUType.T4, count=1)],
)
```

See `references/sdk-patterns.md` for more examples.

## Composability

- **Need workspace for deploy**: Use this skill first, then `deploy` skill with the `fqn`
- **Need cluster for filtering**: Pass `cluster_id` to workspaces or applications
- **Check infra status**: Get cluster + addons for monitoring

## Error Handling

### No Workspaces Found
```
No workspaces found. Check:
- TFY_CLUSTER_ID may be filtering to wrong cluster
- Your API key may not have access to this cluster
```

### Permission Denied
```
Cannot list workspaces. Your API key may lack workspace permissions.
```
