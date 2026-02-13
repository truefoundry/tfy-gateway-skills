---
name: deploy
description: This skill should be used when the user says "deploy to truefoundry", "deploy this app", "ship to tfy", "push to truefoundry", or wants to run deploy.py. NOT for creating deployments via API — use applications skill for that. For initial project setup or checking what's deployed, use applications skill.
disable-model-invocation: true
allowed-tools: Bash(python*), Bash(pip*), Bash(*/tfy-api.sh *), Bash(*/tfy-version.sh *)
---

# Deploy to TrueFoundry

Deploy local code to TrueFoundry as a Service using the TrueFoundry Python SDK. This uploads the repo and triggers a remote build + deploy.

## When to Use

- User says "deploy", "deploy to truefoundry", "ship this"
- User says "run deploy.py", "python deploy.py"
- User wants to push local code to TrueFoundry
- User says "deploy and check status"

## When NOT to Use

- User wants to create a deployment via API manifest → use `applications` skill
- User wants to see what's deployed → use `applications` skill
- User wants to check workspace → use `workspaces` skill

## Prerequisites

**Always verify before deploying:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` is **required**. Never auto-pick. Ask the user if missing.
3. **Python** — TrueFoundry SDK requires Python 3.10–3.12
4. **SDK** — `pip install truefoundry` (or `pip install -e ".[deploy]"` if the project has that extra)

```bash
# Check credentials
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
echo "TFY_WORKSPACE_FQN: ${TFY_WORKSPACE_FQN:-(not set)}"
```

**If TFY_WORKSPACE_FQN is not set, STOP. Ask the user.** Suggest they use the `workspaces` skill or check the TrueFoundry dashboard.

## Step -1: Detect SDK & Environment

**Before anything else**, detect the installed SDK version and Python environment. This prevents deployment failures from version mismatches.

```bash
# Run version detection (from this skill's scripts directory)
$TFY_SKILL_DIR/scripts/tfy-version.sh all
```

### Interpret Results

| SDK Version | Action |
|------------|--------|
| >= 0.5.0 | Use deploy patterns as-is. `replicas` accepts `int`. |
| 0.4.x | Apply compat: use `Replicas(min=N, max=N)` object, ensure `TFY_HOST` is set. |
| 0.3.x | Legacy SDK. Consider upgrading (`pip install -U truefoundry`) or fall back to REST API. |
| Not installed | Fall back to REST API deployment via `tfy-api.sh` with JSON manifest. See `tfy-apply` skill. |

| Python Version | Action |
|---------------|--------|
| 3.10–3.12 | Compatible. Proceed normally. |
| 3.13+ | SDK may not support this version. Create a compatible venv: |

```bash
# Python 3.13+ workaround
python3.12 -m venv .venv-deploy
source .venv-deploy/bin/activate
pip install truefoundry python-dotenv
```

| CLI (`tfy`) | Action |
|------------|--------|
| Installed | Can use `tfy apply` for declarative deploys (see `tfy-apply` skill). |
| Not installed | Use Python SDK deploy or REST API. |

**If SDK is not installed and user wants SDK-based deploy**, install it:
```bash
pip install truefoundry python-dotenv
```

Then re-run version detection to confirm.

## Step 0: Discover Cluster Capabilities

**Before asking the user about resources, GPUs, or public URLs**, fetch the cluster's capabilities so you can present only what's actually available.

### Get Cluster ID

Extract from workspace FQN (part before the colon):
- Workspace FQN `tfy-ea-dev-eo-az:sai-ws` → Cluster ID `tfy-ea-dev-eo-az`
- Or use `TFY_CLUSTER_ID` from environment if set.

### Fetch Cluster Details

```bash
# Via MCP
tfy_clusters_list(cluster_id="CLUSTER_ID")

# Via Direct API
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

### Extract Available Capabilities

From the cluster response, extract:

1. **Base domains** (for public URLs):
   ```json
   "base_domains": ["ml.tfy-eo.truefoundry.cloud", "*.ml.tfy-eo.truefoundry.cloud"]
   ```
   Pick the wildcard domain, strip `*.` → base domain for constructing hosts.

2. **Available GPUs** — If the user needs GPU, the cluster may only support certain types. The SDK will report valid devices in the error message if you pick an unsupported one:
   ```
   "Valid devices are [T4, A10_4GB, A10_8GB, A10_12GB, A10_24GB, H100_94GB]"
   ```
   **Present only available GPU types to the user, not a generic list.**

### Why This Matters

- Deploying with an unsupported GPU type → API error
- Using wrong base domain → "Provided host is not configured in cluster"
- These are the #1 and #2 most common deployment failures

**Always discover before asking.** This prevents wasted round-trips with the user.

## Step 1: Analyze Application & Suggest Resources

**Before asking about CPU/memory/GPU**, analyze the user's codebase and ask about expected load. This produces informed resource suggestions instead of arbitrary defaults.

### 1a. Codebase Analysis

Scan the project to determine:

1. **Framework & runtime** — Look at dependency files and entrypoints:
   - `requirements.txt`, `pyproject.toml`, `setup.py` → Python (check for FastAPI, Flask, Django, Celery, etc.)
   - `package.json` → Node.js (check for Express, Next.js, NestJS, etc.)
   - `go.mod` → Go
   - `Dockerfile` → check `FROM` image and `CMD`/`ENTRYPOINT`

2. **Application type** — Categorize what the app does:
   - **Web API / HTTP service** — REST/GraphQL endpoint (FastAPI, Express, Django, etc.)
   - **ML inference** — Model serving (vLLM, TGI, Triton, transformers, torch, etc.)
   - **Worker / queue consumer** — Background processing (Celery, Bull, etc.)
   - **Static site / frontend** — Next.js SSR, React SPA, etc.
   - **Data pipeline** — Batch processing (Spark, pandas, etc.)

3. **Compute indicators** — Check for signals that affect resource needs:
   - ML libraries (`torch`, `transformers`, `vllm`, `tensorflow`) → likely needs GPU + high memory
   - Image/video processing (`Pillow`, `opencv`, `ffmpeg`) → CPU-intensive
   - In-memory caching or large datasets (`redis`, `pandas` with large files) → memory-intensive
   - Async/concurrent patterns (`asyncio`, `uvicorn workers`, `gunicorn`) → can handle more load per CPU
   - Database connections (`sqlalchemy`, `prisma`, `mongoose`) → connection pooling matters

### 1b. Ask About Expected Load

Based on the app type, ask the user targeted questions:

**For Web APIs / HTTP services:**
```
To suggest the right resources, I need to understand your expected load:

1. Expected requests per second (TPS)?
   - Low (< 10 TPS) — internal tool, dev/testing
   - Medium (10–100 TPS) — production API with moderate traffic
   - High (100–1000 TPS) — high-traffic production service
   - Very high (1000+ TPS) — needs autoscaling

2. Expected concurrent users?
   - Few (< 50) — internal team
   - Moderate (50–500) — typical B2B SaaS
   - Many (500+) — consumer-facing

3. Average response time target?
   - < 100ms (real-time APIs)
   - < 500ms (standard web)
   - < 5s (batch/processing endpoints)

4. Is this for dev/staging or production?
```

**For ML inference services:**
```
To suggest the right resources:

1. What model are you serving? (model name + parameter count)
2. Expected inference requests per second?
   - Low (< 1 TPS) — development/testing
   - Medium (1–10 TPS) — production inference
   - High (10+ TPS) — high-throughput serving
3. Max acceptable latency per request?
   - < 1s (real-time)
   - < 10s (near real-time)
   - < 60s (batch-style)
4. Batch size? (1 for online, higher for throughput)
```

**For workers / background processors:**
```
To suggest the right resources:

1. What kind of tasks? (data processing, image generation, email sending, etc.)
2. How many concurrent tasks should it handle?
3. Average task duration?
4. Peak task queue depth?
```

### 1c. Resource Suggestion Table

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

Use these rules of thumb when calculating suggestions:

**CPU estimation:**
- Python async (FastAPI/uvicorn): ~0.5 cores per 50 TPS for simple CRUD
- Python sync (Flask/Django): ~1 core per 20 TPS
- Node.js (Express): ~0.5 cores per 100 TPS for simple routes
- Go: ~0.25 cores per 200 TPS
- ML inference (CPU-only): 2–4 cores per model instance
- Add 50% buffer for CPU limit vs request

**Memory estimation:**
- Base Python app: 128–256 MB
- Python + ML libraries (torch, etc.): 2–8 GB (depends on model size)
- Node.js app: 128–512 MB
- Go app: 64–128 MB
- Add memory for: loaded models, connection pools, caches, request payloads
- Memory limit should be 1.5–2x the request

**GPU estimation:**
- Model parameter count × 2 bytes (FP16) = minimum VRAM needed
- 2B params → ~4 GB VRAM → T4 (16 GB) works fine
- 7B params → ~14 GB VRAM → A10_24GB or T4 (tight)
- 13B params → ~26 GB VRAM → A10_24GB (quantized) or A100_40GB
- 70B params → ~140 GB VRAM → multiple GPUs or H100/H200
- Always check available GPU types on the cluster (Step 0)

**Replica estimation:**
- Dev/testing: 1 replica (no HA needed)
- Production: min 2 replicas for high availability
- Autoscaling: set max replicas = 2–4x min for traffic spikes
- Rule of thumb: each replica handles ~50–200 TPS for async Python APIs

### Important Notes

- **Always show the suggestion table** — Don't just pick values silently. Users should see the reasoning.
- **Let users override** — Suggestions are starting points, not mandates.
- **Mention trade-offs** — More resources = higher cost, fewer = risk of OOM/throttling.
- **Factor in environment** — Dev gets minimal defaults, production gets HA suggestions.
- **Reference cluster capabilities** — Only suggest GPU types that are actually available (from Step 0).

## Deploy Flow

### Path A: Project Has deploy.py

1. Verify all env vars are set
2. Install SDK if needed:
   ```bash
   pip install truefoundry python-dotenv
   ```
3. Run deploy:
   ```bash
   python deploy.py
   ```
4. Report result to user

### Path B: No deploy.py Exists

1. **Check for Dockerfile** — Look for a Dockerfile in the project root.
   - **If Dockerfile found**: Show the user the Dockerfile path and a brief summary of what it does (base image, exposed port, CMD). Ask: "I found a Dockerfile at `./Dockerfile`. Do you want to use this for the deployment, or would you prefer TrueFoundry to build your app automatically (no Dockerfile needed)?"
   - **If no Dockerfile found**: Ask the user: "No Dockerfile found. Would you like me to create one for your app, or would you prefer TrueFoundry to handle the build automatically?" TrueFoundry can auto-detect Python/Node.js apps and build them without a Dockerfile using `PythonBuild` or `NodejsBuild` from the SDK.
   - **If user wants no Dockerfile**: Use `PythonBuild(python_version="3.12", command="uvicorn main:app --host 0.0.0.0 --port 8000")` instead of `DockerFileBuild` in deploy.py.

2. **ANALYZE & ASK THE USER** — Before creating deploy.py:

   **First**, run the codebase analysis (Step 1a) to identify framework, app type, and compute indicators.

   **Then**, gather this information from the user:
   - **Service name**: What should this service be called? (suggest project directory name if unclear)
   - **Port**: What port does your app listen on? (detect from code if possible — look for `uvicorn`, `app.listen`, `EXPOSE` in Dockerfile)
   - **Expected load**: Ask targeted load questions based on app type (Step 1b) — TPS, concurrent users, environment
   - **Resources**: Present the resource suggestion table (Step 1c) showing defaults vs suggested values based on load analysis. Let the user confirm or adjust.
   - **GPU**: Does your app require GPU acceleration? If yes, present only available GPU types from Step 0. Suggest GPU size based on model parameters (Step 1c guidelines).
   - **Environment variables**:
     - Check if project has `.env` file or `config.py` with env var patterns
     - List any found and ask: "Do you need these as environment variables?"
     - Ask: "Are there any other env vars your app needs?"
   - **Public URL**: Should this service be publicly accessible on the internet, or internal-only?
     - **If public**: Look up the cluster's base domains (see "Public URL" section below) and suggest a host like `{service-name}-{workspace-name}.{base_domain}`. Show the constructed URL and confirm with the user.
     - **If internal**: Set `expose=False` and no `host` — the service is only reachable inside the cluster.
   - **Secrets**: Does your app need access to secrets from TrueFoundry secret groups? (e.g., API keys, database passwords)

3. Create `deploy.py` from the template using confirmed values:
   - `name` — service name from step 2
   - `port` — port from step 2
   - `dockerfile_path` — path to Dockerfile
   - Resources — CPU, memory from step 2
   - Environment variables and secrets from step 2

4. Install SDK:
   ```bash
   pip install truefoundry python-dotenv
   ```
5. Run:
   ```bash
   python deploy.py
   ```

## User Confirmation Checklist

**Before creating or running deploy.py, confirm these with the user:**

- [ ] **Dockerfile** — use existing Dockerfile, create one, or let TrueFoundry auto-build?
- [ ] **Service name** — what to call this deployment
- [ ] **Port** — what port the application listens on
- [ ] **Expected load** — TPS, concurrent users, environment (dev/staging/prod) → use Step 1 analysis
- [ ] **CPU/Memory** — show resource suggestion table from Step 1 (defaults vs suggested values)
- [ ] **GPU** — whether GPU is needed (only offer available types from Step 0)
- [ ] **Replicas** — min/max for autoscaling (suggest based on load analysis)
- [ ] **Environment variables** — check `.env`, `config.py`, or ask directly
- [ ] **Health probes** — configure startup/readiness/liveness probes (recommended for production)
- [ ] **Autoscaling** — min/max replicas based on environment and expected load
- [ ] **Rollout strategy** — rolling update settings for zero-downtime deployments
- [ ] **Public URL** — internal-only or public? If public, look up cluster base domains and confirm the host
- [ ] **Secrets** — whether to mount TrueFoundry secret groups

**Do NOT deploy with hardcoded defaults without asking.** Analyze the app (Step 1), suggest appropriate values, and let the user confirm or adjust.

### Deploy Template

Copy from this skill's `references/deploy-template.py` (located alongside this SKILL.md) and adapt. Key fields to change:

```python
service = Service(
    name="my-app",                    # ← project name
    # ...
    ports=[Port(port=8000, ...)],     # ← app port
)
```

## Health Probes

**Always configure health probes for production services.** Without them, Kubernetes may route traffic to unready pods or fail to restart crashed ones.

### Probe Types

| Probe | Purpose | When to Use |
|-------|---------|-------------|
| **Startup** | Wait for app to initialize | Apps with slow startup (model loading, DB migrations, cache warming) |
| **Readiness** | Can this pod receive traffic? | Always — prevents routing to unready pods |
| **Liveness** | Is this pod alive? | Always — restarts hung processes |

### Default Probe Config (HTTP)

Most web apps expose a `/health` or `/healthz` endpoint:

```python
# In deploy.py (SDK)
from truefoundry.deploy import HttpProbe, HealthProbe

service = Service(
    # ...
    liveness_probe=HealthProbe(
        config=HttpProbe(path="/health", port=8000),
        initial_delay_seconds=5,
        period_seconds=10,
        timeout_seconds=2,
        failure_threshold=3,
    ),
    readiness_probe=HealthProbe(
        config=HttpProbe(path="/health", port=8000),
        initial_delay_seconds=5,
        period_seconds=10,
        timeout_seconds=2,
        failure_threshold=3,
    ),
)
```

### API Manifest Format

```json
{
  "startup_probe": {
    "config": {"type": "http", "path": "/health", "port": 8000},
    "initial_delay_seconds": 10,
    "period_seconds": 10,
    "failure_threshold": 30,
    "timeout_seconds": 2,
    "success_threshold": 1
  },
  "readiness_probe": {
    "config": {"type": "http", "path": "/health", "port": 8000},
    "initial_delay_seconds": 5,
    "period_seconds": 10,
    "failure_threshold": 3,
    "timeout_seconds": 2,
    "success_threshold": 1
  },
  "liveness_probe": {
    "config": {"type": "http", "path": "/health", "port": 8000},
    "initial_delay_seconds": 5,
    "period_seconds": 10,
    "failure_threshold": 5,
    "timeout_seconds": 2,
    "success_threshold": 1
  }
}
```

### Tuning Guidelines

- **Startup probe**: Set `failure_threshold × period_seconds` ≥ max app startup time
- **Fast APIs** (< 5s startup): `initial_delay_seconds: 3`, `failure_threshold: 5`
- **Slow apps** (DB migrations, cache warming): `initial_delay_seconds: 15`, `failure_threshold: 30`
- **ML model loading**: `initial_delay_seconds: 10`, `failure_threshold: 60` (see `llm-deploy` skill)

See: [Liveness & Readiness Probes](https://truefoundry.com/docs/liveness-readiness-probe)

## Autoscaling

TrueFoundry supports horizontal pod autoscaling (HPA) based on CPU, memory, or custom metrics.

### Replica Configuration

```python
# SDK
from truefoundry.deploy import Replicas

service = Service(
    # ...
    replicas=Replicas(min=2, max=10),
)
```

### API Manifest Format

```json
{
  "replicas": {
    "min": 2,
    "max": 10
  }
}
```

### Scaling Guidelines

| Environment | Min | Max | Notes |
|-------------|-----|-----|-------|
| Dev/testing | 1 | 1 | No autoscaling needed |
| Staging | 1 | 3 | Test scaling behavior |
| Production | 2 | 10 | Min 2 for high availability |
| High-traffic | 3 | 20+ | Based on load testing |

**Key considerations:**
- `min: 1` means no high availability — if the pod dies, there's downtime
- `min: 2` ensures at least one pod is always available during rolling updates
- `max` should be set based on cluster capacity and expected peak traffic
- TrueFoundry auto-scales based on CPU utilization by default
- Scale-to-zero is available for async services (see `async-service` skill)

See: [Autoscaling](https://truefoundry.com/docs/autoscaling-overview)

## Rollout Strategy

Control how new versions are deployed to minimize downtime and risk.

### Rolling Update (Default, Recommended)

```python
# SDK
from truefoundry.deploy import RolloutStrategy, RollingUpdate

service = Service(
    # ...
    rollout_strategy=RolloutStrategy(
        type=RollingUpdate(
            max_surge_percentage=25,
            max_unavailable_percentage=0,
        )
    ),
)
```

### API Manifest Format

```json
{
  "rollout_strategy": {
    "type": "rolling_update",
    "max_surge_percentage": 25,
    "max_unavailable_percentage": 0
  }
}
```

### Strategy Options

| Setting | Value | Effect |
|---------|-------|--------|
| `max_surge: 25%, max_unavailable: 0%` | Zero-downtime | New pods start before old ones stop. Uses more resources temporarily. |
| `max_surge: 0%, max_unavailable: 25%` | Resource-efficient | Some pods go down before new ones start. Brief capacity reduction. |
| `max_surge: 50%, max_unavailable: 50%` | Fast rollout | Aggressive replacement. Brief instability possible. |

**Recommendation:** Use `max_surge: 25%, max_unavailable: 0%` for production (zero-downtime deploys).

See: [Rollout Strategy](https://truefoundry.com/docs/rollout-strategy)

---

## Public URL (Exposing a Service)

When the user wants their service publicly accessible, you need a valid hostname from the cluster's configured base domains. **Do NOT guess the domain — always look it up.**

### Step 1: Get the cluster's base domains

Use `TFY_CLUSTER_ID` (from env or ask the user). The cluster ID is the part before the colon in the workspace FQN (e.g., workspace `tfy-ea-dev-eo-az:sai-ws` → cluster `tfy-ea-dev-eo-az`).

```bash
# Via MCP
tfy_clusters_list(cluster_id="CLUSTER_ID")

# Via Direct API
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

Look for `base_domains` in the response. Example:
```json
"base_domains": [
  "ml.tfy-eo.truefoundry.cloud",
  "*.ml.tfy-eo.truefoundry.cloud"
]
```

Pick the **wildcard domain** (the one starting with `*.`), and strip the `*.` prefix to get the base domain. For example: `*.ml.tfy-eo.truefoundry.cloud` → base domain is `ml.tfy-eo.truefoundry.cloud`.

### Step 2: Construct the host

Convention: `{service-name}-{workspace-name}.{base_domain}`

Example:
- Service name: `simple-server`
- Workspace: `sai-ws` (from workspace FQN `tfy-ea-dev-eo-az:sai-ws`)
- Base domain: `ml.tfy-eo.truefoundry.cloud`
- **Result**: `simple-server-sai-ws.ml.tfy-eo.truefoundry.cloud`

### Step 3: Confirm with the user

Show the constructed URL and ask:
```
Your service will be available at:
  https://simple-server-sai-ws.ml.tfy-eo.truefoundry.cloud

Is this host correct, or do you want to use a different one?
```

### Step 4: Set in deploy.py

```python
ports=[
    Port(port=8000, protocol="TCP",
         expose=True,
         host="simple-server-sai-ws.ml.tfy-eo.truefoundry.cloud",
         app_protocol="http"),
]
```

Or use `TFY_DEPLOY_HOST` env var — the deploy template reads this automatically:
```bash
export TFY_DEPLOY_HOST="simple-server-sai-ws.ml.tfy-eo.truefoundry.cloud"
```

### Common Errors

- **"Provided host is not configured in cluster"** — The host domain doesn't match any `base_domains` on the cluster. Re-check with the cluster API.
- **No wildcard domain found** — The cluster may not have public ingress configured. Ask the user to check with their platform admin or use internal-only mode.

### Internal-only (no public URL)

If the user doesn't need a public URL:
```python
ports=[
    Port(port=8000, protocol="TCP", expose=False, app_protocol="http"),
]
```
The service will only be reachable within the cluster (e.g., by other services in the same namespace).

See: [Define Ports and Domains](https://truefoundry.com/docs/define-ports-and-domains)

## Python Version Issues

TrueFoundry SDK requires Python 3.10–3.12. If the system default is 3.13+:

```bash
python3.12 -m venv .venv-deploy
source .venv-deploy/bin/activate
pip install truefoundry python-dotenv
python deploy.py
```

## After Deploy — Get & Return URL

**CRITICAL: Always fetch and return the deployment URL to the user. A deployment without a URL is incomplete.**

### Step 1: Poll for Deployment Status

After `python deploy.py` completes, the deployment is submitted but not yet live. Poll the status:

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh

# Get application details — replace SERVICE_NAME and WORKSPACE_FQN
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=SERVICE_NAME'
```

Or via MCP:
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

Report the result to the user.

## Composability

- **Find workspace first**: Use `workspaces` skill
- **Check what's deployed**: Use `applications` skill
- **View deploy logs**: Use `logs` skill
- **Manage secrets**: Use `secrets` skill before deploy to set up secret groups

## Error Handling

### TFY_WORKSPACE_FQN Not Set
```
TFY_WORKSPACE_FQN is required. Get it from:
- TrueFoundry dashboard → Workspaces
- Or run: tfy_workspaces_list (if MCP server is available)
Do not auto-pick a workspace.
```

### SDK Not Installed
```
Install the TrueFoundry SDK:
  pip install truefoundry python-dotenv
```

### Python Version Incompatible
```
TrueFoundry SDK requires Python 3.10–3.12. Current: X.Y
Create a compatible venv:
  python3.12 -m venv .venv-deploy && source .venv-deploy/bin/activate
```

### No Dockerfile
```
No Dockerfile found. Create one for your app first.
For a Python app: FROM python:3.12-slim, COPY, pip install, CMD.
For Node.js: FROM node:20-slim, COPY, npm install, CMD.
```

### Host Not Configured in Cluster
```
"Provided host is not configured in cluster"
The host you specified doesn't match any base_domains on the cluster.
Fix: Look up cluster base domains:
  GET /api/svc/v1/clusters/CLUSTER_ID → base_domains
Use the wildcard domain (e.g., *.ml.tfy-eo.truefoundry.cloud)
and construct: {service}-{workspace}.{base_domain}
```

### Build Failed
```
Build failed on TrueFoundry. Check the dashboard for build logs.
Common issues:
- Missing dependencies in Dockerfile
- Wrong port configuration
- Dockerfile CMD not matching the app's start command
```
