---
name: workspaces
description: This skill should be used when the user asks "list workspaces", "show clusters", "what workspaces are available", "which workspace", "find my workspace FQN", "show GPU types", "what GPUs are available", "cluster base domain", "workspace for deployment", "get cluster info", "list environments", or needs a workspace FQN for deployment or filtering.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Workspaces & Clusters

List TrueFoundry workspaces and clusters. Workspaces are the deploy targets; clusters are the underlying infrastructure.

## When to Use

- User asks "list workspaces", "show my workspaces", "which workspace"
- User needs a `workspace_fqn` for deploy or filtering
- User asks "list clusters", "show clusters", "cluster status"
- Before deploying, to confirm target workspace

</objective>

<instructions>

## List Workspaces

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

### Via MCP

```
tfy_workspaces_list(filters={"cluster_id": "optional-cluster-id"})
```

### Via Direct API

```bash
# List all workspaces
$TFY_API_SH GET /api/svc/v1/workspaces

# Filter by cluster
$TFY_API_SH GET '/api/svc/v1/workspaces?clusterId=CLUSTER_ID'

# Filter by name
$TFY_API_SH GET '/api/svc/v1/workspaces?name=my-workspace'

# Filter by FQN
$TFY_API_SH GET '/api/svc/v1/workspaces?fqn=my-cluster:my-workspace'
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
| dev-ws     | my-cluster:dev-ws    | my-cluster |
| staging-ws | my-cluster:staging   | my-cluster |
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
| my-cluster | my-cluster | Yes ✓     |
```

## Cluster Base Domains (for Public URLs)

When a user wants to expose a service publicly, you need the cluster's base domains to construct a valid hostname. Invalid hosts cause deploy failures. See `references/cluster-discovery.md` for how to look up base domains, extract cluster ID from workspace FQN, and construct public URLs.

## Available GPU Types

When a user needs GPU resources, discover what's available on the cluster before offering options.

### How to Discover

**Option A: Check cluster addons/node pools**
```bash
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID/get-addons
```

**Option B: The SDK/API error message tells you**

If you deploy with an unsupported GPU type, the error message lists all valid ones:
```
"None of the nodepools support A10G. Valid devices are [T4, A10_4GB, A10_8GB, A10_12GB, A10_24GB, H100_94GB]"
```

**Not all types are available on every cluster.** Always check before presenting options to the user.

For the full GPU type reference table and SDK usage examples, see `references/gpu-reference.md`.

</instructions>

<success_criteria>

- The user can see a formatted table of available workspaces with their FQNs
- The agent has identified the correct workspace FQN for the user's intended deployment target
- The user can see cluster connectivity status and available infrastructure
- The agent has discovered and presented available GPU types if the user needs GPU resources
- The user has the cluster base domain if they need to expose a service publicly

</success_criteria>

<references>

## Composability

- **Need workspace for deploy**: Use this skill first, then `deploy` skill with the `fqn`
- **Need cluster for filtering**: Pass `cluster_id` to workspaces or applications
- **Check infra status**: Get cluster + addons for monitoring

</references>

<troubleshooting>

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

</troubleshooting>
