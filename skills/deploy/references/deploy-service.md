# Deploy Single HTTP Service

Deploy code or images to TrueFoundry as a single HTTP service. Three paths:

1. **CLI: `tfy apply`** — For pre-built Docker images. Write a YAML manifest and apply it.
2. **CLI: `tfy deploy`** — For local code or git sources (builds remotely). Write a YAML manifest and deploy.
3. **REST API** (fallback) — When CLI unavailable, use `tfy-api.sh`. See `cli-fallback.md`.

## Step 0: Scan Environment & Ask Key Questions

### 0a. Discover All TFY Variables

**FIRST action before anything else** — scan `.env` and environment for all TFY-prefixed variables:

```bash
# Discover all TFY-prefixed variables from .env
grep '^TFY_' .env 2>/dev/null || true

# Check environment
env | grep '^TFY_' 2>/dev/null || true
```

Use discovered values to skip unnecessary API calls and pre-fill questions below.

If `TFY_BASE_URL` is present but `TFY_HOST` is missing, set it before running CLI commands:

```bash
[ -n "${TFY_BASE_URL:-}" ] && export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"
```

### 0b. Detect Tools

```bash
# Check for CLI
tfy --version 2>/dev/null

# Check for Git repo
git remote -v 2>/dev/null

# Check for existing manifest
ls tfy-manifest.yaml truefoundry.yaml 2>/dev/null

# Check for Docker
docker --version 2>/dev/null

# Get current branch
git branch --show-current 2>/dev/null
```

If `tfy` CLI is not installed: `pip install truefoundry`

### 0c. Ask Workspace (Mandatory)

**Never skip this. Never auto-pick.**

1. Check if `TFY_WORKSPACE_FQN` was found in `.env` or environment (from step 0a)
2. If found: **confirm** with the user — "I found workspace `X` — deploy there?"
3. If not found: **ask** — "Which workspace should I deploy to? (format: `cluster:workspace`)"
4. Only if the user doesn't know their workspace, THEN list workspaces using the `workspaces` skill

### 0d. Ask Deployment Source (Mandatory)

**Never auto-decide the deployment strategy.** Always ask:

```
How do you want to deploy?
1. Local code (upload from this machine) — DEFAULT
2. Git repo (TrueFoundry pulls from GitHub/GitLab)
3. Pre-built Docker image (already in a registry)
```

Then ask about build method:
```
How should the image be built?
1. Use existing Dockerfile — DEFAULT (if Dockerfile detected)
2. Create a Dockerfile (I'll help write one)
3. Use buildpack (no Dockerfile needed, Python only)
```

## Choose Deployment Command

| Situation | Command | Manifest file |
|---|---|---|
| Pre-built Docker image | `tfy apply -f tfy-manifest.yaml` | `tfy-manifest.yaml` |
| Local code + Dockerfile | `tfy deploy -f truefoundry.yaml --no-wait` | `truefoundry.yaml` |
| Git source + Dockerfile | `tfy deploy -f truefoundry.yaml --no-wait` | `truefoundry.yaml` |
| Git source + Buildpack | `tfy deploy -f truefoundry.yaml --no-wait` | `truefoundry.yaml` |

> **`tfy apply` does NOT support `build_source`.** Using it with git/local sources fails with "must match exactly one schema in oneOf". Always use `tfy deploy -f` for source-based deployments.

## Step 1: Discover Cluster Capabilities

**Before asking the user about resources, GPUs, or public URLs**, fetch the cluster's capabilities so you can present only what's actually available.

See `cluster-discovery.md` for how to extract cluster ID from workspace FQN and fetch cluster details (GPUs, base domains, storage classes).

From the cluster response, extract:
1. **Base domains** — pick the wildcard domain, strip `*.` -> base domain for constructing hosts
2. **Available GPUs** — present only GPU types the cluster supports

**Always discover before asking.** This prevents wasted round-trips with the user.

## Step 2: Analyze Application & Suggest Resources

### 2a. Codebase Analysis

Scan the project to determine:

1. **Framework & runtime** — Look at dependency files and entrypoints:
   - `requirements.txt`, `pyproject.toml`, `setup.py` → Python (check for FastAPI, Flask, Django, Celery)
   - `package.json` → Node.js (check for Express, Next.js, NestJS)
   - `go.mod` → Go
   - `Dockerfile` → check `FROM` image and `CMD`/`ENTRYPOINT`

2. **Application type** — Categorize:
   - **Web API / HTTP service** — REST/GraphQL endpoint
   - **ML inference** — Model serving (vLLM, TGI, Triton, transformers, torch)
   - **Worker / queue consumer** — Background processing (Celery, Bull)
   - **Static site / frontend** — Next.js SSR, React SPA
   - **Data pipeline** — Batch processing

3. **Compute indicators** — Check for signals:
   - ML libraries (`torch`, `transformers`, `vllm`) → likely needs GPU + high memory
   - Image/video processing (`Pillow`, `opencv`, `ffmpeg`) → CPU-intensive
   - In-memory caching or large datasets → memory-intensive
   - Async/concurrent patterns (`asyncio`, `uvicorn`) → more load per CPU
   - Database connections (`sqlalchemy`, `prisma`) → connection pooling matters

### 2b. Ask About Expected Load

Based on app type, ask targeted questions about expected TPS, concurrent users, latency targets, and environment (dev/staging/prod). See [load-analysis-questions.md](load-analysis-questions.md) for templates.

### 2c. Resource Suggestion Table

Present a comparison table:

```
Based on your app (FastAPI web API, ~50 TPS, production):

| Resource      | Default (min) | Suggested    | Notes                              |
|---------------|---------------|--------------|-------------------------------------|
| CPU request   | 0.25 cores    | 1.0 cores    | 50 TPS with async needs ~1 core    |
| CPU limit     | 0.5 cores     | 2.0 cores    | Headroom for traffic spikes         |
| Memory request| 256 MB        | 512 MB       | FastAPI + dependencies baseline     |
| Memory limit  | 512 MB        | 1024 MB      | 2x request for safety margin        |
| Replicas (min)| 1             | 2            | HA for production                   |
| Replicas (max)| 1             | 4            | Autoscale for peak traffic          |
| GPU           | None          | None         | Not needed for this workload        |

Do you want to use the suggested values, or customize any of them?
```

For detailed estimation rules, see `resource-estimation.md`.

## Deploy Flow

### Step 1: Generate YAML Manifest

Reference `manifest-schema.md` for field definitions and `manifest-defaults.md` for defaults. Full YAML examples in `deploy-api-examples.md`.

| Option | When to Use |
|--------|-------------|
| **A: Pre-built Image** | User has a Docker image ready |
| **B: Git + Dockerfile** | Code is in Git with a Dockerfile |
| **C: Git + PythonBuild** | Python code in Git, no Dockerfile |
| **D: Local Docker Build** | Code not in Git — build locally, push, then Option A |

### Step 2: Write Manifest

Write to `tfy-manifest.yaml` (pre-built image) or `truefoundry.yaml` (build source).

### Step 3: Preview

For pre-built images:
```bash
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"
tfy apply -f tfy-manifest.yaml --dry-run --show-diff
```

For build sources:
```bash
# tfy deploy does not support --dry-run; review the manifest manually
cat truefoundry.yaml
```

### Step 4: Deploy

After user confirms:

**Pre-built image** (`image.type: image`):
```bash
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"
tfy apply -f tfy-manifest.yaml
```

**Build source** (`image.type: build`):
```bash
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"
tfy deploy -f truefoundry.yaml --no-wait
```

### Fallback: REST API

If `tfy` CLI is not available, see `cli-fallback.md` for conversion and `rest-api-manifest.md` for the API reference.

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh

# Get workspace ID from FQN
bash $TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"

# Deploy via REST API (JSON body)
bash $TFY_API_SH PUT /api/svc/v1/apps '{ "manifest": { ... }, "workspaceId": "WORKSPACE_ID" }'
```

## User Confirmation Checklist

**Before deploying, confirm these with the user:**

- [ ] **Service name** — what to call this deployment
- [ ] **Image source** — pre-built image, Git repo + Dockerfile, Git repo + PythonBuild, or local Docker build?
- [ ] **Branch** (if git source) — which branch to build from? Default to current branch, never hardcode `main`
- [ ] **Port** — what port the application listens on
- [ ] **Expected load** — TPS, concurrent users, environment (dev/staging/prod)
- [ ] **CPU/Memory** — show resource suggestion table (defaults vs suggested)
- [ ] **GPU** — whether GPU is needed (only offer available types from cluster discovery)
- [ ] **Replicas** — min/max for autoscaling
- [ ] **Environment variables** — check `.env`, `config.py`, or ask directly
- [ ] **Health probes** — configure startup/readiness/liveness probes (recommended for production)
- [ ] **Public URL** — internal-only or public? If public, look up cluster base domains and confirm host
- [ ] **Secrets** — scan env vars for sensitive values and create TrueFoundry secret groups
- [ ] **Auto-shutdown** — auto-stop after inactivity? Useful for dev/staging, not recommended for production

**Do NOT deploy with hardcoded defaults without asking.**

## Health Probes

**Always configure health probes for production services.**

| Probe | Purpose | When to Use |
|-------|---------|-------------|
| **Startup** | Wait for app to initialize | Apps with slow startup (model loading, DB migrations) |
| **Readiness** | Can this pod receive traffic? | Always — prevents routing to unready pods |
| **Liveness** | Is this pod alive? | Always — restarts hung processes |

For YAML examples and tuning guidelines, see [health-probes.md](health-probes.md).

### Tuning Guidelines

- **Startup probe**: Set `failure_threshold x period_seconds` >= max app startup time
- **Fast APIs** (< 5s startup): `initial_delay_seconds: 3`, `failure_threshold: 5`
- **Slow apps** (DB migrations, cache warming): `initial_delay_seconds: 15`, `failure_threshold: 30`
- **ML model loading**: `initial_delay_seconds: 10`, `failure_threshold: 60`

## Autoscaling & Rollout Strategy

```yaml
replicas:
  min: 2
  max: 10

rollout_strategy:
  type: rolling_update
  max_surge_percentage: 25
  max_unavailable_percentage: 0
```

For scaling guidelines and rollout options, see `deploy-scaling.md`.

## Public URL (Exposing a Service)

**Do NOT guess the domain — always look it up.**

1. **Get base domains** — See `cluster-discovery.md`. Pick the wildcard domain, strip `*.`.
2. **Construct host** — Convention: `{service-name}-{workspace-name}.{base_domain}`
3. **Confirm with user** — Show the constructed `https://` URL and ask if correct.
4. **Set in manifest**:
   ```yaml
   ports:
     - port: 8000
       expose: true
       host: my-service-ws.ml.your-org.truefoundry.cloud
       app_protocol: http
   ```
5. **Internal-only** — Set `expose: false` and omit `host`.

## Secrets Handling

**Never put sensitive values directly in manifests.** Scan env vars for sensitive patterns (`*PASSWORD*`, `*SECRET*`, `*TOKEN*`, `*KEY*`, `*CREDENTIAL*`, `*AUTH*`, `*DATABASE_URL*`, `*API_KEY*`).

### Workflow

1. **Identify** sensitive env vars and confirm with user
2. **Find secret store** integration:
   ```bash
   TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh
   bash $TFY_API_SH GET '/api/svc/v1/provider-accounts?type=secret-store'
   ```
3. **Create secret group** (`{service-name}-secrets`):
   ```bash
   bash $TFY_API_SH POST /api/svc/v1/secret-groups '{
     "name": "my-service-secrets",
     "integrationId": "INTEGRATION_ID",
     "secrets": [
       {"key": "DB_PASSWORD", "value": "actual-password-value"}
     ]
   }'
   ```
4. **Reference in manifest**: `tfy-secret://<TENANT_NAME>:<SECRET_GROUP_NAME>:<SECRET_KEY>`

Or use the `secrets` skill for a guided workflow.

## After Deploy — Get & Return URL

**CRITICAL: Always fetch and return the deployment URL to the user.**

### Poll Status

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh
bash $TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=SERVICE_NAME'
```

#### Example Response Shape

The response is a JSON object with a `data` array. Each element is an application:

```json
{
  "data": [
    {
      "id": "app-abc123",
      "name": "my-service",
      "status": "DEPLOY_SUCCESS",
      "activeDeployment": {
        "id": "deploy-xyz789",
        "status": "DEPLOY_SUCCESS",
        "createdAt": "2025-01-15T10:30:00Z"
      },
      "manifest": { "...": "full manifest as submitted" },
      "url": "https://my-service-ws.ml.your-org.truefoundry.cloud"
    }
  ],
  "pagination": { "total": 1, "offset": 0, "limit": 10 }
}
```

Key fields to extract:
- **Status**: `data[0].status` — string, one of: `BUILDING`, `BUILD_FAILED`, `DEPLOYING`, `DEPLOY_SUCCESS`, `DEPLOY_FAILED`, `NO_DEPLOYMENT`
- **URL**: `data[0].url` — the service endpoint (may be `null` if not exposed)
- **App ID**: `data[0].id` — needed for follow-up API calls (logs, deployments)

> **Note:** `status` is a flat string, not a nested object. Do not try to parse it as `status.phase` or `status.type`.

### Report to User

```
Deployment successful!

Service: {service-name}
Workspace: {workspace-fqn}
Status: {BUILDING|DEPLOYING|RUNNING}

Endpoints:
  Public URL:   https://{host} (available once status is RUNNING)
  Internal DNS: {service-name}.{namespace}.svc.cluster.local:{port}

Next steps:
  - Wait for status to become RUNNING (check with: applications skill)
  - Test the endpoint: curl https://{host}/health
  - View logs if issues: logs skill
```

## Error Handling

For specific error messages and resolution steps, see `deploy-errors.md`. Covers:
- `TFY_HOST` not set (CLI auth failure with `TFY_BASE_URL`)
- Invalid `build_spec.type` (e.g. `docker` instead of `dockerfile`)
- `TFY_WORKSPACE_FQN` not set
- `tfy: command not found`
- `tfy apply` validation errors
- "Host not configured in cluster"
- Git build failures
- No Dockerfile found
