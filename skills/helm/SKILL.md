---
name: helm
description: This skill should be used when the user asks "deploy a database", "install redis", "helm chart", "deploy postgres", "deploy mongodb", "install a helm chart", "deploy vector database", "deploy qdrant", "deploy milvus", "deploy elasticsearch", or wants to deploy any infrastructure component via Helm on TrueFoundry. Supports ANY public or private OCI Helm chart.
disable-model-invocation: true
allowed-tools: Bash(*/tfy-api.sh *)
---

# Helm Chart Deployment

Deploy any Helm chart to TrueFoundry — databases, caches, message queues, vector databases, monitoring tools, or any other OCI-compatible Helm chart. TrueFoundry supports any chart as long as the cluster can pull it from the registry.

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

- User wants to deploy application code → use `deploy` skill
- User wants to check what's deployed → use `applications` skill
- User wants to view logs → use `logs` skill

## Prerequisites

**Always verify before deploying:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` is **required**. Never auto-pick. Ask the user if missing.

```bash
# Check credentials
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
echo "TFY_WORKSPACE_FQN: ${TFY_WORKSPACE_FQN:-(not set)}"
```

**If TFY_WORKSPACE_FQN is not set, STOP. Ask the user.** Suggest they use the `workspaces` skill or check the TrueFoundry dashboard.

## User Confirmation Checklist

**Before deploying a Helm chart, ALWAYS confirm these with the user:**

- [ ] **Chart source** — Which chart? (suggest from common charts table below)
- [ ] **Chart registry** — Public (Bitnami, official) or private registry?
- [ ] **Chart version** — Specific version or latest?
- [ ] **Release name** — What to call this deployment? (default: chart name + random suffix)
- [ ] **Namespace/Workspace** — Which workspace FQN? (never auto-pick)
- [ ] **Environment** — Is this for dev, staging, or production? (affects resource defaults)
- [ ] **Configuration** — Critical values to set:
  - **Passwords/credentials** — Use strong random values or reference TrueFoundry secrets
  - **Storage size** — Persistent volume size (e.g., 10Gi, 20Gi)
  - **Resources** — CPU/memory limits and requests
  - **Replicas** — Number of instances (1 for dev, 3+ for prod)
  - **Network** — Expose externally or internal-only?

**Do NOT deploy with minimal defaults without asking.** Production databases need proper sizing, credentials, and persistence configuration.

## Finding & Sourcing Helm Charts

### How TrueFoundry Helm Charts Work

TrueFoundry deploys Helm charts using **OCI (Open Container Initiative) registry URLs** as the recommended approach. Charts are stored as OCI artifacts in container registries, just like Docker images. TrueFoundry also supports traditional Helm repositories and Git-hosted charts -- see the "All Source Types" section below.

The manifest format for OCI (most common):
```json
"source": {
  "type": "oci-repo",
  "version": "16.7.21",
  "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/postgresql"
}
```

This example uses `oci-repo`. You can also use `helm-repo` or `git-helm-repo` -- see "All Source Types" section.

### Step 1: Identify the Chart

If the user asks for a specific service (e.g., "I need a Postgres database"), match it to a chart:

1. **Check the Common Charts table below** — covers 90% of use cases
2. **Search Artifact Hub** — https://artifacthub.io — the central registry for Helm charts
3. **Ask the user** if they have a specific chart or registry in mind

### Step 2: Construct the OCI URL

#### Bitnami Charts (Recommended for Most Cases)

Bitnami publishes all charts as OCI artifacts on Docker Hub. The pattern is:

```
oci://registry-1.docker.io/bitnamicharts/{chart-name}
```

Examples:
- PostgreSQL: `oci://registry-1.docker.io/bitnamicharts/postgresql`
- Redis: `oci://registry-1.docker.io/bitnamicharts/redis`
- MongoDB: `oci://registry-1.docker.io/bitnamicharts/mongodb`

**Why Bitnami?** Well-maintained, production-ready, consistent configuration patterns, and extensive documentation. Use Bitnami as the default recommendation unless the user has a specific preference.

#### Other Public Registries

| Registry | OCI URL Pattern | Example |
|----------|----------------|---------|
| Docker Hub (Bitnami) | `oci://registry-1.docker.io/bitnamicharts/{chart}` | `oci://registry-1.docker.io/bitnamicharts/postgresql` |
| Amazon ECR Public | `oci://public.ecr.aws/{repo}/{chart}` | `oci://public.ecr.aws/aws-controllers-k8s/s3-chart` |
| GitHub Container Registry | `oci://ghcr.io/{org}/{chart}` | `oci://ghcr.io/argoproj/argo-helm/argo-cd` |
| Google Artifact Registry | `oci://{region}-docker.pkg.dev/{project}/{repo}/{chart}` | Varies by project |
| Azure Container Registry | `oci://{registry}.azurecr.io/helm/{chart}` | Varies by registry |

#### Private Registries

If the user has charts in a private OCI registry:

```json
"source": {
  "type": "oci-repo",
  "version": "1.0.0",
  "oci_chart_url": "oci://myregistry.azurecr.io/helm/my-chart"
}
```

**Note:** The cluster must have network access and pull credentials configured for private registries. If the deploy fails with a pull error, the user needs to configure image pull secrets on the cluster.

### All Source Types

TrueFoundry supports three Helm chart source types:

#### 1. OCI Registry (`oci-repo`) — Recommended

The modern standard. Charts stored as OCI artifacts in container registries.

```json
"source": {
  "type": "oci-repo",
  "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/postgresql",
  "version": "16.7.21"
}
```

For private OCI registries, add the container registry integration name:
```json
"source": {
  "type": "oci-repo",
  "oci_chart_url": "oci://myregistry.azurecr.io/helm/my-chart",
  "version": "1.0.0",
  "container_registry": "my-registry-integration"
}
```

#### 2. Helm Repository (`helm-repo`)

Traditional HTTP-based Helm repositories. Use when a chart isn't available as OCI.

```json
"source": {
  "type": "helm-repo",
  "repo_url": "https://charts.bitnami.com/bitnami",
  "chart": "postgresql",
  "version": "16.7.21"
}
```

**Note:** `repo_url` is the repository URL, `chart` is the chart name within that repo.

#### 3. Git Repository (`git-helm-repo`)

Charts stored in Git repositories. Useful for private/custom charts versioned in Git.

```json
"source": {
  "type": "git-helm-repo",
  "git_repo_url": "https://github.com/your-org/helm-charts.git",
  "revision": "main",
  "path": "charts/my-chart"
}
```

Supports branches, tags, and commit SHAs for `revision`.

For private Git repos, configure credentials in the cluster's ArgoCD namespace:
```yaml
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: repo-credentials
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  url: https://github.com/org/charts.git
  type: git
  username: x-access-token
  password: <github-token>
```

### Which Source Type to Use?

| Scenario | Source Type | Why |
|----------|-----------|-----|
| Public chart (Bitnami, etc.) | `oci-repo` | Modern standard, fastest |
| Chart only available via HTTP repo | `helm-repo` | Legacy repos that don't publish OCI |
| Private chart in company Git | `git-helm-repo` | Version control + PR reviews |
| Private OCI registry | `oci-repo` + `container_registry` | Best for private charts |

### Step 3: Find the Chart Version

**Always pin a specific version** — don't leave version blank for production.

#### Option A: Check Artifact Hub

Browse chart versions at:
```
https://artifacthub.io/packages/helm/{publisher}/{chart}
```

For Bitnami charts:
```
https://artifacthub.io/packages/helm/bitnami/{chart-name}
```

Examples:
- https://artifacthub.io/packages/helm/bitnami/postgresql
- https://artifacthub.io/packages/helm/bitnami/redis

#### Option B: Use Helm CLI (if available)

```bash
# Show available versions for a Bitnami chart
helm show chart oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.7.21
```

#### Option C: Check Bitnami GitHub

Browse releases at:
```
https://github.com/bitnami/charts/tree/main/bitnami/{chart-name}
```

The `Chart.yaml` file shows the current version.

### Step 4: Find Chart Values (Configuration Options)

To know what values a chart accepts:

#### Option A: Artifact Hub (Best)

The Artifact Hub page for each chart shows the full `values.yaml` with documentation:
```
https://artifacthub.io/packages/helm/bitnami/{chart-name} → "Default Values" tab
```

#### Option B: Bitnami GitHub

```
https://github.com/bitnami/charts/blob/main/bitnami/{chart-name}/values.yaml
```

#### Option C: Helm CLI

```bash
helm show values oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.7.21
```

### Chart Selection Guide

When the user asks for a generic service, recommend:

| Need | Recommended Chart | Why |
|------|-------------------|-----|
| SQL database | Bitnami PostgreSQL | Most versatile, excellent defaults |
| Document store | Bitnami MongoDB | Good for unstructured data |
| Key-value cache | Bitnami Redis | Industry standard, fast |
| MySQL compatibility | Bitnami MySQL or MariaDB | For MySQL-specific apps |
| Message queue (AMQP) | Bitnami RabbitMQ | Reliable, feature-rich |
| Event streaming | Bitnami Kafka | High-throughput streaming |
| Search engine | Bitnami Elasticsearch | Full-text search + analytics |
| Vector database | Qdrant / Milvus / Weaviate | For AI/embedding workloads (check Artifact Hub for OCI URLs) |
| Object storage | MinIO | S3-compatible storage |
| Vector DB (general) | Qdrant (Bitnami) | Simple, fast, purpose-built for vectors |
| Vector + search | Bitnami Elasticsearch | Combined full-text + vector search |
| S3-compatible storage | Bitnami MinIO | Local object storage |
| Monitoring | Bitnami Grafana + Prometheus | Observability stack |

## Common Helm Charts

| Use Case | Chart | OCI URL | Typical Version |
|----------|-------|---------|-----------------|
| PostgreSQL | `postgresql` | `oci://registry-1.docker.io/bitnamicharts/postgresql` | 16.x |
| Redis | `redis` | `oci://registry-1.docker.io/bitnamicharts/redis` | 18.x |
| MongoDB | `mongodb` | `oci://registry-1.docker.io/bitnamicharts/mongodb` | 14.x |
| MySQL | `mysql` | `oci://registry-1.docker.io/bitnamicharts/mysql` | 9.x |
| RabbitMQ | `rabbitmq` | `oci://registry-1.docker.io/bitnamicharts/rabbitmq` | 12.x |
| Kafka | `kafka` | `oci://registry-1.docker.io/bitnamicharts/kafka` | 26.x |
| Memcached | `memcached` | `oci://registry-1.docker.io/bitnamicharts/memcached` | 6.x |
| NATS | `nats` | `oci://registry-1.docker.io/bitnamicharts/nats` | Latest |
| Elasticsearch | `elasticsearch` | `oci://registry-1.docker.io/bitnamicharts/elasticsearch` | 21.x |
| MinIO | `minio` | `oci://registry-1.docker.io/bitnamicharts/minio` | 14.x |
| Qdrant | `qdrant` | `oci://registry-1.docker.io/bitnamicharts/qdrant` | 0.x |

**Recommend Bitnami charts** for most cases — well-maintained, production-ready, and widely used.

### Deploying Any Helm Chart

The table above covers common use cases, but **TrueFoundry supports any OCI-compatible Helm chart**. If the user wants a chart not listed above:

1. **Find the chart** — Search [Artifact Hub](https://artifacthub.io) or check the project's documentation
2. **Get the OCI URL** — Look for "Install" instructions on Artifact Hub; most charts now publish OCI artifacts
3. **Construct the manifest** — Use the same `source` format:

```json
"source": {
  "type": "oci-repo",
  "version": "CHART_VERSION",
  "oci_chart_url": "oci://REGISTRY/PATH/CHART_NAME"
}
```

This example uses `oci-repo`. You can also use `helm-repo` or `git-helm-repo` -- see "All Source Types" section.

4. **Find values** — Check the chart's `values.yaml` on Artifact Hub or GitHub for configuration options
5. **Deploy** — Use the same `PUT /api/svc/v1/apps` API as any other Helm chart

#### Using Traditional Helm Repo URLs

If the user provides a traditional Helm repo URL (like `https://charts.example.com`), you have two options:

1. **Use `helm-repo` source type directly** — TrueFoundry supports traditional Helm repos natively. See "All Source Types" section.
2. **Convert to OCI** (recommended for Bitnami):
   - **Bitnami** (`https://charts.bitnami.com/bitnami`) → `oci://registry-1.docker.io/bitnamicharts/{chart}`
   - **Check Artifact Hub** — Most charts list their OCI URL on the install page
   - **Check project docs** — Many projects document their OCI registry alongside the traditional repo

#### Custom / Private Charts

For charts in private registries:

```json
"source": {
  "type": "oci-repo",
  "version": "1.0.0",
  "oci_chart_url": "oci://myregistry.azurecr.io/helm/my-custom-chart"
}
```

Requirements:
- The cluster must have network access to the registry
- Image pull secrets must be configured if the registry requires authentication
- The chart must be pushed as an OCI artifact (use `helm push` to publish)

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

### 2. Build HelmRelease Manifest

Create a TrueFoundry HelmRelease manifest with user-confirmed values. This example uses `oci-repo`. You can also use `helm-repo` or `git-helm-repo` -- see "All Source Types" section.

```json
{
  "manifest": {
    "name": "postgres-prod",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "16.7.21",
      "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/postgresql"
    },
    "values": {
      "auth": {
        "postgresPassword": "GENERATED_OR_SECRET_REF",
        "database": "myapp"
      },
      "primary": {
        "persistence": {
          "enabled": true,
          "size": "50Gi"
        },
        "resources": {
          "requests": {
            "cpu": "2",
            "memory": "2Gi"
          },
          "limits": {
            "cpu": "4",
            "memory": "4Gi"
          }
        }
      },
      "readReplicas": {
        "replicaCount": 2
      }
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID_FROM_FQN"
}
```

**Note:** `workspaceId` must be the internal ID, not the FQN. Get it from the `workspaces` skill.

### 3. Deploy via MCP or API

**Important:** The `workspaceId` must be the internal workspace ID (not the FQN). Get it from the `workspaces` skill: `GET /api/svc/v1/workspaces?fqn=WORKSPACE_FQN` -> use the `id` field.

When using direct API, use the **full path** to this skill's `scripts/tfy-api.sh`. The path depends on which agent is installed (e.g. `~/.claude/skills/truefoundry-helm/scripts/tfy-api.sh` for Claude Code, `~/.cursor/skills/truefoundry-helm/scripts/tfy-api.sh` for Cursor). In the examples below, replace `TFY_API_SH` with the full path.

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
# Set the path to tfy-api.sh for your agent (example for Claude Code):
TFY_API_SH=~/.claude/skills/truefoundry-helm/scripts/tfy-api.sh

# First, get workspace ID from FQN
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"

# Then deploy
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

### 4. Report Connection Details

After successful deployment, provide the user with:

```
PostgreSQL deployed successfully!

Connection details:
- Host: postgres-prod-postgresql.NAMESPACE.svc.cluster.local
- Port: 5432
- Database: myapp
- Username: postgres
- Password: [stored in TrueFoundry secrets or in chart output]

To connect from your application:
1. Use the host above (internal cluster DNS)
2. Store credentials in TrueFoundry secret group
3. Mount secrets in your application deployment

Check status: Use `applications` skill to verify deployment
View logs: Use `logs` skill with application ID
```

## Example Configurations

All examples below use `oci-repo`. You can also use `helm-repo` or `git-helm-repo` -- see "All Source Types" section.

### Redis (Cache)

```json
{
  "manifest": {
    "name": "redis-cache",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "18.6.0",
      "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/redis"
    },
    "values": {
      "auth": {
        "enabled": true,
        "password": "STRONG_PASSWORD"
      },
      "master": {
        "persistence": {
          "enabled": true,
          "size": "8Gi"
        },
        "resources": {
          "requests": {"cpu": "250m", "memory": "256Mi"},
          "limits": {"cpu": "1", "memory": "1Gi"}
        }
      },
      "replica": {
        "replicaCount": 3
      }
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

### MongoDB

```json
{
  "manifest": {
    "name": "mongodb",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "14.8.0",
      "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/mongodb"
    },
    "values": {
      "auth": {
        "rootPassword": "STRONG_PASSWORD",
        "databases": ["myapp"],
        "usernames": ["appuser"],
        "passwords": ["USER_PASSWORD"]
      },
      "persistence": {
        "enabled": true,
        "size": "20Gi"
      },
      "resources": {
        "requests": {"cpu": "1", "memory": "1Gi"},
        "limits": {"cpu": "2", "memory": "2Gi"}
      },
      "replicaSet": {
        "enabled": true,
        "replicas": {"secondary": 2}
      }
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

### RabbitMQ (Message Queue)

```json
{
  "manifest": {
    "name": "rabbitmq",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "12.10.0",
      "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/rabbitmq"
    },
    "values": {
      "auth": {
        "username": "admin",
        "password": "STRONG_PASSWORD"
      },
      "persistence": {
        "enabled": true,
        "size": "8Gi"
      },
      "resources": {
        "requests": {"cpu": "500m", "memory": "512Mi"},
        "limits": {"cpu": "2", "memory": "2Gi"}
      },
      "replicaCount": 3
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

### Qdrant (Vector Database)

```json
{
  "manifest": {
    "name": "qdrant",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "0.11.0",
      "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/qdrant"
    },
    "values": {
      "persistence": {
        "enabled": true,
        "size": "20Gi"
      },
      "resources": {
        "requests": {"cpu": "1", "memory": "2Gi"},
        "limits": {"cpu": "2", "memory": "4Gi"}
      },
      "replicaCount": 1
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

### Elasticsearch (Search & Vector)

```json
{
  "manifest": {
    "name": "elasticsearch",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "21.4.0",
      "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/elasticsearch"
    },
    "values": {
      "master": {
        "replicaCount": 1,
        "persistence": {
          "enabled": true,
          "size": "20Gi"
        },
        "resources": {
          "requests": {"cpu": "1", "memory": "2Gi"},
          "limits": {"cpu": "2", "memory": "4Gi"}
        }
      },
      "data": {
        "replicaCount": 2,
        "persistence": {
          "enabled": true,
          "size": "50Gi"
        },
        "resources": {
          "requests": {"cpu": "2", "memory": "4Gi"},
          "limits": {"cpu": "4", "memory": "8Gi"}
        }
      }
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

## Secrets Management

**Never hardcode passwords in manifests for production.** Use TrueFoundry secret groups:

1. Create secret group first (use `secrets` skill if available, or TrueFoundry dashboard)
2. Reference secrets in Helm values:

```json
{
  "values": {
    "auth": {
      "existingSecret": "SECRET_GROUP_NAME",
      "secretKeys": {
        "adminPassword": "POSTGRES_PASSWORD"
      }
    }
  }
}
```

Exact secret reference syntax varies by chart — check the chart's `values.yaml` for `existingSecret` parameters.

## Environment-Specific Defaults

### Development
- **Replicas:** 1 (no high availability)
- **Resources:** Minimal (0.25 CPU, 256Mi RAM)
- **Storage:** Small (5-10Gi)
- **Persistence:** Can be disabled for ephemeral testing

### Staging
- **Replicas:** 2 (some redundancy)
- **Resources:** Medium (0.5-1 CPU, 512Mi-1Gi RAM)
- **Storage:** Moderate (10-20Gi)
- **Persistence:** Enabled

### Production
- **Replicas:** 3+ (high availability)
- **Resources:** Generous (1-4 CPU, 1-4Gi RAM)
- **Storage:** Large (20-100Gi+)
- **Persistence:** Always enabled with backups
- **Monitoring:** Enable Prometheus metrics if available

## Composability

- **Find workspace first**: Use `workspaces` skill to get workspace FQN and ID
- **Check what's deployed**: Use `applications` skill to list existing Helm releases
- **Manage secrets**: Use `secrets` skill to create secret groups before deploy
- **View logs**: Use `logs` skill with the HelmRelease application ID
- **Connect from app**: Reference the deployed chart's service DNS in your application's deploy.py

## Advanced: Kustomize & Additional Manifests

### Kustomize Patches

Modify resources generated by the Helm chart without editing the chart itself. Useful for adding labels, annotations, or tweaking resource configs.

Add `kustomize` to the manifest:
```json
{
  "manifest": {
    "name": "my-postgres",
    "type": "helm",
    "source": { ... },
    "values": { ... },
    "kustomize": {
      "patches": [
        {
          "patch": "apiVersion: apps/v1\nkind: StatefulSet\nmetadata:\n  name: my-postgres-postgresql\n  annotations:\n    custom-annotation: value",
          "target": {
            "kind": "StatefulSet",
            "name": "my-postgres-postgresql"
          }
        }
      ]
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

### Additional Manifests

Deploy extra Kubernetes resources alongside the Helm chart (e.g., VirtualServices, ConfigMaps, Secrets):

```json
{
  "manifest": {
    "name": "my-postgres",
    "type": "helm",
    "source": { ... },
    "values": { ... },
    "additional_manifests": [
      {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {
          "name": "db-credentials",
          "namespace": "your-workspace"
        },
        "type": "Opaque",
        "stringData": {
          "password": "tfy-secret://tfy-eo:my-secrets:db-password"
        }
      }
    ],
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

**Note:** TrueFoundry secrets (`tfy-secret://...`) are only supported in Kubernetes Secret manifests using the `stringData` field.

## Error Handling

### TFY_WORKSPACE_FQN Not Set
```
TFY_WORKSPACE_FQN is required. Get it from:
- TrueFoundry dashboard → Workspaces
- Or use: workspaces skill to list available workspaces
Do not auto-pick a workspace.
```

### Invalid Workspace ID
```
Could not find workspace ID for FQN: {fqn}
Use the workspaces skill to verify the workspace exists and get its ID.
```

### Chart Not Found
```
Helm chart not found in registry.
Check:
- Chart name is correct (e.g., "postgresql", not "postgres")
- Registry URL is reachable
- Version exists (omit version to use latest)
```

### Values Validation Failed
```
Helm values failed validation.
Common issues:
- Missing required fields (auth, passwords, etc.)
- Invalid resource format (use "1" or "1000m" for CPU, "1Gi" for memory)
- Invalid storage size format (use "10Gi", not "10GB")

Check the chart's values.yaml for required fields:
https://artifacthub.io/packages/helm/{repo}/{chart}
```

### Insufficient Resources
```
Deployment failed: Insufficient resources in cluster.
Requested: {cpu} CPU, {memory} RAM
Available: {available}

Options:
- Reduce resource requests in values
- Use a larger cluster node pool
- Remove resource limits (not recommended for prod)
```

### PVC Binding Failed
```
Persistent volume claim failed to bind.
Check:
- Storage class exists in the cluster (use: kubectl get storageclass)
- Requested size is within quota limits
- Cluster has available persistent volume provisioner
```

### Connection Issues After Deploy
```
Chart deployed but connection failed.
Check:
1. Application status: Use `applications` skill
2. Pod logs: Use `logs` skill with the application ID
3. Service DNS: {name}-{chart}.{namespace}.svc.cluster.local
4. Port: Check chart documentation for default port
5. Credentials: Verify password/secret configuration
```

## After Deploy

```
Helm chart deployed successfully!

Next steps:
1. Check deployment status: Use `applications` skill
2. View logs: Use `logs` skill if there are issues
3. Connect from your app: Use the service DNS provided above
4. Store credentials: Use TrueFoundry secrets for app access
```

## Chart Documentation

### Finding Chart Values & Configuration

| Source | URL Pattern | Best For |
|--------|-------------|----------|
| **Artifact Hub** | `https://artifacthub.io/packages/helm/bitnami/{chart}` | Browsing versions, reading values docs |
| **Bitnami GitHub** | `https://github.com/bitnami/charts/tree/main/bitnami/{chart}` | Reading source, values.yaml, examples |
| **Helm CLI** | `helm show values oci://registry-1.docker.io/bitnamicharts/{chart}` | Full values.yaml locally |

### Connection Details by Chart

After deploying, the internal DNS and default ports are:

| Chart | Service DNS | Default Port |
|-------|------------|--------------|
| PostgreSQL | `{name}-postgresql.{namespace}.svc.cluster.local` | 5432 |
| Redis | `{name}-redis-master.{namespace}.svc.cluster.local` | 6379 |
| MongoDB | `{name}-mongodb.{namespace}.svc.cluster.local` | 27017 |
| MySQL | `{name}-mysql.{namespace}.svc.cluster.local` | 3306 |
| RabbitMQ | `{name}-rabbitmq.{namespace}.svc.cluster.local` | 5672 (AMQP), 15672 (UI) |
| Kafka | `{name}-kafka.{namespace}.svc.cluster.local` | 9092 |
| Elasticsearch | `{name}-elasticsearch.{namespace}.svc.cluster.local` | 9200 |
| Qdrant | `{name}-qdrant.{namespace}.svc.cluster.local` | 6333 (HTTP), 6334 (gRPC) |
| MinIO | `{name}-minio.{namespace}.svc.cluster.local` | 9000 (API), 9001 (Console) |

**Note:** `{namespace}` is the Kubernetes namespace of the workspace. You can find it from the workspace details.
