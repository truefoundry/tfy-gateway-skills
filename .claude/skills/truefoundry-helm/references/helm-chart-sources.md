# Helm Chart Sources & Discovery

## How TrueFoundry Helm Charts Work

TrueFoundry deploys Helm charts using **OCI (Open Container Initiative) registry URLs** as the recommended approach. Charts are stored as OCI artifacts in container registries, just like Docker images. TrueFoundry also supports traditional Helm repositories and Git-hosted charts -- see the "All Source Types" section below.

The manifest format for OCI (most common):
```json
"source": {
  "type": "oci-repo",
  "version": "1.0.0",
  "oci_chart_url": "oci://REGISTRY/CHART_NAME"
}
```

You can also use `helm-repo` or `git-helm-repo` -- see "All Source Types" section.

## Step 1: Identify the Chart

**Always ask the user for the chart they want to deploy.** Do not assume or recommend specific chart registries.

1. **Ask the user** which chart and registry they want to use
2. **If they don't know**, suggest they search [Artifact Hub](https://artifacthub.io) — the central discovery hub for Helm charts
3. **If they have a private/organizational registry**, ask for the registry URL, chart name, and version

## Step 2: Construct the Source

### Public Registries

| Registry | OCI URL Pattern | Example |
|----------|----------------|---------|
| Amazon ECR Public | `oci://public.ecr.aws/{repo}/{chart}` | `oci://public.ecr.aws/aws-controllers-k8s/s3-chart` |
| GitHub Container Registry | `oci://ghcr.io/{org}/{chart}` | `oci://ghcr.io/argoproj/argo-helm/argo-cd` |
| Google Artifact Registry | `oci://{region}-docker.pkg.dev/{project}/{repo}/{chart}` | Varies by project |
| Azure Container Registry | `oci://{registry}.azurecr.io/helm/{chart}` | Varies by registry |
| Docker Hub | `oci://registry-1.docker.io/{namespace}/{chart}` | Varies by publisher |

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
  "oci_chart_url": "oci://REGISTRY/CHART_NAME",
  "version": "1.0.0"
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
  "repo_url": "https://charts.example.com/repo",
  "chart": "my-chart",
  "version": "1.0.0"
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
| Public chart available as OCI | `oci-repo` | Modern standard, fastest |
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

Search for any chart at https://artifacthub.io and check its available versions.

### Option B: Use Helm CLI (if available)

```bash
# Show chart info for a specific version
helm show chart oci://REGISTRY/CHART_NAME --version VERSION
```

### Option C: Check the Chart's Repository

Browse the chart's source repository (GitHub, GitLab, etc.) and check the `Chart.yaml` file for version information.

## Step 4: Find Chart Values (Configuration Options)

To know what values a chart accepts:

### Option A: Artifact Hub (Best)

The Artifact Hub page for each chart shows the full `values.yaml` with documentation. Search for the chart at https://artifacthub.io and check the "Default Values" tab.

### Option B: Chart Source Repository

Check the chart's source repository for its `values.yaml` file.

### Option C: Helm CLI

```bash
helm show values oci://REGISTRY/CHART_NAME --version VERSION
```

## Chart Discovery

Ask the user which chart they want to use. If they don't know, suggest they search [Artifact Hub](https://artifacthub.io) or provide their organization's chart registry URL.

Artifact Hub indexes charts from many publishers and registries, making it the best starting point for discovering available charts, versions, and configuration options.

### Deploying Any Helm Chart

**TrueFoundry supports any OCI-compatible Helm chart.** The workflow is always the same:

1. **Ask the user for the chart** — Get the registry URL, chart name, and version
2. **If unknown**, suggest searching [Artifact Hub](https://artifacthub.io) or checking the project's documentation
3. **Construct the manifest** — Use the appropriate source type:

```json
"source": {
  "type": "oci-repo",
  "version": "CHART_VERSION",
  "oci_chart_url": "oci://REGISTRY/CHART_NAME"
}
```

This example uses `oci-repo`. You can also use `helm-repo` or `git-helm-repo` -- see "All Source Types" section.

4. **Find values** — Check the chart's `values.yaml` on Artifact Hub or its source repository for configuration options
5. **Deploy** — Use the same `PUT /api/svc/v1/apps` API as any other Helm chart

### Using Traditional Helm Repo URLs

If the user provides a traditional Helm repo URL (like `https://charts.example.com`), you have two options:

1. **Use `helm-repo` source type directly** — TrueFoundry supports traditional Helm repos natively. See "All Source Types" section.
2. **Convert to OCI** — Check if the chart publisher also offers an OCI registry URL. Many projects now publish to both formats. Check Artifact Hub or the project's documentation for OCI availability.

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
| **Artifact Hub** | `https://artifacthub.io/packages/helm/{publisher}/{chart}` | Browsing versions, reading values docs |
| **Chart Source Repo** | Check the chart's GitHub/GitLab repository | Reading source, values.yaml, examples |
| **Helm CLI** | `helm show values oci://REGISTRY/CHART_NAME --version VERSION` | Full values.yaml locally |

### Connection Details by Chart

After deploying, the internal DNS and default ports depend on the specific chart being used. The chart's documentation will specify the service naming pattern. Common conventions include:

| Service Type | Typical DNS Pattern | Default Port |
|-------------|---------------------|--------------|
| PostgreSQL | `{name}-{chart}.{namespace}.svc.cluster.local` | 5432 |
| Redis | `{name}-{chart}-master.{namespace}.svc.cluster.local` | 6379 |
| MongoDB | `{name}-{chart}.{namespace}.svc.cluster.local` | 27017 |
| MySQL | `{name}-{chart}.{namespace}.svc.cluster.local` | 3306 |
| RabbitMQ | `{name}-{chart}.{namespace}.svc.cluster.local` | 5672 (AMQP), 15672 (UI) |
| Kafka | `{name}-{chart}.{namespace}.svc.cluster.local` | 9092 |
| Elasticsearch | `{name}-{chart}.{namespace}.svc.cluster.local` | 9200 |
| Qdrant | `{name}-{chart}.{namespace}.svc.cluster.local` | 6333 (HTTP), 6334 (gRPC) |
| MinIO | `{name}-{chart}.{namespace}.svc.cluster.local` | 9000 (API), 9001 (Console) |

**Note:** The exact service DNS name depends on the chart being used. Check the chart's documentation or the deployed Kubernetes services (`kubectl get svc -n {namespace}`) to confirm the actual service name. `{namespace}` is the Kubernetes namespace of the workspace. You can find it from the workspace details.
