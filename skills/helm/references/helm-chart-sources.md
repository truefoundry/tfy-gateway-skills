# Helm Chart Sources & Discovery

## How TrueFoundry Helm Charts Work

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

## Step 1: Identify the Chart

If the user asks for a specific service (e.g., "I need a Postgres database"), match it to a chart:

1. **Check the Common Charts table below** — covers 90% of use cases
2. **Search Artifact Hub** — https://artifacthub.io — the central registry for Helm charts
3. **Ask the user** if they have a specific chart or registry in mind

## Step 2: Construct the OCI URL

### Bitnami Charts (Recommended for Most Cases)

Bitnami publishes all charts as OCI artifacts on Docker Hub. The pattern is:

```
oci://registry-1.docker.io/bitnamicharts/{chart-name}
```

Examples:
- PostgreSQL: `oci://registry-1.docker.io/bitnamicharts/postgresql`
- Redis: `oci://registry-1.docker.io/bitnamicharts/redis`
- MongoDB: `oci://registry-1.docker.io/bitnamicharts/mongodb`

**Why Bitnami?** Well-maintained, production-ready, consistent configuration patterns, and extensive documentation. Use Bitnami as the default recommendation unless the user has a specific preference.

### Other Public Registries

| Registry | OCI URL Pattern | Example |
|----------|----------------|---------|
| Docker Hub (Bitnami) | `oci://registry-1.docker.io/bitnamicharts/{chart}` | `oci://registry-1.docker.io/bitnamicharts/postgresql` |
| Amazon ECR Public | `oci://public.ecr.aws/{repo}/{chart}` | `oci://public.ecr.aws/aws-controllers-k8s/s3-chart` |
| GitHub Container Registry | `oci://ghcr.io/{org}/{chart}` | `oci://ghcr.io/argoproj/argo-helm/argo-cd` |
| Google Artifact Registry | `oci://{region}-docker.pkg.dev/{project}/{repo}/{chart}` | Varies by project |
| Azure Container Registry | `oci://{registry}.azurecr.io/helm/{chart}` | Varies by registry |

### Private Registries

If the user has charts in a private OCI registry:

```json
"source": {
  "type": "oci-repo",
  "version": "1.0.0",
  "oci_chart_url": "oci://myregistry.azurecr.io/helm/my-chart"
}
```

**Note:** The cluster must have network access and pull credentials configured for private registries. If the deploy fails with a pull error, the user needs to configure image pull secrets on the cluster.

## All Source Types

TrueFoundry supports three Helm chart source types:

### 1. OCI Registry (`oci-repo`) — Recommended

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

### 2. Helm Repository (`helm-repo`)

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

### 3. Git Repository (`git-helm-repo`)

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

## Step 3: Find the Chart Version

**Always pin a specific version** — don't leave version blank for production.

### Option A: Check Artifact Hub

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

### Option B: Use Helm CLI (if available)

```bash
# Show available versions for a Bitnami chart
helm show chart oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.7.21
```

### Option C: Check Bitnami GitHub

Browse releases at:
```
https://github.com/bitnami/charts/tree/main/bitnami/{chart-name}
```

The `Chart.yaml` file shows the current version.

## Step 4: Find Chart Values (Configuration Options)

To know what values a chart accepts:

### Option A: Artifact Hub (Best)

The Artifact Hub page for each chart shows the full `values.yaml` with documentation:
```
https://artifacthub.io/packages/helm/bitnami/{chart-name} → "Default Values" tab
```

### Option B: Bitnami GitHub

```
https://github.com/bitnami/charts/blob/main/bitnami/{chart-name}/values.yaml
```

### Option C: Helm CLI

```bash
helm show values oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.7.21
```

## Chart Selection Guide

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

### Using Traditional Helm Repo URLs

If the user provides a traditional Helm repo URL (like `https://charts.example.com`), you have two options:

1. **Use `helm-repo` source type directly** — TrueFoundry supports traditional Helm repos natively. See "All Source Types" section.
2. **Convert to OCI** (recommended for Bitnami):
   - **Bitnami** (`https://charts.bitnami.com/bitnami`) → `oci://registry-1.docker.io/bitnamicharts/{chart}`
   - **Check Artifact Hub** — Most charts list their OCI URL on the install page
   - **Check project docs** — Many projects document their OCI registry alongside the traditional repo

### Custom / Private Charts

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
