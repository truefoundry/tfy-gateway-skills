# Cluster Discovery

## Extracting Cluster ID from Workspace FQN

The cluster ID is the part before the colon in a workspace FQN:

- `tfy-ea-dev-eo-az:sai-ws` → cluster ID is `tfy-ea-dev-eo-az`
- Or use `TFY_CLUSTER_ID` from environment if set

## Fetching Cluster Details

```
# Via MCP
tfy_clusters_list(cluster_id="CLUSTER_ID")

# Via Direct API
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

## Extracting Base Domains for Public URLs

1. Look for `base_domains` in the cluster response
2. Pick the wildcard entry (starts with `*.`)
3. Strip `*.` to get the base domain
4. Construct host: `{service-name}-{workspace-name}.{base_domain}`
5. Example: `my-app-dev-ws.ml.tfy-eo.truefoundry.cloud`

**Why this matters:** Deploying with the wrong base domain results in a "Provided host is not configured in cluster" error.

## Discovering Available GPUs

The cluster API shows what GPU types are available. Only present available types to the user.

## Storage Class Reference

| Provider | Storage Class | Type | Notes |
|----------|--------------|------|-------|
| AWS | `efs-sc` | EFS (NFS) | Multi-AZ, shared across pods |
| GCP | `standard-rwx` | Filestore (NFS) | Shared across pods |
| Azure | `azurefile-csi` | Azure Files (SMB) | Shared across pods |
