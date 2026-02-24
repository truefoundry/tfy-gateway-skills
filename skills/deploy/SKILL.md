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

1. **REST API manifest** (recommended) — Works with any Python version. Uses `tfy-api.sh` to deploy pre-built images or trigger remote builds from Git.
2. **Python SDK** (`deploy.py`) — Packages local code and deploys. Requires Python 3.10-3.12.

Use the REST API path by default. Fall back to SDK only if the user already has a `deploy.py` or explicitly requests it.

## When to Use

Deploy code, Docker images, or Git repos to TrueFoundry as HTTP services. Defaults to REST API path; falls back to Python SDK if user has deploy.py or requests it.

## When NOT to Use

- User wants to see what's deployed → use `applications` skill
- User wants to check workspace → use `workspaces` skill

</objective>

<context>

## Prerequisites

**Always verify before deploying:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**

For credential check commands and .env setup, see `references/prerequisites.md`.

## Choose Deployment Path

**Default to REST API.** Only use SDK if the user already has a deploy.py or explicitly requests it.

| User's situation | Path |
|---|---|
| Has a pre-built Docker image | REST API — deploy image directly |
| Code is in a Git repo (GitHub, GitLab, etc.) | REST API — TrueFoundry builds remotely from Git |
| Code is local-only (not in Git), has Python 3.10-3.12 | SDK — packages and uploads code |
| Code is local-only, no compatible Python, has Docker | Docker build locally → REST API with pre-built image |
| Already has deploy.py | SDK — run existing deploy.py |

### Detection Steps

1. Check: Does the project have a `deploy.py`? → If yes, offer SDK path
2. Check: Is the code in a Git repository? (`git remote -v`) → If yes, use REST API with Git build
3. Ask: "Do you have a pre-built Docker image?" → If yes, use REST API with image
4. If local code only: check `python3 --version`
   - Python 3.10-3.12 → SDK path
   - Python 3.13+ → check for `docker` → Docker build + REST API
   - Neither → suggest pushing code to Git first, then REST API

## Step 0: Detect Environment

**Before anything else**, check what tools are available:

```bash
# Check for Git repo
git remote -v 2>/dev/null

# Check Python version (only matters for SDK path)
python3 --version 2>/dev/null

# Check for existing deploy.py
ls deploy.py 2>/dev/null

# Check for Docker (only matters for local build path)
docker --version 2>/dev/null
```

If going the SDK path, detect SDK version:
```bash
$TFY_SKILL_DIR/scripts/tfy-version.sh all
```

### SDK Version Compatibility (SDK path only)

| SDK Version | Action |
|------------|--------|
| >= 0.5.0 | Use deploy patterns as-is. `replicas` accepts `int`. |
| 0.4.x | Apply compat: use `Replicas(min=N, max=N)` object, ensure `TFY_HOST` is set. |
| 0.3.x | Legacy SDK. Consider upgrading or switch to REST API. |
| Not installed | Use REST API path. |

| Python Version | Action |
|---------------|--------|
| 3.10–3.12 | SDK compatible. |
| 3.13+ | **SDK is incompatible** (pydantic v1 build failures). Use REST API path. |

> **Tested 2026-02-14**: Python 3.14 fails with pydantic v1 compilation errors. REST API path works with any Python.

</context>

<instructions>

## Step 1: Discover Cluster Capabilities

**Before asking the user about resources, GPUs, or public URLs**, fetch the cluster's capabilities so you can present only what's actually available.

Fetch the cluster's capabilities before asking about resources or public URLs. See `references/cluster-discovery.md` for how to extract cluster ID from workspace FQN and fetch cluster details (GPUs, base domains, storage classes).

### Extract Available Capabilities

From the cluster response, extract:
1. **Base domains** — pick the wildcard domain, strip `*.` → base domain for constructing hosts.
2. **Available GPUs** — present only GPU types the cluster supports, not a generic list.

### Why This Matters

- Deploying with an unsupported GPU type → API error
- Using wrong base domain → "Provided host is not configured in cluster"
- These are the #1 and #2 most common deployment failures

**Always discover before asking.** This prevents wasted round-trips with the user.

## Step 2: Analyze Application & Suggest Resources

**Before asking about CPU/memory/GPU**, analyze the user's codebase and ask about expected load. This produces informed resource suggestions instead of arbitrary defaults.

For the full codebase analysis flow (framework detection, app categorization, load questions by app type, and resource suggestion table format), see [references/codebase-analysis.md](references/codebase-analysis.md).

For CPU, memory, GPU, and replica estimation rules of thumb, see `references/resource-estimation.md`. Key points:

- Always check available GPU types on the cluster (Step 1)
- Memory limit should be 1.5-2x the request
- Production: min 2 replicas for high availability
- GPU VRAM needed = model parameter count x 2 bytes (FP16)

## Deploy Flow

### Path 1: REST API Manifest (Recommended)

Use this for pre-built images, Git-hosted code, or any environment where SDK isn't available.
No Python SDK required — just `tfy-api.sh` (bash + curl).

For complete manifest templates and field reference, see `references/rest-api-manifest.md`.

**Deployment options** (full JSON examples in `references/deploy-api-examples.md`):

| Option | When to Use |
|--------|-------------|
| **A: Pre-built Image** | User has a Docker image ready to deploy |
| **B: Git + Dockerfile** | Code is in Git with a Dockerfile — TrueFoundry builds remotely |
| **C: Git + PythonBuild** | Python code in Git, no Dockerfile — TrueFoundry auto-builds |
| **D: Local Docker Build** | Code not in Git, no SDK — build locally, push, then use Option A |

For each option: get workspace ID, build the manifest per `references/deploy-api-examples.md`, deploy via `PUT /api/svc/v1/apps`, then poll status (see "After Deploy" section).

### Path 2: Python SDK (deploy.py)

Use this when the user already has a deploy.py or explicitly wants SDK.
**Requires Python 3.10-3.12.** If pip install fails on Python 3.13+, switch to Path 1.

#### Path 2a: Project Has deploy.py

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

#### Path 2b: No deploy.py — Create One

1. **Check for Dockerfile** — Look for a Dockerfile in the project root.
   - **If Dockerfile found**: Show the user the Dockerfile path and a brief summary of what it does (base image, exposed port, CMD). Ask: "I found a Dockerfile at `./Dockerfile`. Do you want to use this for the deployment, or would you prefer TrueFoundry to build your app automatically (no Dockerfile needed)?"
   - **If no Dockerfile found**: Ask the user: "No Dockerfile found. Would you like me to create one for your app, or would you prefer TrueFoundry to handle the build automatically?" TrueFoundry can auto-detect Python/Node.js apps and build them without a Dockerfile using `PythonBuild` or `NodejsBuild` from the SDK.
   - **If user wants no Dockerfile**: Use `PythonBuild(python_version="3.12", command="uvicorn main:app --host 0.0.0.0 --port 8000")` instead of `DockerFileBuild` in deploy.py.

2. **ANALYZE & ASK THE USER** — Before creating deploy.py:

   **First**, run the codebase analysis (Step 2a) to identify framework, app type, and compute indicators.

   **Then**, gather this information from the user:
   - **Service name**: What should this service be called? (suggest project directory name if unclear)
   - **Port**: What port does your app listen on? (detect from code if possible — look for `uvicorn`, `app.listen`, `EXPOSE` in Dockerfile)
   - **Expected load**: Ask targeted load questions based on app type (Step 2b) — TPS, concurrent users, environment
   - **Resources**: Present the resource suggestion table (Step 2c) showing defaults vs suggested values based on load analysis. Let the user confirm or adjust.
   - **GPU**: Does your app require GPU acceleration? If yes, present only available GPU types from Step 1. Suggest GPU size based on model parameters.
   - **Environment variables**:
     - Check if project has `.env` file or `config.py` with env var patterns
     - List any found and ask: "Do you need these as environment variables?"
     - Ask: "Are there any other env vars your app needs?"
   - **Public URL**: Should this service be publicly accessible on the internet, or internal-only?
     - **If public**: Look up the cluster's base domains and suggest a host like `{service-name}-{workspace-name}.{base_domain}`. Show the constructed URL and confirm with the user.
     - **If internal**: Set `expose=False` and no `host` — the service is only reachable inside the cluster.
   - **Secrets**: Does your app need access to secrets from TrueFoundry secret groups? (e.g., API keys, database passwords)

3. Create `deploy.py` from the template using confirmed values. Copy from `references/deploy-template.py` and adapt.

4. Install SDK:
   ```bash
   pip install truefoundry python-dotenv
   ```
   If this fails on Python 3.13+:
   ```bash
   python3.12 -m venv .venv-deploy
   source .venv-deploy/bin/activate
   pip install truefoundry python-dotenv
   ```
   If python3.12 isn't available, switch to Path 1 (REST API).

5. Run:
   ```bash
   python deploy.py
   ```

## User Confirmation Checklist

**Before deploying (either path), confirm these with the user:**

- [ ] **Service name** — what to call this deployment
- [ ] **Image source** — pre-built image, Git repo + Dockerfile, Git repo + PythonBuild, or SDK local build?
- [ ] **Port** — what port the application listens on
- [ ] **Expected load** — TPS, concurrent users, environment (dev/staging/prod) → use Step 2 analysis
- [ ] **CPU/Memory** — show resource suggestion table from Step 2 (defaults vs suggested values)
- [ ] **GPU** — whether GPU is needed (only offer available types from Step 1)
- [ ] **Replicas** — min/max for autoscaling (suggest based on load analysis)
- [ ] **Environment variables** — check `.env`, `config.py`, or ask directly
- [ ] **Health probes** — configure startup/readiness/liveness probes (recommended for production)
- [ ] **Public URL** — internal-only or public? If public, look up cluster base domains and confirm the host
- [ ] **Secrets** — whether to mount TrueFoundry secret groups

**Do NOT deploy with hardcoded defaults without asking.** Analyze the app (Step 2), suggest appropriate values, and let the user confirm or adjust.

## Health Probes

**Always configure health probes for production services.** Without them, Kubernetes may route traffic to unready pods or fail to restart crashed ones.

| Probe | Purpose | When to Use |
|-------|---------|-------------|
| **Startup** | Wait for app to initialize | Apps with slow startup (model loading, DB migrations, cache warming) |
| **Readiness** | Can this pod receive traffic? | Always — prevents routing to unready pods |
| **Liveness** | Is this pod alive? | Always — restarts hung processes |

For SDK format, API manifest format, and detailed probe examples, see `references/health-probes.md`.

### Tuning Guidelines

- **Startup probe**: Set `failure_threshold × period_seconds` ≥ max app startup time
- **Fast APIs** (< 5s startup): `initial_delay_seconds: 3`, `failure_threshold: 5`
- **Slow apps** (DB migrations, cache warming): `initial_delay_seconds: 15`, `failure_threshold: 30`
- **ML model loading**: `initial_delay_seconds: 10`, `failure_threshold: 60` (see `llm-deploy` skill)

See: [Liveness & Readiness Probes](https://truefoundry.com/docs/liveness-readiness-probe)

## Autoscaling & Rollout Strategy

For replica configuration (REST API + SDK), scaling guidelines by environment, rollout strategy options, and zero-downtime deploy settings, see `references/deploy-scaling.md`.

Key points:
- Production: min 2 replicas for high availability
- Default rollout: `max_surge: 25%, max_unavailable: 0%` (zero-downtime)
- Scale-to-zero is available for async services (see `async-service` skill)

---

## Public URL (Exposing a Service)

When the user wants their service publicly accessible, **do NOT guess the domain — always look it up.**

1. **Get base domains** — See `references/cluster-discovery.md` for cluster ID extraction and base domain lookup. Pick the wildcard domain, strip `*.`.
2. **Construct host** — Convention: `{service-name}-{workspace-name}.{base_domain}` (e.g., `simple-server-my-workspace.ml.your-org.truefoundry.cloud`)
3. **Confirm with user** — Show the constructed `https://` URL and ask if correct.
4. **Set in manifest** — Use `"expose": true` and `"host": "..."` in the ports config. Or set `TFY_DEPLOY_HOST` env var (the deploy template reads this automatically).
5. **Internal-only** — Set `"expose": false` and omit `host`. Service is only reachable within the cluster.

**Common errors:** "Provided host is not configured in cluster" means the domain doesn't match cluster `base_domains` — re-check via cluster API. See `references/deploy-errors.md`.

See: [Define Ports and Domains](https://truefoundry.com/docs/define-ports-and-domains)

## After Deploy — Get & Return URL

**CRITICAL: Always fetch and return the deployment URL to the user. A deployment without a URL is incomplete.**

### Step 1: Poll for Deployment Status

After deploying (either path), the deployment is submitted but not yet live. Poll the status:

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
- SDK not installed / Python version incompatible
- "Host not configured in cluster"
- Git build failures
- Build failures (SDK path)
- No Dockerfile found

</troubleshooting>
