# TFY Apply — Declarative Resource Management

Create or update TrueFoundry resources from YAML manifest files using `tfy apply`. Analogous to `kubectl apply` — describe desired state in YAML and the CLI reconciles it.

## When to Use

- Declarative, file-based deployments (GitOps style)
- Store deployment configs in Git and apply via CI/CD
- Batch-apply multiple resources at once
- Reproducible deployments across environments
- User has a TrueFoundry YAML manifest and wants to apply it
- Preview changes before applying (`--dry-run`)

## CLI Version Check

| CLI Output | Status | Action |
|-----------|--------|--------|
| `tfy version X.Y.Z` (>= 0.5.0) | Current | Use `tfy apply` as documented |
| `tfy version X.Y.Z` (0.3.x-0.4.x) | Outdated | Upgrade: `pip install -U truefoundry`. Core `tfy apply` still works. |
| `servicefoundry version X.Y.Z` | Legacy CLI | Upgrade: `pip install -U truefoundry` |
| Command not found | Not installed | Install: `pip install 'truefoundry==0.5.0' && tfy login --host "$TFY_BASE_URL"` |

For full environment detection (SDK + CLI + Python):
```bash
$TFY_SKILL_DIR/scripts/tfy-version.sh all
```

## Basic Usage

```bash
# Apply a single manifest
tfy apply -f manifest.yaml

# Preview changes without applying (dry run)
tfy apply -f manifest.yaml --dry-run --show-diff
```

**Always recommend running `--dry-run --show-diff` first** so the user can review changes before committing.

## Manifest Format

A TrueFoundry manifest is a YAML file with `name`, `type`, and type-specific configuration. The `type` field determines the resource kind.

For detailed field definitions, see `manifest-schema.md`. For sensible defaults, see `manifest-defaults.md`.

### Service Manifest

```yaml
name: my-api-service
type: service
image:
  type: image
  image_uri: docker.io/myorg/my-api:latest
ports:
  - port: 8000
    protocol: TCP
    expose: true
    app_protocol: http
    host: my-api-service-my-workspace.example.truefoundry.cloud
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1024
  ephemeral_storage_limit: 2048
replicas:
  min: 2
  max: 5
env:
  DATABASE_URL: postgres://user:DB_PASSWORD@db-host:5432/mydb
  LOG_LEVEL: info
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
workspace_fqn: cluster-id:workspace-name
```

### Job Manifest

```yaml
name: data-pipeline-job
type: job
image:
  type: image
  image_uri: docker.io/myorg/pipeline:latest
resources:
  cpu_request: 1.0
  cpu_limit: 2.0
  memory_request: 2048
  memory_limit: 4096
env:
  INPUT_BUCKET: s3://my-data/input
  OUTPUT_BUCKET: s3://my-data/output
retries: 3
timeout: 3600
workspace_fqn: cluster-id:workspace-name
```

### Helm Chart Manifest

```yaml
name: postgres-prod
type: helm
source:
  type: oci-repo
  version: "16.7.21"
  oci_chart_url: oci://REGISTRY/CHART_NAME
values:
  auth:
    postgresPassword: "STRONG_PASSWORD"
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
workspace_fqn: cluster-id:workspace-name
```

For async-service, notebook, and ssh-server manifest examples (including GPU variants), see [tfy-apply-extra-manifests.md](tfy-apply-extra-manifests.md).

## Environment Variable Substitution

### Using Shell Envsubst

```bash
# Substitute and apply
export IMAGE_TAG="v1.2.3"
export TFY_WORKSPACE_FQN="cluster-id:production-ws"
envsubst < manifest-template.yaml | tfy apply -f -
```

### Per-Environment Manifests

Maintain separate manifests per environment or use a single template:

```bash
# CI/CD pipeline
export IMAGE_TAG="${CI_COMMIT_SHA}"
export TFY_WORKSPACE_FQN="${WORKSPACE_FQN}"
export REPLICAS_MIN="${REPLICAS_MIN:-1}"
export REPLICAS_MAX="${REPLICAS_MAX:-3}"

envsubst < manifest-template.yaml | tfy apply -f -
```

## Applying Multiple Resources

### Multiple Files

```bash
tfy apply -f service.yaml
tfy apply -f database.yaml
tfy apply -f worker.yaml
```

### Batch Apply Script

```bash
#!/bin/bash
set -euo pipefail
MANIFEST_DIR="${1:-.}"

for manifest in "$MANIFEST_DIR"/*.yaml; do
  echo "Applying: $manifest"
  tfy apply -f "$manifest"
  echo "---"
done
echo "All manifests applied."
```

## Dry Run and Diff

**Always preview changes before applying to production.**

```bash
tfy apply -f manifest.yaml --dry-run --show-diff
```

This will:
1. Compare the manifest against the current state of the resource
2. Display a diff of what would change
3. Exit without making any changes

Use this in CI/CD pipelines as a validation step before the actual apply.

## CI/CD Integration

For complete CI/CD examples (GitHub Actions, GitLab CI, generic deploy scripts), see [tfy-apply-cicd.md](tfy-apply-cicd.md).

## Error Handling

### tfy CLI Not Found
Install: `pip install 'truefoundry==0.5.0' && tfy login --host "$TFY_BASE_URL"`

### Authentication Failed
Check `TFY_BASE_URL` is correct, `TFY_API_KEY` is valid. Or re-run: `tfy login --host "$TFY_BASE_URL" --api-key "$TFY_API_KEY"`

### Invalid Manifest
Check YAML syntax, required fields (`name`, `type`, `workspace_fqn`), resource type matches structure.

### Workspace Not Found
Use `workspaces` skill to list available workspaces. Verify FQN format: `cluster-id:workspace-name`.

### Resource Conflict
Run with `--dry-run --show-diff` to see the difference. `tfy apply` is idempotent — re-applying the same manifest is safe.

### Image Pull Error
Verify image URI and tag exist. Check cluster has access to the registry. Configure image pull secrets for private registries.

### Insufficient Resources
Check CPU/memory is within cluster capacity. Verify GPU type is available. Reduce requests or contact cluster admin.
