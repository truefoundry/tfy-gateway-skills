---
name: deploy
description: Deploys code or images to TrueFoundry as services. Supports REST API manifests, Git-based builds, pre-built images, and Python SDK. NOT for listing apps (use applications) or LLMs (use llm-deploy).
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
disable-model-invocation: true
allowed-tools: Bash(python*) Bash(pip*) Bash(*/tfy-api.sh *) Bash(*/tfy-version.sh *) Bash(docker *)
---

<objective>

# Deploy to TrueFoundry

Deploy code or images to TrueFoundry. Two paths:

1. **CLI** (`tfy apply`) — Write a YAML manifest and apply it. Works everywhere.
2. **REST API** (fallback) — When CLI unavailable, use `tfy-api.sh`.

Use the CLI path by default. Fall back to REST API only if `tfy` CLI is not installed and the user cannot install it.

## When to Use

Deploy code, Docker images, or Git repos to TrueFoundry as HTTP services. Defaults to REST API path; falls back to Python SDK if user has deploy.py or requests it.

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

## Quick Deploy Flow

**For the fastest deployment, present a single plan instead of asking questions one by one.**

### 1. Check Preferences

```bash
PREFS_FILE=~/.config/truefoundry/preferences.yml
if [ -f "$PREFS_FILE" ]; then
  cat "$PREFS_FILE"
fi
```

If preferences exist, pre-fill: workspace, environment, resources, expose, base domain.
If no preferences file, the only mandatory question is **workspace**.

### 2. Auto-Detect + Pre-fill

Combine preferences + project scanning to fill every field:

| Field | Source (priority order) |
|-------|----------------------|
| Workspace | 1. Preferences 2. Ask user |
| Service name | Auto-detect from project/repo name |
| Image source | Auto-detect from project (Git repo, Dockerfile, local code) |
| Port | Auto-detect from code (uvicorn, EXPOSE, app.listen, etc.) |
| Resources | 1. Preferences 2. Codebase analysis defaults |
| Environment | 1. Preferences 2. Default "dev" |
| Public URL | 1. Preferences (`expose_services`) 2. Default false |
| Env vars | Auto-detect from .env/code |

### 3. Present One Plan

Present ALL values in a single summary and ask for confirmation:

```
I'll deploy your service to TrueFoundry:

| Setting        | Value                          | Source      |
|----------------|--------------------------------|-------------|
| Workspace      | my-cluster:dev-ws              | saved pref  |
| Service name   | my-app                         | auto        |
| Image          | Git + Dockerfile               | auto        |
| Port           | 8000                           | auto        |
| CPU            | 0.5 / 1.0                      | dev default |
| Memory         | 512 / 1024 MB                  | dev default |
| Replicas       | 1                              | dev default |
| Public URL     | No                             | saved pref  |
| Env vars       | 3 from .env                    | auto        |

Deploy with these settings? (say "yes" to deploy, or tell me what to change)
```

### 4. Handle Response

- **"yes" / "looks good" / "deploy"** → deploy immediately using the steps below
- **"change X to Y"** → update that one field, re-confirm
- **"I want to customize"** → fall through to the full checklist flow below

### 5. After Deploy — Offer to Save Preferences

If no preferences file exists or new values were used:

```
Deployed successfully! Want me to save these settings as defaults?
- Workspace: my-cluster:dev-ws
- Environment: dev
- Resources: dev profile
- Expose: internal only

This saves to ~/.config/truefoundry/preferences.yml so future deploys are even faster.
```

Use the `preferences` skill to save. If the user wants to edit preferences later, tell them to use the `preferences` skill directly.

---

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

## Step 2: Auto-Detect Before Asking

**Before asking the user anything**, scan the project to auto-detect as much as possible:

1. **Image source** — Auto-detect deployment path (see "Choose Deployment Path" above). Only confirm with user, don't ask from scratch.
2. **Framework & app type** — Detect from dependency files (`requirements.txt`, `package.json`, `go.mod`, `Dockerfile`). Categorize as web API, ML inference, worker, frontend, or data pipeline.
3. **Port** — Detect from code: `uvicorn --port`, `app.listen(`, `EXPOSE` in Dockerfile, `gunicorn -b 0.0.0.0:`, `server.port` in config.
4. **Build details** — Auto-detect Dockerfile path, build context, Git repo URL + branch. Only confirm, don't ask each sub-field.
5. **Environment variables** — Scan `.env`, `config.py`, `docker-compose.yml` for env var patterns.
6. **GPU** — Only suggest if ML/GPU libraries detected (`torch`, `transformers`, `tensorflow`, `opencv-python`).
7. **Health endpoint** — Look for `/health`, `/healthz`, `/ping` routes in the code.

Present auto-detected values as confirmations ("I detected X — correct?") rather than open-ended questions.

## Step 3: Analyze Application & Suggest Resources

**Before asking about CPU/memory/GPU**, analyze the user's codebase. This produces informed resource suggestions instead of arbitrary defaults.

For the full codebase analysis flow (framework detection, app categorization, load questions by app type, and resource suggestion table format), see [references/codebase-analysis.md](references/codebase-analysis.md).

For CPU, memory, GPU, and replica estimation rules of thumb, see `references/resource-estimation.md`. Key points:

- Always check available GPU types on the cluster (Step 1)
- Memory limit should be 1.5-2x the request
- Production: min 2 replicas for high availability
- GPU VRAM needed = model parameter count x 2 bytes (FP16)

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

   **First**, run auto-detection (Step 2) and codebase analysis (Step 3) to identify framework, app type, port, and compute indicators.

   **Then**, confirm with the user per the User Confirmation Checklist below. Most values should already be auto-detected — present them for confirmation rather than asking from scratch.

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

**Confirm these with the user before deploying. Auto-detect where possible, show defaults, let user adjust.**

- [ ] **Workspace** — `TFY_WORKSPACE_FQN`. Never auto-pick. Ask the user if missing.
- [ ] **Service name** — Suggest project directory name or repo name.
- [ ] **Image source** — Auto-detect deployment path (Git repo + Dockerfile, pre-built image, SDK local build, etc.). Confirm with user.
- [ ] **Port** — Auto-detect from code. Confirm: "I detected port {port} — correct?"
- [ ] **Resources + scaling** — Present a suggestion table based on codebase analysis (see below). Include CPU, memory, storage, GPU (if detected), and min/max replicas. Let user adjust.
- [ ] **Public URL** — Internal-only or public? If public, construct URL from cluster base domains and confirm.
- [ ] **Environment variables & secrets** — Auto-detect from `.env`/code. Confirm found vars, ask if any others needed.

### Resource Suggestion Table

Present resources and scaling together based on the app type and environment:

```
Based on your app ({framework}, {app_type}):

| Resource       | Default    | Suggested  | Notes                          |
|----------------|------------|------------|--------------------------------|
| CPU request    | 0.25 cores | {value}    | {reasoning}                    |
| CPU limit      | 0.5 cores  | {value}    | {reasoning}                    |
| Memory request | 256 MB     | {value}    | {reasoning}                    |
| Memory limit   | 512 MB     | {value}    | 1.5-2x request                 |
| GPU            | None       | {value}    | Only if ML libs detected       |
| Replicas (min) | 1          | {value}    | Based on environment           |
| Replicas (max) | 1          | {value}    | Based on expected load         |

Use suggested values, or customize?
```

For detailed estimation rules, see `references/resource-estimation.md` and `references/codebase-analysis.md`.

### Defaults Applied Silently (do not ask unless user raises)

These use sensible defaults. Only surface if the user asks or the situation requires it:

| Field | Default | When to Ask |
|-------|---------|-------------|
| Health probes | Auto-configured based on framework (liveness + readiness) | Only ask if user mentions custom health endpoints or slow startup |
| Protocol | HTTP | Only ask if user mentions TCP/gRPC |
| Expose | false | Already covered by Public URL question |
| Rollout strategy | `max_surge: 25%, max_unavailable: 0%` (zero-downtime) | Only ask if user mentions rolling updates or canary deploys |
| Build details (Dockerfile path, context, args) | Auto-detected from project | Only confirm if auto-detection finds multiple Dockerfiles or non-standard paths |
| Capacity type | any | Only ask if user mentions spot/cost optimization |

## Health Probes

**Auto-configure health probes for all services.** Do not ask the user about probes unless they mention custom health endpoints or slow startup. Without probes, Kubernetes may route traffic to unready pods or fail to restart crashed ones.

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
