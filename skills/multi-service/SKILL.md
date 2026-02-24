---
name: multi-service
description: This skill should be used when the user asks "deploy my full app", "deploy frontend and backend", "multi-service deployment", "deploy all services", "microservices deployment", "deploy my docker-compose app", "deploy my monorepo", "deploy multiple containers", "deploy full stack", "deploy interconnected services", "orchestrate service deployment", or has a project with multiple interconnected services that need coordinated deployment on TrueFoundry.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
metadata:
  disable-model-invocation: "true"
allowed-tools: Bash(*/tfy-api.sh *) Bash(python*) Bash(pip*)
---

<objective>

# Multi-Service Application Deployment

Orchestrate the deployment of complex applications with multiple interconnected services on TrueFoundry. This skill builds a dependency graph, deploys services in the correct order, and wires them together so the full application works end-to-end.

## When to Use

- User has a project with multiple services (e.g., frontend + backend + database)
- User says "deploy my full app", "deploy everything", "deploy all services"
- User has a monorepo with multiple deployable components
- User needs microservices deployed together with inter-service communication
- User wants to deploy an app that depends on infrastructure (DB, cache, queue)

## When NOT to Use

- User wants to deploy a single service → use `deploy` skill
- User wants to deploy just a database → use `helm` skill
- User wants to deploy just an LLM → use `llm-deploy` skill
- User wants to check what's deployed → use `applications` skill

## CRITICAL: Service Wiring is MANDATORY

**When deploying multiple services, you MUST wire them together.** Deploying services in isolation without connecting them is useless — a frontend that can't reach its backend, or a backend that can't reach its database, is a broken deployment.

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

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set
2. **Workspace** — `TFY_WORKSPACE_FQN` is required. **Never auto-pick — always ask the user.**

</context>

<instructions>

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

2. **Multiple Dockerfiles** — Look for `Dockerfile`, `Dockerfile.*`, `*/Dockerfile` across the project

3. **Service directories** — Directories with their own `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`

4. **Kubernetes manifests** — Check `k8s/`, `manifests/`, `deploy/` directories

5. **Monorepo patterns** — `services/`, `apps/`, `packages/` with subdirectories

### Classify Each Service

For each discovered service, determine its **type**:

| Type | How to Detect | Deploy Method |
|------|--------------|---------------|
| **Database** | Image is `postgres`, `mysql`, `mariadb`, `mongo` | Helm chart (Bitnami) |
| **Cache** | Image is `redis`, `memcached`, `valkey` | Helm chart (Bitnami) |
| **Queue** | Image is `rabbitmq`, `nats`, `kafka` | Helm chart (Bitnami) |
| **Search/Vector DB** | Image is `elasticsearch`, `qdrant`, `weaviate`, `milvus` | Helm chart or Service |
| **LLM** | Image contains `vllm`, `tgi`, `triton`, `ollama` | `llm-deploy` skill |
| **MCP Server** | Exposes `/mcp` endpoint, uses MCP protocol | `mcp-server` skill |
| **Application** | Has `build:` context or custom image with code | Service deployment |

## Step 2: Build Dependency Graph

Construct a directed acyclic graph (DAG) of service dependencies.

### Sources of Dependency Information

**From docker-compose.yml:**
```yaml
services:
  backend:
    depends_on:
      - db
      - redis
    environment:
      - DATABASE_URL=postgresql://postgres:pass@db:5432/myapp  # ← "db" is a dependency
      - REDIS_URL=redis://redis:6379                           # ← "redis" is a dependency
      - FRONTEND_ORIGIN=http://frontend:3000                   # ← NOT a dependency (frontend depends on backend, not the reverse)
```

**From environment variables:**
Scan env var values for references to other service names. A hostname in a connection string (`@db:5432`, `redis:6379`) implies a dependency.

**From code analysis (if no compose file):**
Look at code for connection patterns:
- `DATABASE_URL`, `MONGO_URI` → depends on database
- `REDIS_URL`, `CACHE_URL` → depends on cache
- `BROKER_URL`, `AMQP_URL` → depends on message queue
- `API_URL`, `BACKEND_URL` → depends on another service

### Dependency Rules

1. **Infrastructure has no dependencies** — databases, caches, queues are leaf nodes
2. **Backend services depend on infrastructure** — and potentially on other backends
3. **Frontends depend on backends** — never on infrastructure directly
4. **Workers depend on queues + databases** — same tier as backends
5. **If A's env vars reference B's hostname → A depends on B**
6. **`depends_on` in compose is explicit** — always respect it

### Detect Circular Dependencies

If the graph has a cycle, **stop and tell the user:**

```
Detected circular dependency: service-a → service-b → service-a

This cannot be deployed in sequence. Options:
1. Break the cycle by making one service start without the other (add retry logic)
2. Use async communication (message queue) instead of direct HTTP calls
3. Merge the tightly coupled services
```

### CRITICAL: Poll Infrastructure Readiness Before Next Tier

> **Tested 2026-02-14**: `DEPLOY_SUCCESS` from the TrueFoundry API does NOT mean Helm chart pods are ready to accept connections. PostgreSQL and Redis charts may show DEPLOY_SUCCESS while pods are still initializing (PVC binding, image pull, startup).

**Between each deployment tier, poll the actual pods for readiness:**

1. After deploying Helm infra (DB, Redis, etc.), poll the application status API repeatedly (every 15s, up to 5 min)
2. Check `applicationComponentStatuses` for pod readiness, not just deployment status
3. For databases: attempt a TCP connection to the service DNS + port before deploying dependent services
4. **Have fallback logic**: If infra isn't ready after 5 min, warn the user rather than deploying dependent services that will crash-loop

```bash
# Example: poll PostgreSQL readiness
for i in $(seq 1 20); do
  # Check if pods are actually responding (from within cluster or via API)
  $TFY_API_SH GET '/api/svc/v1/apps/APP_ID' | jq '.applicationComponentStatuses[0].status'
  sleep 15
done
```

### Compute Deploy Order

Topologically sort the DAG. Services with no dependencies deploy first. Services at the same level in the graph can deploy in parallel.

**Example:**
```
Graph:
  frontend → backend
  backend  → db, redis, worker
  worker   → db, redis, rabbitmq
  db       → (none)
  redis    → (none)
  rabbitmq → (none)

Deploy order:
  Level 0: db, redis, rabbitmq     (parallel — no dependencies)
  Level 1: backend, worker         (parallel — both depend only on level 0)
  Level 2: frontend                (depends on backend from level 1)
```

## Step 3: Present Plan and Ask User

**ALWAYS present the discovered architecture and ask the user to confirm before deploying.**

Show:
1. What services were found (and how — compose file, directory scan, etc.)
2. The dependency graph
3. The deploy order
4. What will be deployed as Helm vs. Service vs. LLM

The plan should include: dependency graph (tree format), deploy order with levels, environment wiring (which env vars connect which services), and questions about workspace, public URLs, and secrets. Always end with "Shall I proceed with this plan?"

**Do NOT deploy until the user confirms.**

## Step 4: Resolve Namespace and DNS

Before deploying, resolve the Kubernetes namespace for the target workspace. This is needed for internal service DNS.

### Get Workspace Details

```bash
TFY_API_SH=~/.claude/skills/truefoundry-multi-service/scripts/tfy-api.sh

# Get workspace details to find the namespace
$TFY_API_SH GET '/api/svc/v1/workspace?workspaceFqn=WORKSPACE_FQN'
```

From the response, extract:
- `id` → workspace ID (needed for deployment API calls)
- `clusterId` → cluster ID (needed for base domain lookup)
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

### For Infrastructure (Helm Charts)

Use the `helm` skill approach. All charts use `PUT /api/svc/v1/apps` with `kind: HelmChart` and `source.repo_url: https://charts.bitnami.com/bitnami`. Common charts:

| Service | `chart_name` | Key Values |
|---------|-------------|------------|
| PostgreSQL | `postgresql` (v16.4.1) | `auth.postgresPassword`, `auth.database`, `primary.persistence.size: "10Gi"` |
| Redis | `redis` (v20.6.2) | `auth.password`, `architecture: "standalone"` |
| RabbitMQ | `rabbitmq` (v15.1.2) | `auth.username`, `auth.password` |
| MongoDB | `mongodb` | `auth.rootUser`, `auth.rootPassword` |

Name each chart `APP_NAME-{service}` (e.g., `myapp-db`, `myapp-redis`). See the `helm` skill for full manifest examples.

### Verify Infrastructure is Running

Before deploying dependent services, poll until infrastructure is healthy:

```bash
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=APP_NAME-db'
# Check status == "RUNNING"
```

### For Application Services

Deploy using the Service manifest with wired env vars:

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "kind": "Service",
    "name": "APP_NAME-backend",
    "image": {
      "type": "image",
      "image_uri": "PREBUILT_IMAGE_OR_REGISTRY_IMAGE",
      "command": "uvicorn main:app --host 0.0.0.0 --port 8000"
    },
    "ports": [
      {
        "port": 8000,
        "protocol": "TCP",
        "expose": true,
        "host": "APP_NAME-backend-WS.BASE_DOMAIN",
        "app_protocol": "http"
      }
    ],
    "resources": {
      "cpu_request": 0.5,
      "cpu_limit": 1.0,
      "memory_request": 512,
      "memory_limit": 1024
    },
    "env": {
      "DATABASE_URL": "postgresql://postgres:PASSWORD@APP_NAME-db-postgresql.NAMESPACE.svc.cluster.local:5432/DB_NAME",
      "REDIS_URL": "redis://:PASSWORD@APP_NAME-redis-redis-master.NAMESPACE.svc.cluster.local:6379/0"
    },
    "replicas": { "min": 1, "max": 1 }
  },
  "workspaceId": "WORKSPACE_ID"
}'
```

**If the service has a `build:` context (docker-compose) or a Dockerfile**, use the `deploy` skill's build approach instead of a pre-built image. Create a `deploy.py` per service.

### For LLM Services

If the dependency graph includes an LLM, use the `llm-deploy` skill's approach with GPU allocation.

## Step 6: Wire Environment Variables

**This is the most critical step.** Every cross-service reference must be translated from compose service names to Kubernetes DNS.

### Translation Rule

In docker-compose, services reference each other by service name:
```yaml
DATABASE_URL=postgresql://postgres:pass@db:5432/myapp
```

In TrueFoundry, replace the service name with Kubernetes DNS:
```
DATABASE_URL=postgresql://postgres:pass@APP_NAME-db-postgresql.NAMESPACE.svc.cluster.local:5432/myapp
```

### Common Wiring Patterns

| Compose Env Var | TrueFoundry Env Var |
|----------------|---------------------|
| `@db:5432` | `@{name}-db-postgresql.{ns}.svc.cluster.local:5432` |
| `@redis:6379` | `@{name}-redis-redis-master.{ns}.svc.cluster.local:6379` |
| `@rabbitmq:5672` | `@{name}-rabbitmq-rabbitmq.{ns}.svc.cluster.local:5672` |
| `@mongo:27017` | `@{name}-mongo-mongodb.{ns}.svc.cluster.local:27017` |
| `http://backend:8000` | `http://{name}-backend.{ns}.svc.cluster.local:8000` |
| `http://frontend:3000` | `https://{name}-frontend-{ws}.{base_domain}` (if public) |

### Secrets for Credentials

For passwords shared between infrastructure and services:

1. **Generate strong passwords** — `openssl rand -base64 24` for each
2. **Store in TrueFoundry secrets** (using `secrets` skill):
   ```bash
   $TFY_API_SH POST /api/svc/v1/secret-groups '{
     "name": "APP_NAME-secrets",
     "secrets": [
       {"key": "db-password", "value": "GENERATED_PASSWORD"},
       {"key": "redis-password", "value": "GENERATED_PASSWORD"}
     ]
   }'
   ```
3. **Reference in env vars**:
   ```python
   env = {
       "DB_PASSWORD": "tfy-secret://DOMAIN:APP_NAME-secrets:db-password",
   }
   ```

## Step 7: Verify Connectivity

After all services are deployed and running, verify they can reach each other.

### Check Deployment Status

```bash
# Check all services are RUNNING
for app in APP_NAME-db APP_NAME-redis APP_NAME-backend APP_NAME-frontend; do
  $TFY_API_SH GET "/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=$app"
done
```

### Check Logs for Connection Errors

For each application service, download recent logs and search for connection errors:

```bash
$TFY_API_SH GET '/api/svc/v1/logs/WORKSPACE_ID/download?applicationFqn=APP_FQN&startTs=DEPLOY_TIME&searchString=error&searchType=contains'
```

Look for:
- `Connection refused` → dependency not reachable (wrong DNS or not running)
- `Authentication failed` → password mismatch between infra and service
- `Name resolution failed` → wrong service name in DNS
- `Timeout` → service is starting slowly (check health probes)

### Hit Service Endpoints

If services have public URLs, test them:

```bash
# Backend health
curl -s -o /dev/null -w '%{http_code}' "https://APP_NAME-backend-WS.BASE_DOMAIN/health"

# Frontend
curl -s -o /dev/null -w '%{http_code}' "https://APP_NAME-frontend-WS.BASE_DOMAIN/"
```

Use the `service-test` skill for deeper validation.

## Step 8: Report Deployment Summary

**CRITICAL: Always provide a comprehensive summary with ALL URLs and wiring.**

The summary must include:
1. **Component table** — each service with its type (Helm/Service), status, and URL or internal DNS
2. **Wiring map** — which env vars connect which services (mask passwords with `***`)
3. **Access URLs** — public URLs for frontend and API docs
4. **Next steps** — open frontend, use `logs` skill if broken, use `service-test` skill to validate

**The user should be able to open the frontend URL and see a working app.** If they can't, the deployment is not done.

## docker-compose.yml Translation

See `references/compose-translation.md` for the full translation reference. Key points:

- **Always scan for compose files first** before asking the user about architecture
- `build:` services -> TrueFoundry Service with `DockerFileBuild`
- `image:` services (custom) -> TrueFoundry Service with pre-built image
- `image:` services (postgres, redis, etc.) -> Helm charts (Bitnami)
- `depends_on` -> deploy order in the dependency graph
- `healthcheck` -> TrueFoundry liveness/readiness probes
- `volumes` -> Helm persistence or TrueFoundry Volumes
- `networks` -> ignored (all services share a K8s namespace)
- `env_file` / `secrets` -> read values, create TrueFoundry secrets as needed

## Compound AI & Monorepo Patterns

See `references/multi-service-patterns.md` for ready-made dependency graphs and deploy orders for:
- **RAG applications** (LLM + vector DB + API + frontend)
- **AI Agent with tools** (LLM + MCP server + DB)
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
- **MCP Servers**: Uses `mcp-server` skill if the app includes MCP servers
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

</troubleshooting>
