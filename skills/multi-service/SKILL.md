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
| **Database** | Image is `postgres`, `mysql`, `mariadb`, `mongo` | Helm chart (ask user for chart source) |
| **Cache** | Image is `redis`, `memcached`, `valkey` | Helm chart (ask user for chart source) |
| **Queue** | Image is `rabbitmq`, `nats`, `kafka` | Helm chart (ask user for chart source) |
| **Search/Vector DB** | Image is `elasticsearch`, `qdrant`, `weaviate`, `milvus` | Helm chart or Service |
| **LLM** | Image contains `vllm`, `tgi`, `triton`, `ollama` | `llm-deploy` skill |
| **MCP Server** | Exposes `/mcp` endpoint, uses MCP protocol | `mcp-server` skill |
| **Application** | Has `build:` context or custom image with code | Service deployment |

## Step 2: Build Dependency Graph

Construct a directed acyclic graph (DAG) of service dependencies. For dependency detection sources (compose, env vars, code analysis), dependency rules, circular dependency handling, infrastructure readiness polling, and topological sort examples, see [references/dependency-graph.md](references/dependency-graph.md).

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

Use the `helm` skill approach. All charts use `PUT /api/svc/v1/apps` with `type: "helm"`. **Ask the user for the chart source URL, chart name, and version.** Do not assume a specific chart registry.

Name each chart `APP_NAME-{service}` (e.g., `myapp-db`, `myapp-redis`). See the `helm` skill for full manifest examples and source type formats (`oci-repo`, `helm-repo`, `git-helm-repo`).

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

**If the service has a `build:` context (docker-compose) or a Dockerfile**, use the `deploy` skill's build approach instead of a pre-built image. Create a `deploy.py` per service.

### For LLM Services

If the dependency graph includes an LLM, use the `llm-deploy` skill's approach with GPU allocation.

## Step 6: Wire Environment Variables

**This is the most critical step.** Every cross-service reference must be translated from compose service names to Kubernetes DNS. For the translation rule, common wiring patterns (DB, Redis, RabbitMQ, etc.), DNS patterns, and secrets management, see [references/service-wiring.md](references/service-wiring.md).

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
- `image:` services (postgres, redis, etc.) -> Helm charts (ask user for chart source)
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
