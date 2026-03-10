# Cluster Discovery

## Interactive Cluster Selection

**Never ask the user to set `TFY_CLUSTER_ID` manually.** Instead, list clusters and let the user pick one — just like workspace selection.

### Flow

1. List all clusters the user has access to
2. Present a table and let the user choose
3. Use the selected cluster ID to filter workspaces

### Via Tool Call

```
tfy_clusters_list()
```

### Via Direct API

```bash
$TFY_API_SH GET /api/svc/v1/clusters
```

### Present as Table

```
Clusters:
| Name             | ID               | Connected |
|------------------|------------------|-----------|
| prod-cluster     | prod-cluster     | Yes       |
| dev-cluster      | dev-cluster      | Yes       |
```

Ask the user to pick one, then filter workspaces by that cluster ID.

## Extracting Cluster ID from Workspace FQN

The cluster ID is the part before the colon in a workspace FQN:

- `my-cluster:my-workspace` → cluster ID is `my-cluster`

## Fetching Cluster Details

```
# Via Tool Call
tfy_clusters_list(cluster_id="CLUSTER_ID")

# Via Direct API
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

## Extracting Base Domains for Public URLs

1. Look for `base_domains` in the cluster response
2. Pick the wildcard entry (starts with `*.`)
3. Strip `*.` to get the base domain
4. Construct host: `{service-name}-{workspace-name}.{base_domain}`
5. Example: `my-app-dev-ws.ml.your-org.truefoundry.cloud`

**Why this matters:** Deploying with the wrong base domain results in a "Provided host is not configured in cluster" error.

## Discovering Available GPUs

The cluster API shows what GPU types are available. Only present available types to the user.

## Fallback: When Cluster API Returns 403

If the cluster API returns 403 Forbidden or is otherwise unavailable:

1. **List workspaces without cluster filter** — the workspace list itself shows which clusters are available (cluster ID is part of the FQN)
2. **List existing apps in the workspace** and extract domain patterns from `ports[].host`:
   ```bash
   $TFY_API_SH GET "/api/svc/v1/apps?workspaceFqn=${TFY_WORKSPACE_FQN}&limit=5"
   # Look at ports[].host in any existing app to infer the base domain
   ```
3. **Ask the user directly** — "What's your cluster's base domain? (e.g., `ml.your-org.truefoundry.cloud`)"
4. **For internal-only services**, skip domain discovery entirely — set `expose: false` and omit `host`

## Storage Class Reference

| Provider | Storage Class | Type | Notes |
|----------|--------------|------|-------|
| AWS | `efs-sc` | EFS (NFS) | Multi-AZ, shared across pods |
| GCP | `standard-rwx` | Filestore (NFS) | Shared across pods |
| Azure | `azurefile-csi` | Azure Files (SMB) | Shared across pods |
