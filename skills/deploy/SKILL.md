---
name: deploy
description: Deploys code or container images to TrueFoundry as HTTP services. Supports YAML manifests with `tfy apply`, Git-based remote builds, and pre-built images. Use when deploying apps, shipping services to production, or hosting web services on TrueFoundry.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
metadata:
  disable-model-invocation: "true"
allowed-tools: Bash(tfy*) Bash(*/tfy-api.sh *) Bash(*/tfy-version.sh *) Bash(docker *)
---

<objective>

# Deploy to TrueFoundry

Deploy code or images to TrueFoundry. Two paths:

1. **CLI** (`tfy apply`) — Write a YAML manifest and apply it. Works everywhere.
2. **REST API** (fallback) — When CLI unavailable, use `tfy-api.sh`.

Use the CLI path by default. Fall back to REST API only if `tfy` CLI is not installed and the user cannot install it.

## When to Use

- User says "deploy", "deploy to truefoundry", "ship this"
- User wants to push code or images to TrueFoundry
- User says "deploy and check status"

## When NOT to Use

- User wants to see what's deployed -> use `applications` skill
- User wants to check workspace -> use `workspaces` skill

</objective>

<context>

## Prerequisites

**Always verify before deploying:**

1. **Credentials** -- `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** -- `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**
3. **CLI** -- Check if `tfy` CLI is available

For credential check commands and .env setup, see `references/prerequisites.md`.

## Choose Deployment Path

**Default to CLI (`tfy apply`).** Only use REST API if CLI is unavailable.

| User's situation | Path |
|---|---|
| Has a pre-built Docker image | YAML manifest + `tfy apply` |
| Code is in a Git repo | YAML manifest with git build source + `tfy apply` |
| Code is local-only, has Docker | Docker build locally -> YAML manifest with image + `tfy apply` |
| Code is local-only, no Docker | Push code to Git first -> YAML manifest with git build |
| Has existing manifest.yaml | `tfy apply -f manifest.yaml` directly |

### Detection Steps

1. Check: Is the `tfy` CLI installed? (`tfy --version`)
   - If not: `pip install truefoundry` to install it
2. Check: Is the code in a Git repository? (`git remote -v`) -> If yes, use YAML manifest with Git build
3. Ask: "Do you have a pre-built Docker image?" -> If yes, use YAML manifest with image
4. If local code only: check for `docker` -> Docker build + YAML manifest with image
5. Otherwise -> suggest pushing code to Git first, then YAML manifest with git build

## Step 0: Detect Environment

**Before anything else**, check what tools are available:

```bash
# Check for CLI
tfy --version 2>/dev/null

# Check for Git repo
git remote -v 2>/dev/null

# Check for existing manifest
ls tfy-manifest.yaml 2>/dev/null

# Check for Docker (only matters for local build path)
docker --version 2>/dev/null
```

If `tfy` CLI is not installed:
```bash
pip install truefoundry
```

</context>

<instructions>

## Step 1: Discover Cluster Capabilities

**Before asking the user about resources, GPUs, or public URLs**, fetch the cluster's capabilities so you can present only what's actually available.

Fetch the cluster's capabilities before asking about resources or public URLs. See `references/cluster-discovery.md` for how to extract cluster ID from workspace FQN and fetch cluster details (GPUs, base domains, storage classes).

### Extract Available Capabilities

From the cluster response, extract:
1. **Base domains** -- pick the wildcard domain, strip `*.` -> base domain for constructing hosts.
2. **Available GPUs** -- present only GPU types the cluster supports, not a generic list.

### Why This Matters

- Deploying with an unsupported GPU type -> API error
- Using wrong base domain -> "Provided host is not configured in cluster"
- These are the #1 and #2 most common deployment failures

**Always discover before asking.** This prevents wasted round-trips with the user.

## Step 2: Analyze Application & Suggest Resources

**Before asking about CPU/memory/GPU**, analyze the user's codebase and ask about expected load. This produces informed resource suggestions instead of arbitrary defaults.

### 2a. Codebase Analysis

Scan the project to determine:

1. **Framework & runtime** -- Look at dependency files and entrypoints:
   - `requirements.txt`, `pyproject.toml`, `setup.py` -> Python (check for FastAPI, Flask, Django, Celery, etc.)
   - `package.json` -> Node.js (check for Express, Next.js, NestJS, etc.)
   - `go.mod` -> Go
   - `Dockerfile` -> check `FROM` image and `CMD`/`ENTRYPOINT`

2. **Application type** -- Categorize what the app does:
   - **Web API / HTTP service** -- REST/GraphQL endpoint (FastAPI, Express, Django, etc.)
   - **ML inference** -- Model serving (vLLM, TGI, Triton, transformers, torch, etc.)
   - **Worker / queue consumer** -- Background processing (Celery, Bull, etc.)
   - **Static site / frontend** -- Next.js SSR, React SPA, etc.
   - **Data pipeline** -- Batch processing (Spark, pandas, etc.)

3. **Compute indicators** -- Check for signals that affect resource needs:
   - ML libraries (`torch`, `transformers`, `vllm`, `tensorflow`) -> likely needs GPU + high memory
   - Image/video processing (`Pillow`, `opencv`, `ffmpeg`) -> CPU-intensive
   - In-memory caching or large datasets (`redis`, `pandas` with large files) -> memory-intensive
   - Async/concurrent patterns (`asyncio`, `uvicorn workers`, `gunicorn`) -> can handle more load per CPU
   - Database connections (`sqlalchemy`, `prisma`, `mongoose`) -> connection pooling matters

### 2b. Ask About Expected Load

Based on the app type, ask the user targeted questions about expected TPS, concurrent users, latency targets, and environment (dev/staging/prod). For detailed question templates by app type (Web APIs, ML inference, workers), see [references/load-analysis-questions.md](references/load-analysis-questions.md).

### 2c. Resource Suggestion Table

Present a comparison table with defaults, suggested values, and let the user choose:

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

### Resource Estimation Guidelines

For detailed CPU, memory, GPU, and replica estimation rules of thumb, see `references/resource-estimation.md`. Key points:

- Always check available GPU types on the cluster (Step 1)
- Memory limit should be 1.5-2x the request
- Production: min 2 replicas for high availability
- GPU VRAM needed ~ model parameter count x 2 bytes (FP16)

### Important Notes

- **Always show the suggestion table** -- Don't just pick values silently. Users should see the reasoning.
- **Let users override** -- Suggestions are starting points, not mandates.
- **Mention trade-offs** -- More resources = higher cost, fewer = risk of OOM/throttling.
- **Factor in environment** -- Dev gets minimal defaults, production gets HA suggestions.
- **Reference cluster capabilities** -- Only suggest GPU types that are actually available (from Step 1).

## Deploy Flow

### Step 1: Generate YAML Manifest

Based on the gathered information (image source, resources, ports, env vars), generate a YAML manifest file.

Reference `references/manifest-schema.md` for field definitions and `references/manifest-defaults.md` for recommended defaults per service type.

**Deployment options** (full YAML examples in `references/deploy-api-examples.md`):

| Option | When to Use |
|--------|-------------|
| **A: Pre-built Image** | User has a Docker image ready to deploy |
| **B: Git + Dockerfile** | Code is in Git with a Dockerfile -- TrueFoundry builds remotely |
| **C: Git + PythonBuild** | Python code in Git, no Dockerfile -- TrueFoundry auto-builds |
| **D: Local Docker Build** | Code not in Git -- build locally, push, then use Option A |

Example YAML manifest (pre-built image):

```yaml
name: my-service
type: service
image:
  type: image
  image_uri: docker.io/myorg/my-api:v1.0
ports:
  - port: 8000
    protocol: TCP
    expose: true
    host: my-service-ws.ml.your-org.truefoundry.cloud
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
env:
  LOG_LEVEL: info
replicas: 1
workspace_fqn: cluster-id:workspace-name
```

### Step 2: Write Manifest

Write the manifest to `tfy-manifest.yaml` in the project directory.

### Step 3: Preview

```bash
tfy apply -f tfy-manifest.yaml --dry-run --show-diff
```

Show the preview output to the user. If this is an update to an existing service, the diff shows what will change.

### Step 4: Apply

After user confirms:

```bash
tfy apply -f tfy-manifest.yaml
```

### Fallback: REST API

If `tfy` CLI is not available, convert the YAML manifest to JSON and deploy via REST API. See `references/cli-fallback.md` for the conversion process and `references/rest-api-manifest.md` for the full API reference.

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh

# Get workspace ID from FQN
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"

# Deploy via REST API (JSON body)
$TFY_API_SH PUT /api/svc/v1/apps '{ "manifest": { ... }, "workspaceId": "WORKSPACE_ID" }'
```

## User Confirmation Checklist

**Before deploying, confirm these with the user:**

- [ ] **Service name** -- what to call this deployment
- [ ] **Image source** -- pre-built image, Git repo + Dockerfile, Git repo + PythonBuild, or local Docker build?
- [ ] **Port** -- what port the application listens on
- [ ] **Expected load** -- TPS, concurrent users, environment (dev/staging/prod) -> use Step 2 analysis
- [ ] **CPU/Memory** -- show resource suggestion table from Step 2 (defaults vs suggested values)
- [ ] **GPU** -- whether GPU is needed (only offer available types from Step 1)
- [ ] **Replicas** -- min/max for autoscaling (suggest based on load analysis)
- [ ] **Environment variables** -- check `.env`, `config.py`, or ask directly
- [ ] **Health probes** -- configure startup/readiness/liveness probes (recommended for production)
- [ ] **Public URL** -- internal-only or public? If public, look up cluster base domains and confirm the host
- [ ] **Secrets** -- whether to mount TrueFoundry secret groups
- [ ] **Auto-shutdown** -- does the user want the service to auto-stop after inactivity? Useful for dev/staging to save costs. Not recommended for production services that need to be always-on.

**Do NOT deploy with hardcoded defaults without asking.** Analyze the app (Step 2), suggest appropriate values, and let the user confirm or adjust.

## Health Probes

**Always configure health probes for production services.** Without them, Kubernetes may route traffic to unready pods or fail to restart crashed ones.

| Probe | Purpose | When to Use |
|-------|---------|-------------|
| **Startup** | Wait for app to initialize | Apps with slow startup (model loading, DB migrations, cache warming) |
| **Readiness** | Can this pod receive traffic? | Always -- prevents routing to unready pods |
| **Liveness** | Is this pod alive? | Always -- restarts hung processes |

For YAML probe examples (startup, readiness, liveness), REST API format, and tuning guidelines by app type, see [references/health-probes.md](references/health-probes.md).

### Tuning Guidelines

- **Startup probe**: Set `failure_threshold x period_seconds` >= max app startup time
- **Fast APIs** (< 5s startup): `initial_delay_seconds: 3`, `failure_threshold: 5`
- **Slow apps** (DB migrations, cache warming): `initial_delay_seconds: 15`, `failure_threshold: 30`
- **ML model loading**: `initial_delay_seconds: 10`, `failure_threshold: 60` (see `llm-deploy` skill)

See: [Liveness & Readiness Probes](https://truefoundry.com/docs/liveness-readiness-probe)

## Autoscaling & Rollout Strategy

YAML format for replicas and autoscaling:

```yaml
replicas:
  min: 2
  max: 10
```

YAML format for rollout strategy:

```yaml
rollout_strategy:
  type: rolling_update
  max_surge_percentage: 25
  max_unavailable_percentage: 0
```

For scaling guidelines by environment, rollout strategy options, and zero-downtime deploy settings, see `references/deploy-scaling.md`.

Key points:
- Production: min 2 replicas for high availability
- Default rollout: `max_surge: 25%, max_unavailable: 0%` (zero-downtime)
- Scale-to-zero is available for async services (see `async-service` skill)

---

## Public URL (Exposing a Service)

When the user wants their service publicly accessible, **do NOT guess the domain -- always look it up.**

1. **Get base domains** -- See `references/cluster-discovery.md` for cluster ID extraction and base domain lookup. Pick the wildcard domain, strip `*.`.
2. **Construct host** -- Convention: `{service-name}-{workspace-name}.{base_domain}` (e.g., `simple-server-my-workspace.ml.your-org.truefoundry.cloud`)
3. **Confirm with user** -- Show the constructed `https://` URL and ask if correct.
4. **Set in manifest**:
   ```yaml
   ports:
     - port: 8000
       expose: true
       host: my-service-ws.ml.your-org.truefoundry.cloud
       app_protocol: http
   ```
5. **Internal-only** -- Set `expose: false` and omit `host`. Service is only reachable within the cluster.

**Common errors:** "Provided host is not configured in cluster" means the domain doesn't match cluster `base_domains` -- re-check via cluster API. See `references/deploy-errors.md`.

See: [Define Ports and Domains](https://truefoundry.com/docs/define-ports-and-domains)

## After Deploy -- Get & Return URL

**CRITICAL: Always fetch and return the deployment URL to the user. A deployment without a URL is incomplete.**

### Step 1: Poll for Deployment Status

After deploying, the deployment is submitted but not yet live. Poll the status:

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh

# Get application details -- replace SERVICE_NAME and WORKSPACE_FQN
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=SERVICE_NAME'
```

Or via tool call:
```
tfy_applications_list(filters={"workspace_fqn": "WORKSPACE_FQN", "application_name": "SERVICE_NAME"})
```

### Step 2: Extract the URL

From the API response, look for the endpoint URL in the application object:
- **Public services**: The URL is in `ports[].host` or constructed from the host you set during deployment
- **Internal services**: The internal DNS is `{service-name}.{namespace}.svc.cluster.local:{port}`

### Step 3: Report to User

**Always present this summary after deployment:**

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

**If the service has a public URL**, include the full `https://` URL.
**If internal-only**, show the Kubernetes DNS address and explain how other services can reach it.
**If status is still BUILDING**, tell the user it will take a few minutes and suggest checking back.

### Step 4: Verify Health (Optional but Recommended)

If the deployment shows RUNNING status, do a quick health check:

```bash
curl -s https://{host}/health
```

Report the result to the user. For comprehensive validation (endpoint smoke tests, load soak), use the `service-test` skill.

</instructions>

<success_criteria>

## Success Criteria

- The user can access their deployed service via the returned URL (public or internal)
- The deployment is healthy with all replicas running and passing health checks
- The agent has confirmed service name, resources, port, and image source with the user before deploying
- The deployment URL and status have been reported back to the user
- Health probes are configured for production deployments
- The user knows how to check logs and redeploy if issues arise

</success_criteria>

<references>

## Composability

- **Find workspace first**: Use `workspaces` skill
- **Save workspace for next time**: Use `preferences` skill to remember default workspace
- **Check what's deployed**: Use `applications` skill
- **View deploy logs**: Use `logs` skill
- **Manage secrets**: Use `secrets` skill before deploy to set up secret groups
- **Test after deployment**: Use `service-test` skill to validate the service is healthy

</references>

<troubleshooting>

## Error Handling

For specific error messages and resolution steps, see `references/deploy-errors.md`. Covers:
- `TFY_WORKSPACE_FQN` not set
- `tfy: command not found` -- install with `pip install truefoundry`
- `tfy apply` validation errors -- check YAML syntax and required fields
- "Host not configured in cluster"
- Git build failures
- No Dockerfile found

</troubleshooting>
</output>
