# Multi-Service Application Deployment

Orchestrate the deployment of complex applications with multiple interconnected services on TrueFoundry. Build a dependency graph, deploy services in the correct order, and wire them together so the full application works end-to-end.

Each service gets its own YAML manifest, applied in dependency order with `tfy apply`.

## CRITICAL: Service Wiring is MANDATORY

**When deploying multiple services, you MUST wire them together.** Deploying services in isolation without connecting them is useless — a frontend that can't reach its backend, or a backend that can't reach its database, is a broken deployment.

**The agent MUST:**
1. Build a dependency graph of all services
2. Configure environment variables so each service knows how to reach its dependencies
3. Deploy in topologically sorted order
4. Verify connectivity between services after deployment
5. Return ALL deployment URLs and internal DNS addresses in the final summary

## Step 1: Discover Services

**Proactively scan the project** to find all deployable components.

### Scan Order

1. **`docker-compose.yml` / `docker-compose.yaml` / `compose.yml` / `compose.yaml`** — Primary source of truth if present. Parse to extract services, ports, environment variables, `depends_on`, volumes, health checks.
2. **Multiple Dockerfiles** — `Dockerfile`, `Dockerfile.*`, `*/Dockerfile`
3. **Service directories** — Directories with their own `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`
4. **Kubernetes manifests** — Check `k8s/`, `manifests/`, `deploy/` directories
5. **Monorepo patterns** — `services/`, `apps/`, `packages/` with subdirectories

### Classify Each Service

```
IF service has image: field:
  Extract image name (strip registry prefix and tag)
  IF image matches postgres/mysql/mariadb/mongo       -> Helm Database
  ELSE IF image matches redis/valkey/memcached         -> Helm Cache
  ELSE IF image matches rabbitmq/nats/kafka            -> Helm Queue
  ELSE IF image matches elasticsearch/qdrant/weaviate  -> Helm Search/VectorDB
  ELSE IF image matches vllm/tgi/triton/ollama         -> LLM Service
  ELSE                                                 -> Application Service (pre-built image)
ELSE IF service has build: field:
  -> Application Service (build from source)
```

| Type | Image Patterns | Deploy Method |
|------|---------------|---------------|
| **Database** | `postgres:*`, `mysql:*`, `mariadb:*`, `mongo:*` | Helm chart via `tfy apply` |
| **Cache** | `redis:*`, `memcached:*`, `valkey:*` | Helm chart via `tfy apply` |
| **Queue** | `rabbitmq:*`, `nats:*`, `kafka:*` | Helm chart via `tfy apply` |
| **Search/Vector DB** | `elasticsearch:*`, `qdrant/*`, `weaviate/*` | Helm chart via `tfy apply` |
| **LLM** | `vllm/*`, `*tgi*`, `*triton*` | `llm-deploy` skill |
| **Application** | Has `build:` or custom image | Service via `tfy apply` |

See `compose-translation.md` for the complete classification reference and step-by-step conversion.

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
      - DATABASE_URL=postgresql://postgres:DB_PASSWORD@db:5432/myapp  # "db" is a dependency
      - REDIS_URL=redis://redis:6379                           # "redis" is a dependency
```

**From environment variables:** Scan env var values for references to other service names. A hostname in a connection string (`@db:5432`, `redis:6379`) implies a dependency.

**From code analysis (if no compose file):** Look for `DATABASE_URL`, `REDIS_URL`, `BROKER_URL`, `API_URL`, `BACKEND_URL` patterns.

### Dependency Rules

1. **Infrastructure has no dependencies** — databases, caches, queues are leaf nodes
2. **Backend services depend on infrastructure** — and potentially on other backends
3. **Frontends depend on backends** — never on infrastructure directly
4. **Workers depend on queues + databases** — same tier as backends
5. **If A's env vars reference B's hostname → A depends on B**
6. **`depends_on` in compose is explicit** — always respect it

### Detect Circular Dependencies

If the graph has a cycle, **stop and tell the user** with options to break the cycle.

### CRITICAL: Poll Infrastructure Readiness

`DEPLOY_SUCCESS` from the API does NOT mean Helm chart pods are ready. PostgreSQL and Redis charts may show DEPLOY_SUCCESS while pods are still initializing.

**Between each tier, poll actual pods for readiness:**

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh
for i in $(seq 1 20); do
  bash $TFY_API_SH GET '/api/svc/v1/apps/APP_ID' | jq '.applicationComponentStatuses[0].status'
  sleep 15
done
```

If infra isn't ready after 5 min, warn the user rather than deploying dependent services.

### Compute Deploy Order

Topologically sort the DAG:

```
Graph:
  frontend -> backend
  backend  -> db, redis, worker
  worker   -> db, redis, rabbitmq

Deploy order:
  Level 0: db, redis, rabbitmq     (parallel)
  Level 1: backend, worker         (parallel)
  Level 2: frontend                (depends on level 1)
```

## Step 3: Present Plan and Ask User

**ALWAYS present the discovered architecture and ask for confirmation before deploying.**

Show:
1. What services were found (and how — compose file, directory scan, etc.)
2. The dependency graph
3. The deploy order
4. What will be deployed as Helm vs. Service vs. LLM
5. Questions about workspace, public URLs, secrets, and **auto-shutdown**

**Do NOT deploy until the user confirms.**

## Step 4: Resolve Namespace and DNS

### Get Workspace Details

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh
bash $TFY_API_SH GET '/api/svc/v1/workspace?workspaceFqn=WORKSPACE_FQN'
```

Extract `id` (workspace ID), `clusterId`, and namespace.

### Get Base Domain (for public URLs)

```bash
bash $TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

Pick wildcard domain, strip `*.` for base domain. Public URL pattern: `{service-name}-{workspace-name}.{base_domain}`

### Internal DNS Patterns

**Application services** (type: service):
```
{app-name}.{namespace}.svc.cluster.local:{port}
```

**Helm charts** (type: helm):

| Chart | DNS Pattern | Port |
|-------|-------------|------|
| PostgreSQL | `{release-name}-postgresql.{ns}.svc.cluster.local` | 5432 |
| Redis | `{release-name}-redis-master.{ns}.svc.cluster.local` | 6379 |
| MongoDB | `{release-name}-mongodb.{ns}.svc.cluster.local` | 27017 |
| MySQL | `{release-name}-mysql.{ns}.svc.cluster.local` | 3306 |
| RabbitMQ | `{release-name}-rabbitmq.{ns}.svc.cluster.local` | 5672 |

Use short names like `myapp-db` (not `myapp-postgresql`) to avoid redundant DNS. See `service-wiring.md` for the complete DNS reference.

## Step 5: Deploy in Graph Order

Walk the dependency graph level by level. **Wait for each level to be healthy before proceeding.**

Each service gets its own YAML manifest file. Reference `manifest-schema.md` for fields and `manifest-defaults.md` for defaults. If `tfy` CLI is unavailable, see `cli-fallback.md`.

### For Infrastructure (Helm Charts)

Example PostgreSQL:

```yaml
name: myapp-db
type: helm
source:
  type: oci-repo
  version: "16.4.1"
  oci_chart_url: oci://REGISTRY/CHART_NAME
values:
  auth:
    postgresPassword: GENERATED_PASSWORD
    database: myapp
  primary:
    persistence:
      enabled: true
      size: 10Gi
    resources:
      requests:
        cpu: "0.5"
        memory: 512Mi
workspace_fqn: cluster-id:workspace-name
```

```bash
tfy apply -f tfy-manifest-db.yaml
```

### For Application Services

```yaml
name: myapp-backend
type: service
image:
  type: image
  image_uri: PREBUILT_IMAGE_OR_REGISTRY_IMAGE
ports:
  - port: 8000
    expose: true
    host: myapp-backend-ws.BASE_DOMAIN
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
env:
  DATABASE_URL: postgresql://postgres:PASSWORD@myapp-db-postgresql.NAMESPACE.svc.cluster.local:5432/DB_NAME
  REDIS_URL: redis://:PASSWORD@myapp-redis-redis-master.NAMESPACE.svc.cluster.local:6379/0
replicas:
  min: 1
  max: 1
workspace_fqn: cluster-id:workspace-name
```

**If the service has a `build:` context**, use Git build source with `tfy deploy`.

### For LLM Services

Use the `llm-deploy` skill's approach with GPU allocation.

## Step 6: Wire Environment Variables

**This is the most critical step.** Every cross-service reference must be translated from compose service names to Kubernetes DNS.

### Translation Rule

In docker-compose: `DATABASE_URL=postgresql://postgres:DB_PASSWORD@db:5432/myapp`
In TrueFoundry: `DATABASE_URL=postgresql://postgres:DB_PASSWORD@myapp-db-postgresql.NAMESPACE.svc.cluster.local:5432/myapp`

### Common Wiring Patterns

| Compose Reference | TFY Release Name | TFY DNS |
|-------------------|-------------------|---------|
| `@db:5432` | `{app}-db` | `@{app}-db-postgresql.{ns}.svc.cluster.local:5432` |
| `redis://redis:6379` | `{app}-cache` | `redis://{app}-cache-redis-master.{ns}.svc.cluster.local:6379` |
| `@mongo:27017` | `{app}-mongo` | `@{app}-mongo-mongodb.{ns}.svc.cluster.local:27017` |
| `amqp://rabbitmq:5672` | `{app}-queue` | `amqp://{app}-queue-rabbitmq.{ns}.svc.cluster.local:5672` |
| `http://backend:8000` | `{app}-backend` | `http://{app}-backend.{ns}.svc.cluster.local:8000` |

See `service-wiring.md` for the complete wiring algorithm and validation checklist.

### Secrets for Credentials

1. **Generate strong passwords** — `openssl rand -base64 24`
2. **Store in TrueFoundry secrets** and reference as `tfy-secret://DOMAIN:SECRET_GROUP:KEY`

## Step 7: Verify Connectivity

1. **Check deployment status** — Poll each service and confirm `DEPLOY_SUCCESS`
2. **Check logs for connection errors** — Use `logs` skill to search for `Connection refused`, `Authentication failed`, `Name resolution failed`
3. **Hit service endpoints** — `curl` public URLs to verify HTTP 200
4. Use the `service-test` skill for deeper validation.

## Step 8: Report Deployment Summary

**CRITICAL: Always provide a comprehensive summary with ALL URLs and wiring.**

Include:
1. **Component table** — each service with type (Helm/Service), status, URL or internal DNS
2. **Wiring map** — which env vars connect which services (mask passwords with `***`)
3. **Access URLs** — public URLs for frontend and API docs
4. **Next steps** — open frontend, use `logs` skill if broken, use `service-test` to validate

**The user should be able to open the frontend URL and see a working app.**

## docker-compose.yml Translation

See `compose-translation.md` for the complete reference. Key rules:

- **Always scan for compose files first**
- **Use short release names** for Helm charts: `{app}-db` not `{app}-postgresql`
- `build:` services → YAML manifest with git build source + `tfy deploy`
- `image:` services (custom) → YAML manifest with pre-built image + `tfy apply`
- `image:` services (postgres, redis, etc.) → Helm manifests via `tfy apply`
- `depends_on` → deploy order in the dependency graph
- `healthcheck` → TrueFoundry liveness/readiness probes
- `volumes` → Helm persistence or TrueFoundry Volumes
- `networks` → ignored (all services share a K8s namespace)

## Compound AI & Monorepo Patterns

See `multi-service-patterns.md` for ready-made dependency graphs and deploy orders for:
- **RAG applications** (LLM + vector DB + API + frontend)
- **AI Agent with tools** (LLM + tool server + DB)
- **Full-Stack SaaS with AI** (frontend + backend + workers + infra + LLM)
- **Monorepo support** (detecting structure, shared code, build contexts)

## Error Handling

See `multi-service-errors.md` for error templates covering:
- Partial deployment failure
- Circular dependency detection and resolution
- Cross-service connection failures
- Unsupported docker-compose features
