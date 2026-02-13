---
name: tfy-apply
description: This skill should be used when the user says "tfy apply", "apply manifest", "deploy from yaml", "declarative deployment", "apply yaml to truefoundry", "gitops deploy", "apply tfy manifest", or wants to create/update TrueFoundry resources from YAML manifest files using the tfy CLI.
allowed-tools: Bash(tfy*), Bash(*/tfy-api.sh *)
---

# TFY Apply — Declarative Resource Management

Create or update TrueFoundry resources from YAML manifest files using `tfy apply`. This is analogous to `kubectl apply` — you describe the desired state in a YAML file and the CLI reconciles it.

## When to Use

- User says "tfy apply", "apply manifest", "deploy from yaml"
- User wants declarative, file-based deployments (GitOps style)
- User wants to store deployment configs in Git and apply via CI/CD
- User wants to batch-apply multiple resources at once
- User wants reproducible deployments across environments
- User has a TrueFoundry YAML manifest and wants to apply it
- User wants to preview changes before applying (`--dry-run`)

## When NOT to Use

- User wants to deploy local code with auto-build → use `deploy` skill (Python SDK)
- User wants to deploy a Helm chart interactively → use `helm` skill
- User wants to list or inspect existing deployments → use `applications` skill
- User wants to check connection/credentials → use `status` skill

## Prerequisites

**Always verify before applying:**

1. **tfy CLI** — Must be installed and available on PATH
2. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`), or the user must have run `tfy login`
3. **Workspace** — `TFY_WORKSPACE_FQN` is required in the manifest. Never auto-pick. Ask the user if missing.

```bash
# Check tfy CLI is installed
tfy --version

# Check credentials
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
echo "TFY_WORKSPACE_FQN: ${TFY_WORKSPACE_FQN:-(not set)}"
```

**If tfy CLI is not installed**, guide the user:
```bash
pip install truefoundry
tfy login --host "$TFY_BASE_URL"
```

**If TFY_WORKSPACE_FQN is not set, STOP. Ask the user.** Suggest they use the `workspaces` skill or check the TrueFoundry dashboard.

## Basic Usage

```bash
# Apply a single manifest
tfy apply -f manifest.yaml

# Preview changes without applying (dry run)
tfy apply -f manifest.yaml --dry-run --show-diff
```

**Always recommend running `--dry-run --show-diff` first** so the user can review what will change before committing.

## Manifest Format

A TrueFoundry manifest is a YAML file with a `name`, `type`, and type-specific configuration. The `type` field determines the resource kind.

### Service Manifest

Deploys a long-running HTTP service.

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
    host: my-api-service-my-ws.example.truefoundry.cloud
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
  DATABASE_URL: postgres://user:pass@db-host:5432/mydb
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

Runs a batch or scheduled workload.

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

Deploys a Helm chart (databases, caches, infrastructure components).

```yaml
name: postgres-prod
type: helm
source:
  type: oci-repo
  version: "16.7.21"
  oci_chart_url: oci://registry-1.docker.io/bitnamicharts/postgresql
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

## Environment Variable Substitution

Manifests support environment variable substitution, which is essential for CI/CD pipelines where values differ per environment.

### Using Shell Envsubst

Use `envsubst` to template manifests before applying:

```bash
# manifest-template.yaml
# name: my-service
# type: service
# image:
#   type: image
#   image_uri: docker.io/myorg/my-api:${IMAGE_TAG}
# workspace_fqn: ${TFY_WORKSPACE_FQN}

# Substitute and apply
export IMAGE_TAG="v1.2.3"
export TFY_WORKSPACE_FQN="cluster-id:production-ws"
envsubst < manifest-template.yaml | tfy apply -f -
```

### Per-Environment Manifests

Maintain separate manifests per environment:

```
manifests/
  base.yaml           # shared config
  dev.yaml            # dev overrides
  staging.yaml        # staging overrides
  production.yaml     # production overrides
```

Or use a single template with environment-specific variables:

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
# Apply each manifest separately
tfy apply -f service.yaml
tfy apply -f database.yaml
tfy apply -f worker.yaml
```

### Script for Batch Apply

```bash
#!/bin/bash
# apply-all.sh — apply all manifests in a directory
set -euo pipefail

MANIFEST_DIR="${1:-.}"

for manifest in "$MANIFEST_DIR"/*.yaml; do
  echo "Applying: $manifest"
  tfy apply -f "$manifest"
  echo "---"
done

echo "All manifests applied."
```

```bash
# Apply all manifests in a directory
./apply-all.sh manifests/
```

## Dry Run and Diff

**Always preview changes before applying to production.**

```bash
# Show what would change without applying
tfy apply -f manifest.yaml --dry-run --show-diff
```

This will:
1. Compare the manifest against the current state of the resource
2. Display a diff of what would change
3. Exit without making any changes

Use this in CI/CD pipelines as a validation step before the actual apply.

## Integration with CI/CD

### GitHub Actions

```yaml
name: Deploy to TrueFoundry
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install tfy CLI
        run: pip install truefoundry

      - name: Login to TrueFoundry
        env:
          TFY_BASE_URL: ${{ secrets.TFY_BASE_URL }}
          TFY_API_KEY: ${{ secrets.TFY_API_KEY }}
        run: tfy login --host "$TFY_BASE_URL" --api-key "$TFY_API_KEY"

      - name: Preview changes
        run: |
          export IMAGE_TAG="${{ github.sha }}"
          export TFY_WORKSPACE_FQN="${{ vars.TFY_WORKSPACE_FQN }}"
          envsubst < manifest.yaml | tfy apply -f - --dry-run --show-diff

      - name: Apply manifest
        run: |
          export IMAGE_TAG="${{ github.sha }}"
          export TFY_WORKSPACE_FQN="${{ vars.TFY_WORKSPACE_FQN }}"
          envsubst < manifest.yaml | tfy apply -f -
```

### GitLab CI

```yaml
deploy:
  stage: deploy
  image: python:3.12-slim
  before_script:
    - pip install truefoundry
    - tfy login --host "$TFY_BASE_URL" --api-key "$TFY_API_KEY"
  script:
    - export IMAGE_TAG="$CI_COMMIT_SHA"
    - envsubst < manifest.yaml | tfy apply -f -
  only:
    - main
```

### Generic CI/CD Pattern

```bash
#!/bin/bash
# deploy.sh — generic CI/CD deploy script
set -euo pipefail

# 1. Install CLI
pip install truefoundry

# 2. Authenticate
tfy login --host "$TFY_BASE_URL" --api-key "$TFY_API_KEY"

# 3. Substitute environment variables
envsubst < manifest.yaml > manifest-resolved.yaml

# 4. Preview changes
echo "=== Dry Run ==="
tfy apply -f manifest-resolved.yaml --dry-run --show-diff

# 5. Apply
echo "=== Applying ==="
tfy apply -f manifest-resolved.yaml

# 6. Cleanup
rm -f manifest-resolved.yaml
```

## Composability

- **Check credentials first**: Use `status` skill to verify TrueFoundry connectivity
- **Find workspace**: Use `workspaces` skill to get workspace FQN before writing manifests
- **Inspect deployed resources**: Use `applications` skill after applying to verify
- **View logs**: Use `logs` skill to check application logs after apply
- **Manage secrets**: Use `secrets` skill to create secret groups referenced in manifests
- **Deploy Helm charts**: The `helm` skill provides interactive Helm chart deployment; use `tfy-apply` when you have the manifest ready
- **Deploy with SDK**: The `deploy` skill deploys local code with auto-build; use `tfy-apply` for pre-built images and declarative configs

## Error Handling

### tfy CLI Not Found
```
tfy: command not found
Install the TrueFoundry CLI:
  pip install truefoundry
  tfy login --host "$TFY_BASE_URL"
```

### Authentication Failed
```
Authentication error or 401 Unauthorized.
Check:
- TFY_BASE_URL is correct
- TFY_API_KEY is valid and not expired
- Or re-run: tfy login --host "$TFY_BASE_URL" --api-key "$TFY_API_KEY"
```

### Invalid Manifest
```
Manifest validation failed.
Check:
- YAML syntax is valid (use yamllint or a YAML validator)
- Required fields are present: name, type, workspace_fqn
- Resource type matches the manifest structure (service, job, helm)
- Image URI is reachable from the cluster
```

### Workspace Not Found
```
Workspace FQN not found or invalid.
Check:
- Workspace exists: use `workspaces` skill to list available workspaces
- FQN format is correct: cluster-id:workspace-name
- You have access to the workspace
```

### Resource Conflict
```
Resource already exists with different configuration.
Options:
- Run with --dry-run --show-diff to see the difference
- Update the manifest to match desired state and re-apply
- tfy apply is idempotent — re-applying the same manifest is safe
```

### Image Pull Error
```
Failed to pull image.
Check:
- Image URI is correct and the tag exists
- The cluster has access to the container registry
- Image pull secrets are configured if using a private registry
```

### Insufficient Resources
```
Deployment failed: Insufficient resources.
Check:
- Requested CPU/memory is within cluster capacity
- GPU type is available on the cluster (use deploy skill's Step 0 to check)
- Reduce resource requests or contact cluster admin
```
