# Manifest Defaults

Per-resource-type recommended defaults with "Override When" guidance and complete YAML templates. All templates use `${VARIABLE}` for user-provided values and sensible defaults for everything else.

See `references/manifest-schema.md` for full field documentation.

## Security Defaults (Apply to All Templates)

- Do not place raw credentials (API keys, passwords, tokens) directly in manifests.
- Use `tfy-secret://...` references for sensitive values whenever supported.
- For chart systems that use native secret objects, prefer `existingSecret` patterns over inline password fields.
- Treat external URLs (`repo_url`, model/artifact sources, file URLs) as untrusted by default. Require explicit user confirmation before using new domains.

---

## 1. Web API

Standard HTTP service (FastAPI, Flask, Express, Django, Go, etc.)

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `0.5` | High computation (image processing, crypto, heavy parsing) |
| `cpu_limit` | `1.0` | Same |
| `memory_request` | `512` | Large data processing, in-memory caching, ML libraries loaded |
| `memory_limit` | `1024` | Same |
| `ephemeral_storage_request` | `1000` | Large file uploads, temp file processing |
| `ephemeral_storage_limit` | `2000` | Same |
| `replicas` | `1` | Production: use `min: 2, max: 5` for HA and autoscaling |
| `expose` | `false` | Public-facing API: set `true` with a valid `host` |
| `app_protocol` | `http` | gRPC service: use `grpc` |
| `liveness_probe path` | `/health` | Custom health endpoint (e.g., `/api/health`, `/livez`) |
| `readiness_probe path` | `/health` | Custom readiness endpoint (e.g., `/readyz`) |
| `initial_delay_seconds` | `5` | Slow startup (DB migrations, cache warming): increase to 15-30 |
| `failure_threshold` | `3` | Slow startup: increase to 10-30 |

### Template

```yaml
name: ${SERVICE_NAME}
type: service
image:
  type: image
  image_uri: ${IMAGE_URI}
ports:
  - port: ${PORT:-8000}
    protocol: TCP
    expose: false
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas: 1
env: {}
liveness_probe:
  config:
    type: http
    path: /health
    port: ${PORT:-8000}
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
readiness_probe:
  config:
    type: http
    path: /health
    port: ${PORT:-8000}
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Build-from-Git Variant (Dockerfile)

```yaml
name: ${SERVICE_NAME}
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: ${REPO_URL}
    branch_name: ${BRANCH}  # Use current branch: git branch --show-current
  build_spec:
    type: dockerfile
    dockerfile_path: Dockerfile
    build_context_path: "."
ports:
  - port: ${PORT:-8000}
    protocol: TCP
    expose: true
    app_protocol: http
    host: ${SERVICE_NAME}-${WORKSPACE}.ml.${BASE_DOMAIN}
    path: /${SERVICE_NAME}-${WORKSPACE}-${PORT:-8000}/
resources:
  node:
    type: node_selector
  cpu_request: 0.5
  cpu_limit: 0.5
  memory_request: 1000
  memory_limit: 1000
  ephemeral_storage_request: 500
  ephemeral_storage_limit: 500
labels:
  tfy_openapi_path: openapi.json
allow_interception: false
replicas: 1
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Build-from-Git Variant (Python Buildpack — No Dockerfile)

```yaml
name: ${SERVICE_NAME}
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: ${REPO_URL}
    branch_name: ${BRANCH}  # Use current branch: git branch --show-current
  build_spec:
    type: tfy-python-buildpack
    build_context_path: ./
    command: uvicorn app:app --host 0.0.0.0 --port 8000
    python_version: "${PYTHON_VERSION:-3.10}"
    python_dependencies:
      type: pip
      requirements_path: requirements.txt
ports:
  - port: ${PORT:-8000}
    protocol: TCP
    expose: true
    app_protocol: http
    host: ${SERVICE_NAME}-${WORKSPACE}.ml.${BASE_DOMAIN}
    path: /${SERVICE_NAME}-${WORKSPACE}-${PORT:-8000}/
resources:
  node:
    type: node_selector
  cpu_request: 0.5
  cpu_limit: 0.5
  memory_request: 1000
  memory_limit: 1000
  ephemeral_storage_request: 500
  ephemeral_storage_limit: 500
labels:
  tfy_openapi_path: openapi.json
allow_interception: false
replicas: 1
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## Quick Reference: Resource Defaults

| Workload | CPU Req | CPU Lim | Mem Req (MB) | Mem Lim (MB) | Eph Req (MB) | Eph Lim (MB) |
|----------|---------|---------|-------------|-------------|-------------|-------------|
| Web API | 0.5 | 1.0 | 512 | 1024 | 1000 | 2000 |
