---
name: helm
description: Deploys Helm charts to TrueFoundry for infrastructure components (databases, caches, queues, vector DBs, monitoring). Supports any OCI-compatible chart. NOT for application code (use deploy skill).
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
disable-model-invocation: true
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Helm Chart Deployment

Deploy any Helm chart to TrueFoundry — databases, caches, message queues, vector databases, monitoring tools, or any other OCI-compatible Helm chart. TrueFoundry supports any chart as long as the cluster can pull it from the registry.

## When to Use

Deploy infrastructure via Helm charts: databases, caches, message queues, vector DBs, monitoring, or any custom OCI chart.

## When NOT to Use

- User wants to deploy application code → use `deploy` skill
- User wants to check what's deployed → use `applications` skill
- User wants to view logs → use `logs` skill

</objective>

<context>

## Prerequisites

**Always verify before deploying:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**

For credential check commands and .env setup, see `references/prerequisites.md`.

## User Confirmation Checklist

**Confirm these with the user before deploying. Show defaults based on chart type, let user adjust.**

- [ ] **Workspace** — `TFY_WORKSPACE_FQN`. Never auto-pick. Ask the user if missing.
- [ ] **Chart source + version** — Which chart, registry URL, and version? Always ask — charts can't be auto-detected. Suggest searching https://artifacthub.io if user is unsure.
- [ ] **Release name** — Suggest `{app-name}-{chart-type}` (e.g., `myapp-postgres`, `myapp-redis`).
- [ ] **Configuration values** — Critical values that depend on chart type. Present as a focused checklist based on what the chart needs (see below).

### Configuration by Chart Type

Ask only the values relevant to the specific chart:

**Databases (PostgreSQL, MySQL, MongoDB):**
- Password (generate strong default, confirm)
- Database name
- Storage size (suggest: 10Gi dev, 50Gi+ prod)
- Replicas (1 dev, 3 prod HA)

**Caches (Redis, Memcached, Valkey):**
- Password (generate strong default, confirm)
- Storage size (suggest: 1Gi dev, 10Gi prod)
- Memory limit

**Queues (RabbitMQ, NATS, Kafka):**
- Credentials
- Persistence enabled? Storage size
- Replicas

**Vector DBs (Qdrant, Milvus, Elasticsearch):**
- Storage size
- Replicas
- Resource limits

**Other/custom charts:**
- Ask user which values to set

### Defaults Applied Silently (do not ask unless user raises)

These use sensible defaults. Only surface if the user asks or the situation requires it:

| Field | Default | When to Ask |
|-------|---------|-------------|
| Resources (CPU/memory) | Chart defaults | Only ask for production or if chart has no defaults |
| Network access | Internal-only | Only ask if user mentions external access |
| Environment | Dev sizing | Only ask if user mentions production |
| Storage class | Cluster default | Only ask if user mentions specific storage requirements |

</context>

<instructions>

## Finding & Sourcing Helm Charts

For chart sources, OCI URLs, registries, version discovery, and the chart selection guide, see [references/helm-chart-sources.md](references/helm-chart-sources.md).

Key points: TrueFoundry supports `oci-repo` (recommended), `helm-repo`, and `git-helm-repo` source types. Always ask the user for the chart source. Do not assume or recommend specific chart registries.

## Deploy Flow

### 1. Gather Configuration

Ask the user for the chart source and critical configuration values:

```
I'll deploy a Helm chart to TrueFoundry. Let me confirm a few things:

1. Chart source: What is the chart registry URL? (e.g., an OCI registry URL, Helm repo URL, or Git repo)
   - If you're unsure, you can search https://artifacthub.io for available charts.
2. Chart name: What is the chart name? (e.g., postgresql, redis, my-custom-chart)
3. Chart version: What version should I use? (always pin a specific version for production)
4. Configuration values: What values do you need to set?
   - Credentials (passwords, usernames)
   - Storage size (e.g., 10Gi for dev, 50Gi+ for prod)
   - Resources (CPU/memory requests and limits)
   - Replicas (1 for dev, 3+ for prod high availability)
   - Network access (internal-only or expose externally)
```

### 2. Build HelmRelease Manifest

Create a TrueFoundry HelmRelease manifest with user-confirmed values:

```json
{
  "manifest": {
    "name": "my-release-name",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "CHART_VERSION",
      "oci_chart_url": "oci://REGISTRY/CHART_NAME"
    },
    "values": {
      "YOUR_CHART_VALUES": "See the chart's values.yaml for available options"
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID_FROM_FQN"
}
```

**Note:** `workspaceId` must be the internal ID, not the FQN. Get it from the `workspaces` skill.

> **Note:** The `version` field in `source` is required. Omitting it will cause a validation error. Find the latest version using the chart discovery methods described above.

### 3. Deploy via MCP or API

**Important:** The `workspaceId` must be the internal workspace ID (not the FQN). Get it from the `workspaces` skill: `GET /api/svc/v1/workspaces?fqn=WORKSPACE_FQN` -> use the `id` field.

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

#### Via MCP

```
tfy_applications_create_deployment(
    manifest={
        "name": "my-release-name",
        "type": "helm",
        "source": {
            "type": "oci-repo",
            "version": "CHART_VERSION",
            "oci_chart_url": "oci://REGISTRY/CHART_NAME"
        },
        "values": {...},
        "workspace_fqn": "cluster-id:workspace-name"
    },
    options={
        "workspace_id": "ws-internal-id",
        "force_deploy": false
    }
)
```

**Note:** This requires human approval (HITL) when using MCP.

#### Via Direct API

```bash
# First, get workspace ID from FQN
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"

# Then deploy
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-release-name",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "CHART_VERSION",
      "oci_chart_url": "oci://REGISTRY/CHART_NAME"
    },
    "values": {
      "YOUR_CHART_VALUES": "See the chart values.yaml for available options"
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID_HERE"
}'
```

### 4. Report Connection Details

After successful deployment, provide the user with connection details (host, port, database, credentials). For connection DNS patterns and default ports by chart type, see [references/helm-chart-sources.md](references/helm-chart-sources.md) (Connection Details by Chart section).

## Example Configurations

For full JSON manifest examples (Redis, MongoDB, RabbitMQ, Qdrant, Elasticsearch), secrets management patterns, and environment-specific defaults, see [references/helm-chart-examples.md](references/helm-chart-examples.md).

## Advanced: Kustomize & Additional Manifests

For Kustomize patches and deploying additional Kubernetes manifests alongside Helm charts, see [references/helm-advanced.md](references/helm-advanced.md).

## After Deploy

```
Helm chart deployed successfully!

Next steps:
1. Check deployment status: Use `applications` skill
2. View logs: Use `logs` skill if there are issues
3. Connect from your app: Use the service DNS provided above
4. Store credentials: Use TrueFoundry secrets for app access
```

</instructions>

<success_criteria>

## Success Criteria

- The Helm chart is deployed and all pods are running in the target workspace
- The agent has confirmed the chart version, resource sizing, and credentials with the user before deploying
- Connection details (host, port, credentials) are provided to the user
- Persistent storage is configured for stateful charts (databases, caches)
- The user can connect to the deployed service from their application using the provided DNS

</success_criteria>

<references>

## Composability

- **Find workspace first**: Use `workspaces` skill to get workspace FQN and ID
- **Save workspace for next time**: Use `preferences` skill to remember default workspace
- **Check what's deployed**: Use `applications` skill to list existing Helm releases
- **Test after deployment**: Use `service-test` skill to validate the deployed service
- **Manage secrets**: Use `secrets` skill to create secret groups before deploy
- **View logs**: Use `logs` skill with the HelmRelease application ID
- **Connect from app**: Reference the deployed chart's service DNS in your application's deploy.py

</references>

<troubleshooting>

## Error Handling

For error messages and troubleshooting (workspace issues, chart not found, values validation, insufficient resources, PVC binding, connection issues), see [references/helm-errors.md](references/helm-errors.md).

</troubleshooting>
