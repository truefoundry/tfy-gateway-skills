---
name: multi-service
description: Orchestrates multi-service deployments on TrueFoundry. Builds dependency graphs, deploys in order, and wires services together (docker-compose translation, DNS, secrets). NOT for single services (use deploy skill).
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
disable-model-invocation: true
allowed-tools: Bash(*/tfy-api.sh *) Bash(python*) Bash(pip*)
---

<objective>

# Multi-Service Application Deployment

Orchestrate the deployment of complex applications with multiple interconnected services on TrueFoundry. This skill builds a dependency graph, deploys services in the correct order, and wires them together so the full application works end-to-end.

## Scope

Orchestrate deployment of multi-service applications (frontend + backend + infra). Scans for docker-compose files, builds a dependency DAG, deploys in topological order, and wires services via Kubernetes DNS.

## When NOT to Use

- User wants to deploy a single service -> use `deploy` skill
- User wants to deploy just a database -> use `helm` skill
- User wants to deploy just an LLM -> use `llm-deploy` skill
- User wants to check what's deployed -> use `applications` skill

## CRITICAL: Service Wiring is MANDATORY

**When deploying multiple services, you MUST wire them together.** Deploying services in isolation without connecting them is useless -- a frontend that can't reach its backend, or a backend that can't reach its database, is a broken deployment.

**The agent MUST:**
1. Build a dependency graph of all services
2. Configure environment variables so each service knows how to reach its dependencies
3. Deploy in topologically sorted order
4. Verify connectivity between services after deployment
5. Return ALL deployment URLs and internal DNS addresses in the final summary

**If the user deploys a frontend + backend + database, the frontend MUST work end-to-end.** Not just individually deployed services.

</objective>

<context>

## Prerequisites

Same as other deploy skills:

1. **Credentials** -- `TFY_BASE_URL` and `TFY_API_KEY` must be set
2. **Workspace** -- `TFY_WORKSPACE_FQN` is required. **Never auto-pick -- always ask the user.**
3. **CLI** -- Check if `tfy` CLI is available: `tfy --version`. If not, `pip install truefoundry`.

</context>

<instructions>

## Quick Deploy Flow — Preferences Check

**Before scanning the project, check for saved preferences to pre-fill workspace, environment, and resource defaults.**

### Check Preferences

```bash
PREFS_FILE=~/.config/truefoundry/preferences.yml
if [ -f "$PREFS_FILE" ]; then
  cat "$PREFS_FILE"
fi
```

If preferences exist, pre-fill these fields in the deployment plan (Step 3):
- **Workspace** — from `default_workspace`
- **Environment** — from `environment` (affects resource sizing: dev vs production)
- **Expose** — from `expose_services` (which services get public URLs)
- **Resource profiles** — from `resources` (CPU/memory defaults)

If no preferences file, the only mandatory question is **workspace** — everything else is auto-detected from the project.

After a successful multi-service deployment, offer to save preferences:

```
All services deployed! Want me to save these settings as defaults?
- Workspace: my-cluster:dev-ws
- Environment: dev

This saves to ~/.config/truefoundry/preferences.yml so future deploys are even faster.
```

Use the `preferences` skill to save. If the user wants to edit preferences later, tell them to use the `preferences` skill directly.

---

## Step 0: Auto-Detect Before Asking

**The multi-service skill is heavily auto-detected.** The agent proactively scans the project to discover services, build the dependency graph, classify components, detect ports, env vars, and wiring — all before asking the user anything.

The user's role is to **confirm the plan**, not answer individual questions per service.

## User Confirmation Checklist

**Confirm these with the user before deploying. Almost everything is auto-detected from the project.**

- [ ] **Workspace** — `TFY_WORKSPACE_FQN`. Never auto-pick. Ask the user if missing.
- [ ] **Discovered services** — Present auto-detected services with their types (Helm/Service/LLM). Let user confirm or correct.
- [ ] **Dependency graph + deploy order** — Show the DAG and topological deploy order. Let user confirm.
- [ ] **Helm chart sources** — For infrastructure (DB, cache, queue): ask the user which chart registry and version to use. Cannot auto-detect — always ask.
- [ ] **Public URLs** — Which services need public access? (typically frontend only). Construct URLs from cluster base domains and confirm.
- [ ] **Credentials** — Generate strong passwords for infra (DB, Redis, etc.) and confirm. Store in TrueFoundry secrets.

### Per-Service Details (auto-detected, confirm in plan)

These are auto-detected from docker-compose or project structure and included in the plan. Do not ask each one individually — show them in the plan table and let the user adjust:

| Field | Auto-Detected From |
|-------|-------------------|
| Service names | Compose service names or directory names |
| Ports | Compose `ports:`, Dockerfile `EXPOSE`, code detection |
| Environment variables | Compose `environment:`, `.env` files, code patterns |
| Build context / Dockerfile | Compose `build:`, project Dockerfiles |
| Resources (CPU/memory) | Sensible defaults per service type (see below) |
| Replicas | 1 per service (dev default) |
| Health probes | Auto-configured per framework |

### Default Resources by Service Type

Apply these defaults silently. Show in the plan table, let user adjust:

| Service Type | CPU req/lim | Memory req/lim | Storage |
|---|---|---|---|
| Database (Helm) | Chart defaults | Chart defaults | 10Gi (dev), 50Gi (prod) |
| Cache (Helm) | Chart defaults | Chart defaults | 1Gi |
| Queue (Helm) | Chart defaults | Chart defaults | 5Gi |
| Backend API | 0.5 / 1.0 | 512 / 1024 MB | 1 GB |
| Frontend | 0.25 / 0.5 | 256 / 512 MB | 1 GB |
| Worker | 0.5 / 1.0 | 512 / 1024 MB | 2 GB |
| LLM | Per `llm-deploy` skill | Per `llm-deploy` skill | 50 GB |

### Defaults Applied Silently (do not ask unless user raises)

| Field | Default | When to Ask |
|-------|---------|-------------|
| Per-service resources | Defaults from table above | Only if user mentions sizing or production |
| Replicas | 1 per service | Only if user mentions HA or production |
| Health probes | Auto-configured per framework | Only if user mentions custom probes |
| Rollout strategy | Zero-downtime (`max_surge: 25%, max_unavailable: 0%`) | Never for multi-service |
| Capacity type | any | Only if user mentions spot/cost |
| Network protocol | HTTP | Only if user mentions TCP/gRPC |

## Step 1: Discover Services

**Proactively scan the project** to find all deployable components. Do NOT wait for the user to list them.

### Scan Order (check all of these)

1. **`docker-compose.yml` / `docker-compose.yaml` / `compose.yml` / `compose.yaml`**
   If any of these exist, this is the primary source of truth. Parse it to extract:
   - All services (names, images, build contexts)
   - Port mappings
   - Environment variables (including cross-service references like `db:5432`)
   - `depends_on` relationships
   - Volume mounts
   - Health checks

2. **Multiple Dockerfiles** -- Look for `Dockerfile`, `Dockerfile.*`, `*/Dockerfile` across the project

3. **Service directories** -- Directories with their own `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`

4. **Kubernetes manifests** -- Check `k8s/`, `manifests/`, `deploy/` directories

5. **Monorepo patterns** -- `services/`, `apps/`, `packages/` with subdirectories

### Classify Each Service

For each discovered service, determine its **type**:

| Type | How to Detect | Deploy Method |
|------|--------------|---------------|
| **Database** | Image is `postgres`, `mysql`, `mariadb`, `mongo` | Helm chart (ask user for chart source) |
| **Cache** | Image is `redis`, `memcached`, `valkey` | Helm chart (ask user for chart source) |
| **Queue** | Image is `rabbitmq`, `nats`, `kafka` | Helm chart (ask user for chart source) |
| **Search/Vector DB** | Image is `elasticsearch`, `qdrant`, `weaviate`, `milvus` | Helm chart or Service |
| **LLM** | Image contains `vllm`, `tgi`, `triton`, `ollama` | `llm-deploy` skill |
| **Application** | Has `build:` context or custom image with code | Service deployment via `tfy apply` |

## Step 2: Build Dependency Graph

Construct a directed acyclic graph (DAG) of service dependencies. For dependency detection sources (compose, env vars, code analysis), dependency rules, circular dependency handling, infrastructure readiness polling, and topological sort examples, see [references/dependency-graph.md](references/dependency-graph.md).

## Step 3: Present Plan and Ask User

**ALWAYS present the discovered architecture and ask the user to confirm before deploying.**

Present a single comprehensive plan that covers the User Confirmation Checklist. The plan should include:

```
## Deployment Plan for {project-name}

### Discovered Services
| Service    | Type       | Deploy As    | Port | Image/Build          |
|------------|------------|--------------|------|----------------------|
| db         | Database   | Helm chart   | 5432 | PostgreSQL           |
| redis      | Cache      | Helm chart   | 6379 | Redis                |
| backend    | App        | Service      | 8000 | Git + Dockerfile     |
| frontend   | App        | Service      | 3000 | Git + Dockerfile     |

### Dependency Graph
  frontend → backend → db, redis

### Deploy Order
  Level 0: db, redis (parallel)
  Level 1: backend (after infra healthy)
  Level 2: frontend (after backend healthy)

### Environment Wiring
  backend.DATABASE_URL → db (PostgreSQL DNS)
  backend.REDIS_URL → redis (Redis DNS)
  frontend.API_URL → backend (public URL or internal DNS)

### Resources (defaults — adjust as needed)
| Service  | CPU req/lim | Memory req/lim | GPU  | Replicas |
|----------|-------------|----------------|------|----------|
| db       | chart       | chart          | —    | 1        |
| redis    | chart       | chart          | —    | 1        |
| backend  | 0.5/1.0     | 512/1024 MB    | —    | 1        |
| frontend | 0.25/0.5    | 256/512 MB     | —    | 1        |

### Questions
1. **Helm chart sources** — Which registry/version for PostgreSQL and Redis?
2. **Public URLs** — Frontend public? Backend internal or public?
3. **Credentials** — I'll generate strong passwords for DB and Redis. OK?

Shall I proceed with this plan?
```

**Do NOT deploy until the user confirms.** The plan is the user's single point of review — all auto-detected values, resources, wiring, and questions are presented together.

## Step 4: Resolve Namespace and DNS

Before deploying, resolve the Kubernetes namespace for the target workspace. This is needed for internal service DNS.

### Get Workspace Details

```bash
TFY_API_SH=~/.claude/skills/truefoundry-multi-service/scripts/tfy-api.sh

# Get workspace details to find the namespace
$TFY_API_SH GET '/api/svc/v1/workspace?workspaceFqn=WORKSPACE_FQN'
```

From the response, extract:
- `id` -> workspace ID (needed for deployment API calls)
- `clusterId` -> cluster ID (needed for base domain lookup)
- The namespace is typically the workspace name portion of the FQN

### Get Base Domain (for public URLs)

```bash
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

From the response, extract `base_domains`. Pick the wildcard domain (e.g., `*.ml.your-org.truefoundry.cloud`) and strip `*.` to get the base domain.

Public URL pattern: `{service-name}-{workspace-name}.{base_domain}`

### Internal DNS Pattern

All services in the same workspace share a namespace:
```
{service-name}.{namespace}.svc.cluster.local:{port}
```

For Helm-deployed infrastructure, the DNS includes the chart name:
```
{release-name}-postgresql.{namespace}.svc.cluster.local:5432
{release-name}-redis-master.{namespace}.svc.cluster.local:6379
{release-name}-rabbitmq.{namespace}.svc.cluster.local:5672
```

## Step 5: Deploy in Graph Order

Walk the dependency graph level by level. **Wait for each level to be healthy before proceeding to the next.**

Each service gets its own YAML manifest file (e.g., `tfy-manifest-db.yaml`, `tfy-manifest-backend.yaml`, `tfy-manifest-frontend.yaml`). Reference `references/manifest-schema.md` for field definitions and `references/manifest-defaults.md` for recommended defaults per service type. If `tfy` CLI is unavailable, see `references/cli-fallback.md` for REST API fallback.

### For Infrastructure (Helm Charts)

Use the `helm` skill approach. All charts use `PUT /api/svc/v1/apps` with `type: "helm"`. **Ask the user for the chart source URL, chart name, and version.** Do not assume a specific chart registry.

Name each chart `APP_NAME-{service}` (e.g., `myapp-db`, `myapp-redis`). See the `helm` skill for full manifest examples and source type formats (`oci-repo`, `helm-repo`, `git-helm-repo`).

### Verify Infrastructure is Running

Before deploying dependent services, poll until infrastructure is healthy:

```bash
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=APP_NAME-db'
# Check status == "RUNNING"
```

### For Application Services

Deploy each service using its own YAML manifest with wired env vars:

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "kind": "Service",
    "name": "<APP_NAME>-<SERVICE_NAME>",
    "image": {
      "type": "image",
      "image_uri": "<IMAGE_URI>",
      "command": "<COMMAND>"
    },
    "ports": [
      {
        "port": <PORT>,
        "protocol": "<PROTOCOL>",
        "expose": <EXPOSE>,
        "host": "<APP_NAME>-<SERVICE_NAME>-<WORKSPACE>.<BASE_DOMAIN>",
        "app_protocol": "http"
      }
    ],
    "resources": {
      "cpu_request": <CPU_REQUEST>,
      "cpu_limit": <CPU_LIMIT>,
      "memory_request": <MEMORY_REQUEST>,
      "memory_limit": <MEMORY_LIMIT>
    },
    "env": {
      "DATABASE_URL": "postgresql://postgres:PASSWORD@APP_NAME-db-postgresql.NAMESPACE.svc.cluster.local:5432/DB_NAME",
      "REDIS_URL": "redis://:PASSWORD@APP_NAME-redis-redis-master.NAMESPACE.svc.cluster.local:6379/0"
    },
    "replicas": { "min": <MIN_REPLICAS>, "max": <MAX_REPLICAS> }
  },
  "workspaceId": "WORKSPACE_ID"
}'
```

```bash
tfy apply -f tfy-manifest-backend.yaml
```

**If the service has a `build:` context (docker-compose) or a Dockerfile**, use Git build source in the YAML manifest:

```yaml
image:
  type: build
  build_source:
    type: git
    repo_url: https://github.com/user/repo
    branch_name: main
  build_spec:
    type: dockerfile
    dockerfile_path: backend/Dockerfile
    build_context_path: backend/
```

### For LLM Services

If the dependency graph includes an LLM, use the `llm-deploy` skill's approach with GPU allocation.

## Step 6: Wire Environment Variables

**This is the most critical step.** Every cross-service reference must be translated from compose service names to Kubernetes DNS. For the translation rule, common wiring patterns (DB, Redis, RabbitMQ, etc.), DNS patterns, and secrets management, see [references/service-wiring.md](references/service-wiring.md).

## Step 7: Verify Connectivity

After all services are deployed and running, verify they can reach each other:

1. **Check deployment status** -- Poll each service via `$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=APP_NAME'` and confirm status is RUNNING
2. **Check logs for connection errors** -- Use the `logs` skill to search for `Connection refused`, `Authentication failed`, `Name resolution failed`, or `Timeout`
3. **Hit service endpoints** -- `curl` public URLs to verify HTTP 200 responses
4. Use the `service-test` skill for deeper validation.

## Step 8: Report Deployment Summary

**CRITICAL: Always provide a comprehensive summary with ALL URLs and wiring.**

The summary must include:
1. **Component table** -- each service with its type (Helm/Service), status, and URL or internal DNS
2. **Wiring map** -- which env vars connect which services (mask passwords with `***`)
3. **Access URLs** -- public URLs for frontend and API docs
4. **Next steps** -- open frontend, use `logs` skill if broken, use `service-test` skill to validate

**The user should be able to open the frontend URL and see a working app.** If they can't, the deployment is not done.

## docker-compose.yml Translation

See `references/compose-translation.md` for the full translation reference. Key points:

- **Always scan for compose files first** before asking the user about architecture
- `build:` services -> TrueFoundry Service with `DockerFileBuild`
- `image:` services (custom) -> TrueFoundry Service with pre-built image
- `image:` services (postgres, redis, etc.) -> Helm charts (ask user for chart source)
- `depends_on` -> deploy order in the dependency graph
- `healthcheck` -> TrueFoundry liveness/readiness probes in YAML
- `volumes` -> Helm persistence or TrueFoundry Volumes
- `networks` -> ignored (all services share a K8s namespace)
- `env_file` / `secrets` -> read values, create TrueFoundry secrets as needed

## Compound AI & Monorepo Patterns

See `references/multi-service-patterns.md` for ready-made dependency graphs and deploy orders for:
- **RAG applications** (LLM + vector DB + API + frontend)
- **AI Agent with tools** (LLM + tool server + DB)
- **Full-Stack SaaS with AI** (frontend + backend + workers + infra + LLM)
- **Monorepo support** (detecting structure, shared code, build contexts)

</instructions>

<success_criteria>

## Success Criteria

- The agent has discovered all services in the project and built an accurate dependency graph
- All infrastructure (databases, caches, queues) is deployed and healthy before dependent services
- Environment variables are correctly wired so every service can reach its dependencies via Kubernetes DNS
- All services are running and the user has a comprehensive summary with public URLs and internal DNS addresses
- The user can open the frontend URL and interact with a fully working end-to-end application
- Credentials are stored securely in TrueFoundry secrets, not hardcoded in manifests

</success_criteria>

<references>

## Composability

This skill orchestrates other skills:

- **Infrastructure**: Uses `helm` skill patterns for databases, caches, queues
- **Services**: Uses `deploy` skill patterns for application services
- **LLMs**: Uses `llm-deploy` skill patterns if the app includes model serving
- **Secrets**: Uses `secrets` skill to create shared credential groups
- **Workspaces**: Uses `workspaces` skill to get workspace FQN and namespace
- **Verification**: Uses `applications` skill to check status, `logs` skill to debug, `service-test` skill to validate endpoints

</references>

<troubleshooting>

## Error Handling

See `references/multi-service-errors.md` for error templates covering:
- Partial deployment failure (some services succeed, others fail)
- Circular dependency detection and resolution
- Cross-service connection failures (DNS, ports, credentials)
- Unsupported docker-compose features

### CLI Errors
- `tfy: command not found` -- Install with `pip install truefoundry`
- `tfy apply` validation errors -- Check YAML syntax for each manifest file

</troubleshooting>
</output>
