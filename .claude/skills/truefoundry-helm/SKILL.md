---
name: helm
description: This skill should be used when the user asks "deploy a database", "install redis", "helm chart", "deploy postgres", "deploy mongodb", "install a helm chart", "deploy vector database", "deploy qdrant", "deploy milvus", "deploy elasticsearch", "install a chart", "deploy infrastructure", "set up a database", "add redis to my cluster", "deploy rabbitmq", "install kafka", "deploy monitoring stack", or wants to deploy any infrastructure component via Helm on TrueFoundry. Supports ANY public or private OCI Helm chart. Uses YAML manifests with `tfy apply`.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
metadata:
  disable-model-invocation: "true"
allowed-tools: Bash(tfy*) Bash(*/tfy-api.sh *)
---

<objective>

# Helm Chart Deployment

Deploy any Helm chart to TrueFoundry -- databases, caches, message queues, vector databases, monitoring tools, or any other OCI-compatible Helm chart. TrueFoundry supports any chart as long as the cluster can pull it from the registry.

Two paths:

1. **CLI** (`tfy apply`) -- Write a YAML manifest and apply it. Works everywhere.
2. **REST API** (fallback) -- When CLI unavailable, use `tfy-api.sh`.

## When to Use

- User wants to deploy a database (PostgreSQL, MySQL, MongoDB, etc.)
- User wants to install a cache (Redis, Memcached)
- User wants to deploy a message queue (RabbitMQ, Kafka, NATS)
- User says "install helm chart", "deploy via helm"
- User wants infrastructure components, not application code
- User wants to deploy a vector database (Qdrant, Milvus, Weaviate, Chroma)
- User wants to deploy monitoring tools (Prometheus, Grafana)
- User has a custom/private Helm chart to deploy
- User wants to deploy ANY infrastructure component available as a Helm chart

## When NOT to Use

- User wants to deploy application code -> use `deploy` skill
- User wants to check what's deployed -> use `applications` skill
- User wants to view logs -> use `logs` skill

</objective>

<context>

## Prerequisites

**Always verify before deploying:**

1. **Credentials** -- `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** -- `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**
3. **CLI** -- Check if `tfy` CLI is available: `tfy --version`. If not, `pip install truefoundry`.

For credential check commands and .env setup, see `references/prerequisites.md`.

## User Confirmation Checklist

**Before deploying a Helm chart, ALWAYS confirm these with the user:**

- [ ] **Chart source** -- Which chart? (suggest from common charts table)
- [ ] **Chart registry** -- Public (Bitnami, official) or private registry?
- [ ] **Chart version** -- Specific version or latest?
- [ ] **Release name** -- What to call this deployment? (default: chart name + random suffix)
- [ ] **Namespace/Workspace** -- Which workspace FQN? (never auto-pick)
- [ ] **Environment** -- Is this for dev, staging, or production? (affects resource defaults)
- [ ] **Configuration** -- Critical values to set:
  - **Passwords/credentials** -- Use strong random values or reference TrueFoundry secrets
  - **Storage size** -- Persistent volume size (e.g., 10Gi, 20Gi)
  - **Resources** -- CPU/memory limits and requests
  - **Replicas** -- Number of instances (1 for dev, 3+ for prod)
  - **Network** -- Expose externally or internal-only?
- [ ] **Auto-shutdown** -- Should the deployment auto-stop after inactivity? (useful for dev/staging to save costs)

**Do NOT deploy with minimal defaults without asking.** Production databases need proper sizing, credentials, and persistence configuration.

</context>

<instructions>

## Finding & Sourcing Helm Charts

For chart sources, OCI URLs, registries, version discovery, and the chart selection guide, see [references/helm-chart-sources.md](references/helm-chart-sources.md).

Key points: TrueFoundry supports `oci-repo` (recommended), `helm-repo`, and `git-helm-repo` source types. Bitnami charts (`oci://registry-1.docker.io/bitnamicharts/{chart}`) are recommended for most use cases.

## Deploy Flow

### 1. Gather Configuration

Ask the user for critical configuration values. For a **PostgreSQL** example:

```
I'll deploy PostgreSQL to TrueFoundry. Let me confirm a few things:

1. Chart version: Use postgresql 15.x (latest stable)? Or specific version?
2. Database name: What should the default database be called? (default: postgres)
3. Password: I'll generate a strong random password. Or do you have a TrueFoundry secret group to reference?
4. Storage: How much persistent storage? (default: 10Gi for dev, 50Gi+ for prod)
5. Resources:
   - CPU: 0.5 cores for dev, 2+ for prod?
   - Memory: 512Mi for dev, 2Gi+ for prod?
6. Replicas: 1 for dev, 3+ for prod high availability?
7. Access: Internal-only (default) or expose externally?
```

### 2. Generate YAML Manifest

Create a YAML manifest with user-confirmed values:

```yaml
name: postgres-prod
type: helm
source:
  type: oci-repo
  version: "16.7.21"
  oci_chart_url: oci://registry-1.docker.io/bitnamicharts/postgresql
values:
  auth:
    postgresPassword: GENERATED_OR_SECRET_REF
    database: myapp
  primary:
    persistence:
      enabled: true
      size: 50Gi
    resources:
      requests:
        cpu: "2"
        memory: 2Gi
      limits:
        cpu: "4"
        memory: 4Gi
  readReplicas:
    replicaCount: 2
workspace_fqn: cluster-id:workspace-name
```

### 3. Write and Preview Manifest

Write the manifest to `tfy-manifest.yaml`:

```bash
tfy apply -f tfy-manifest.yaml --dry-run --show-diff
```

Show the preview output to the user.

### 4. Apply

After user confirms:

```bash
tfy apply -f tfy-manifest.yaml
```

### Fallback: REST API

If `tfy` CLI is not available, convert the YAML manifest to JSON and deploy via REST API. See `references/cli-fallback.md` for the conversion process.

**Important:** The `workspaceId` must be the internal workspace ID (not the FQN). Get it from the `workspaces` skill: `GET /api/svc/v1/workspaces?fqn=WORKSPACE_FQN` -> use the `id` field.

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

#### Via MCP

```
tfy_applications_create_deployment(
    manifest={
        "name": "postgres-prod",
        "type": "helm",
        "source": {
            "type": "oci-repo",
            "version": "16.7.21",
            "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/postgresql"
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
TFY_API_SH=~/.claude/skills/truefoundry-helm/scripts/tfy-api.sh

# First, get workspace ID from FQN
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"

# Then deploy (JSON body)
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "postgres-prod",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "16.7.21",
      "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/postgresql"
    },
    "values": {
      "auth": {"postgresPassword": "...", "database": "myapp"},
      "primary": {
        "persistence": {"enabled": true, "size": "50Gi"},
        "resources": {
          "requests": {"cpu": "2", "memory": "2Gi"},
          "limits": {"cpu": "4", "memory": "4Gi"}
        }
      }
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID_HERE"
}'
```

### 5. Report Connection Details

After successful deployment, provide the user with connection details (host, port, database, credentials). For connection DNS patterns and default ports by chart type, see [references/helm-chart-sources.md](references/helm-chart-sources.md) (Connection Details by Chart section).

## Example Configurations

For full YAML manifest examples (Redis, MongoDB, RabbitMQ, Qdrant, Elasticsearch), secrets management patterns, and environment-specific defaults, see [references/helm-chart-examples.md](references/helm-chart-examples.md).

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
- **Connect from app**: Reference the deployed chart's service DNS in your application's YAML manifest

</references>

<troubleshooting>

## Error Handling

For error messages and troubleshooting (workspace issues, chart not found, values validation, insufficient resources, PVC binding, connection issues), see [references/helm-errors.md](references/helm-errors.md).

Additional CLI-specific errors:
- `tfy: command not found` -- Install with `pip install truefoundry`
- `tfy apply` validation errors -- Check YAML syntax, ensure required fields (name, type, source, workspace_fqn) are present

</troubleshooting>
</output>
