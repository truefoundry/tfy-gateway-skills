# REST API Manifest Reference

> **This is the fallback path** when the `tfy` CLI is not available. For the primary deployment method, use `tfy apply -f manifest.yaml`. See `cli-fallback.md` for the detection and fallback flow.

Deploy services and jobs to TrueFoundry using `PUT /api/svc/v1/apps` — no Python SDK required.

## Setup

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh
```

See `references/tfy-api-setup.md` for agent-specific paths.

## Step 1: Get Workspace ID

The API requires the internal workspace ID (not the FQN). Look it up:

```bash
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"
```

Extract the `id` field from the response. Use this as `workspaceId` in the deploy call.

## Service Manifests

### Pre-built Image

Deploy an existing Docker image directly (no build step):

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-service",
    "type": "service",
    "image": {
      "type": "image",
      "image_uri": "docker.io/myorg/my-api:v1.0"
    },
    "ports": [
      {
        "port": 8000,
        "protocol": "TCP",
        "expose": true,
        "host": "my-service-ws.ml.your-org.truefoundry.cloud",
        "app_protocol": "http"
      }
    ],
    "resources": {
      "cpu_request": 0.5,
      "cpu_limit": 1,
      "memory_request": 512,
      "memory_limit": 1024,
      "ephemeral_storage_request": 1000,
      "ephemeral_storage_limit": 2000
    },
    "env": {
      "LOG_LEVEL": "info"
    },
    "replicas": 1,
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}'
```

### Git Repo + Dockerfile (Remote Build)

TrueFoundry clones the repo and builds from your Dockerfile:

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-service",
    "type": "service",
    "image": {
      "type": "build",
      "build_source": {
        "type": "git",
        "repo_url": "https://github.com/user/repo",
        "branch_name": "main"
      },
      "build_spec": {
        "type": "dockerfile",
        "dockerfile_path": "Dockerfile",
        "build_context_path": "."
      }
    },
    "ports": [
      {
        "port": 8000,
        "protocol": "TCP",
        "expose": true,
        "host": "my-service-ws.ml.your-org.truefoundry.cloud",
        "app_protocol": "http"
      }
    ],
    "resources": {
      "cpu_request": 0.5,
      "cpu_limit": 1,
      "memory_request": 512,
      "memory_limit": 1024,
      "ephemeral_storage_request": 1000,
      "ephemeral_storage_limit": 2000
    },
    "replicas": 1,
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}'
```

### Git Repo + PythonBuild (No Dockerfile)

TrueFoundry auto-builds a Python app from Git — no Dockerfile needed:

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-service",
    "type": "service",
    "image": {
      "type": "build",
      "build_source": {
        "type": "git",
        "repo_url": "https://github.com/user/repo",
        "branch_name": "main"
      },
      "build_spec": {
        "type": "python",
        "python_version": "3.12",
        "requirements_path": "requirements.txt",
        "command": "uvicorn main:app --host 0.0.0.0 --port 8000"
      }
    },
    "ports": [
      {
        "port": 8000,
        "protocol": "TCP",
        "expose": true,
        "host": "my-service-ws.ml.your-org.truefoundry.cloud",
        "app_protocol": "http"
      }
    ],
    "resources": {
      "cpu_request": 0.5,
      "cpu_limit": 1,
      "memory_request": 512,
      "memory_limit": 1024,
      "ephemeral_storage_request": 1000,
      "ephemeral_storage_limit": 2000
    },
    "replicas": 1,
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}'
```

## Job Manifest

Jobs run to completion and exit. Use `"type": "job"` instead of `"type": "service"`:

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-job",
    "type": "job",
    "image": {
      "type": "image",
      "image_uri": "docker.io/myorg/my-job:v1.0",
      "command": ["python", "run_job.py"]
    },
    "resources": {
      "cpu_request": 1,
      "cpu_limit": 2,
      "memory_request": 1024,
      "memory_limit": 2048,
      "ephemeral_storage_request": 1000,
      "ephemeral_storage_limit": 2000
    },
    "env": {},
    "retries": 0,
    "timeout": 3600,
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}'
```

Jobs also support `build_source` + `build_spec` for Git-based builds — same format as services.

## Field Reference

### Top-level fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `manifest` | object | Yes | The application manifest |
| `workspaceId` | string | Yes | Internal workspace ID (from GET workspaces API, not the FQN) |

### Manifest fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | — | Service/job name (lowercase, alphanumeric, hyphens) |
| `type` | string | Yes | — | `"service"` or `"job"` |
| `image` | object | Yes | — | Image source — see Image section |
| `ports` | array | Service only | — | Port configurations — see Ports section |
| `resources` | object | Yes | — | CPU, memory, GPU, storage — see Resources section |
| `env` | object | No | `{}` | Environment variables as key-value pairs |
| `replicas` | int or object | No | `1` | Fixed int or `{"min": N, "max": M}` for autoscaling |
| `workspace_fqn` | string | Yes | — | Workspace FQN (format: `cluster-id:workspace-name`) |
| `liveness_probe` | object | No | — | Liveness probe config (see `health-probes.md`) |
| `readiness_probe` | object | No | — | Readiness probe config |
| `startup_probe` | object | No | — | Startup probe config |
| `rollout_strategy` | object | No | — | Rolling update config |

### Image (pre-built)

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `"image"` |
| `image_uri` | string | Full image URI with tag (e.g. `docker.io/org/app:v1`) |
| `command` | array | Override container command (optional — omit if not needed) |

### Image (Git build)

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `"build"` |
| `build_source.type` | string | `"git"` |
| `build_source.repo_url` | string | Git repository URL |
| `build_source.branch_name` | string | Branch or ref to build from |
| `build_spec.type` | string | `"dockerfile"` or `"python"` |
| `build_spec.dockerfile_path` | string | Path to Dockerfile (for `"dockerfile"` type) |
| `build_spec.build_context_path` | string | Build context directory (for `"dockerfile"` type) |
| `build_spec.python_version` | string | Python version (for `"python"` type) |
| `build_spec.requirements_path` | string | Path to requirements.txt (for `"python"` type) |
| `build_spec.command` | string | Start command (for `"python"` type) |

### Ports

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `port` | int | — | Container port number |
| `protocol` | string | `"TCP"` | `"TCP"` or `"UDP"` |
| `expose` | bool | `false` | Whether to expose externally |
| `host` | string | — | Hostname for external access (required if `expose: true`) |
| `app_protocol` | string | `"http"` | `"http"` or `"grpc"` |

### Resources

| Field | Type | Unit | Description |
|-------|------|------|-------------|
| `cpu_request` | float | cores | Guaranteed CPU |
| `cpu_limit` | float | cores | Maximum CPU |
| `memory_request` | int | MB | Guaranteed memory |
| `memory_limit` | int | MB | Maximum memory |
| `ephemeral_storage_request` | int | MB | Guaranteed disk |
| `ephemeral_storage_limit` | int | MB | Maximum disk |
| `devices` | array | — | GPU devices (see GPU section) |

### GPU Devices

```json
{
  "devices": [
    {
      "type": "nvidia.com/gpu",
      "name": "A10G",
      "count": 1
    }
  ]
}
```

Check available GPU types with the cluster discovery API before specifying.

## Gotchas

1. **Don't set `"command": null`** — Omit the `command` field entirely if not needed. Setting it to `null` can cause errors.
2. **Memory values are in MB** — Not bytes, not GB. `512` means 512 MB.
3. **`workspaceId` is the internal ID, not the FQN** — Fetch it from `GET /api/svc/v1/workspaces?fqn=...`. The FQN goes in `manifest.workspace_fqn`.
4. **`replicas` can be int or object** — Use `1` for fixed, or `{"min": 2, "max": 10}` for autoscaling.
5. **`host` must match cluster base domains** — Use `references/cluster-discovery.md` to look up valid domains. Wrong domain → "Provided host is not configured in cluster" error.
6. **Ephemeral storage is required** — Always include `ephemeral_storage_request` and `ephemeral_storage_limit`.
7. **Git repo must be accessible** — For private repos, ensure credentials are configured in TrueFoundry. Public repos work directly.

## Polling Deployment Status

After deploying, poll for status:

```bash
# Get the app by name and workspace
$TFY_API_SH GET "/api/svc/v1/apps?workspaceFqn=${TFY_WORKSPACE_FQN}&applicationName=SERVICE_NAME"
```

Look for `status` in the response (a flat string, not a nested object). Common values: `BUILDING`, `BUILD_FAILED`, `DEPLOYING`, `DEPLOY_SUCCESS`, `DEPLOY_FAILED`, `NO_DEPLOYMENT`.
