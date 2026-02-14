---
name: multi-service
description: This skill should be used when the user asks "deploy my full app", "deploy frontend and backend", "multi-service deployment", "deploy all services", "microservices deployment", or has a project with multiple interconnected services that need coordinated deployment on TrueFoundry.
disable-model-invocation: true
allowed-tools: Bash(*/tfy-api.sh *), Bash(python*), Bash(pip*)
---

# Multi-Service Application Deployment

Orchestrate the deployment of complex applications with multiple interconnected services on TrueFoundry. This skill coordinates deploying infrastructure (databases, caches), backend services, and frontends in the correct order with proper wiring.

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

**When deploying multiple services, you MUST wire them together.** Deploying services in isolation without connecting them is pointless — a frontend that can't reach its backend, or a backend that can't reach its database, is a broken deployment.

**The agent MUST:**
1. Identify ALL dependencies between services (which service needs to talk to which)
2. Configure environment variables so each service knows how to reach its dependencies
3. Deploy in the correct order (infrastructure → backends → frontends)
4. Verify connectivity between services after deployment
5. Return ALL deployment URLs and internal DNS addresses in the final summary

**If the user deploys a frontend + backend + database, the frontend MUST work end-to-end.** Not just individually deployed services.

## Prerequisites

Same as other deploy skills:

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set
2. **Workspace** — `TFY_WORKSPACE_FQN` is required. Never auto-pick.

## Step 1: Analyze Project Architecture

Scan the user's project to identify all deployable components:

### What to Look For

1. **Project structure** — Look for multiple service directories:
   ```
   my-app/
   ├── frontend/          # React/Next.js app
   ├── backend/           # API server
   ├── worker/            # Background processor
   ├── docker-compose.yml # Service definitions
   └── ...
   ```

2. **docker-compose.yml** — If present, this is a goldmine. Parse it to identify:
   - Services and their images/build contexts
   - Port mappings
   - Environment variables and secrets
   - Dependencies (`depends_on`)
   - Volumes and storage needs
   - Network configuration

3. **Kubernetes manifests** — Check for `k8s/`, `manifests/`, `deploy/` directories with YAML files

4. **Package files** — Multiple `package.json`, `requirements.txt`, `go.mod` in different directories

5. **Dockerfiles** — Multiple Dockerfiles or `Dockerfile.*` variants

### Categorize Components

Group discovered components into deployment tiers:

| Tier | Type | Examples | Deploy Order |
|------|------|----------|-------------|
| **1. Infrastructure** | Databases, caches, queues | PostgreSQL, Redis, RabbitMQ, MongoDB | First (others depend on these) |
| **2. Backend services** | APIs, workers, processors | FastAPI, Express, Go services, Celery workers | After infrastructure |
| **3. Frontend** | Web UIs, static sites | React, Next.js, Vue | After backends |
| **4. Supporting** | Monitoring, logging | Prometheus, Grafana | Any time |

## Step 2: Present Architecture Plan

Show the user what you found and confirm the deployment plan:

```
I've analyzed your project and found these components:

Architecture:
┌─────────────────────────────────────────────┐
│                  Frontend                    │
│              (Next.js, port 3000)            │
│                     │                        │
│                     ▼                        │
│              Backend API                     │
│            (FastAPI, port 8000)              │
│              │           │                   │
│              ▼           ▼                   │
│         PostgreSQL    Redis                  │
│         (port 5432)  (port 6379)             │
└─────────────────────────────────────────────┘

Deployment plan (in order):
1. PostgreSQL (Helm) — database for backend
2. Redis (Helm) — cache/session store
3. Backend API (Service) — depends on PostgreSQL + Redis
4. Frontend (Service) — depends on Backend API

Each component will be deployed to workspace: {workspace}

Shall I proceed with this plan? Any changes needed?
```

## Step 3: Gather Configuration Per Component

For each component, ask targeted questions based on its type:

### Infrastructure (Helm Charts)
- Use the `helm` skill's configuration approach
- Ask about: storage size, replicas, passwords, environment (dev/staging/prod)
- Generate credentials (or reference TrueFoundry secrets)

### Backend Services
- Use the `deploy` skill's analysis approach
- Ask about: resources (use Step 1 resource advisor from deploy skill), public/internal access, env vars
- **Identify cross-service connections** — these become env vars:
  ```
  DATABASE_URL=postgresql://user:pass@{postgres-name}-postgresql.{namespace}.svc.cluster.local:5432/mydb
  REDIS_URL=redis://:{password}@{redis-name}-redis-master.{namespace}.svc.cluster.local:6379/0
  ```

### Frontend
- Ask about: public URL, backend API URL, resources
- The API URL is typically the backend's internal DNS or public URL

## Step 4: Wire Services Together

**This is the critical step that makes multi-service deployments work.**

### Internal Service DNS

Services within the same cluster communicate via Kubernetes DNS:
```
{service-name}.{namespace}.svc.cluster.local:{port}
```

For TrueFoundry deployments, the namespace is derived from the workspace. The service name matches the deployment name.

### Connection Patterns

#### Backend → Database (Helm)
```python
env = {
    "DATABASE_URL": "postgresql://postgres:{password}@{helm-release-name}-postgresql.{namespace}.svc.cluster.local:5432/{db_name}",
}
```

#### Backend → Cache (Helm)
```python
env = {
    "REDIS_URL": "redis://:{password}@{helm-release-name}-redis-master.{namespace}.svc.cluster.local:6379/0",
}
```

#### Backend → Message Queue (Helm)
```python
env = {
    "RABBITMQ_URL": "amqp://admin:{password}@{helm-release-name}-rabbitmq.{namespace}.svc.cluster.local:5672/",
}
```

#### Frontend → Backend
```python
# If backend is internal-only:
env = {
    "API_URL": "http://{backend-service-name}.{namespace}.svc.cluster.local:8000",
}

# If backend has a public URL:
env = {
    "NEXT_PUBLIC_API_URL": "https://{backend-host}",
}
```

#### Service → Service (internal)
```python
env = {
    "AUTH_SERVICE_URL": "http://auth-service.{namespace}.svc.cluster.local:8000",
    "NOTIFICATION_SERVICE_URL": "http://notifications.{namespace}.svc.cluster.local:8000",
}
```

### Secrets Wiring

For credentials shared between infrastructure and services:

1. **Generate passwords** during infrastructure deployment
2. **Store in TrueFoundry secrets** using the `secrets` skill
3. **Reference in service env vars** using `tfy-secret://` URIs:
   ```python
   env = {
       "DATABASE_URL": "postgresql://postgres:$(DB_PASSWORD)@postgres.ns.svc.cluster.local:5432/mydb",
       "DB_PASSWORD": "tfy-secret://tfy-eo:my-app-secrets:db-password",
   }
   ```

## Step 5: Deploy in Order

Execute deployments tier by tier. **Wait for each tier to be ready before proceeding to the next.**

### Tier 1: Infrastructure

Deploy databases, caches, and queues first using the `helm` skill approach:

```bash
# Deploy PostgreSQL
$TFY_API_SH PUT /api/svc/v1/apps '{...postgres manifest...}'

# Deploy Redis (can be parallel with PostgreSQL)
$TFY_API_SH PUT /api/svc/v1/apps '{...redis manifest...}'
```

**Verify infrastructure is running** before proceeding:
```bash
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE&applicationName=postgres-name'
```

### Tier 2: Backend Services

Deploy backend services with environment variables pointing to infrastructure:

```bash
# Deploy backend API
$TFY_API_SH PUT /api/svc/v1/apps '{...backend manifest with DATABASE_URL, REDIS_URL...}'

# Deploy workers (can be parallel with API if they share the same deps)
$TFY_API_SH PUT /api/svc/v1/apps '{...worker manifest...}'
```

### Tier 3: Frontend

Deploy frontend with the backend API URL:

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{...frontend manifest with API_URL...}'
```

## Step 6: Report Deployment Summary

**CRITICAL: Always provide a comprehensive deployment summary with ALL URLs and wiring details.**

After all components are deployed, present this summary:

```
Multi-service deployment complete!

Workspace: {workspace-fqn}

┌──────────────────────────────────────────────────────────────────────────┐
│ Component    │ Type     │ Status  │ URL / DNS                            │
│──────────────│──────────│─────────│──────────────────────────────────────│
│ PostgreSQL   │ Helm     │ Running │ postgres.ns.svc.cluster.local:5432   │
│ Redis        │ Helm     │ Running │ redis-master.ns.svc.cluster.local:6379│
│ LLM (vLLM)  │ Service  │ Running │ https://llm-ws.ml.tfy.cloud          │
│ Backend API  │ Service  │ Running │ https://api-ws.ml.tfy.cloud          │
│ Frontend     │ Service  │ Running │ https://app-ws.ml.tfy.cloud          │
└──────────────────────────────────────────────────────────────────────────┘

Service Wiring:
  Frontend → Backend API:  NEXT_PUBLIC_API_URL=https://api-ws.ml.tfy.cloud
  Backend  → PostgreSQL:   DATABASE_URL=postgresql://...
  Backend  → Redis:        REDIS_URL=redis://...
  Backend  → LLM:          LLM_BASE_URL=http://llm.ns.svc.cluster.local:8000/v1

Access your app:
  Frontend: https://app-ws.ml.tfy.cloud
  API:      https://api-ws.ml.tfy.cloud/docs  (FastAPI Swagger)
  LLM:     https://llm-ws.ml.tfy.cloud/v1/chat/completions

Next steps:
  1. Open the frontend URL in your browser to verify end-to-end
  2. Check logs for any connection issues: Use `logs` skill
  3. Monitor services: Use `applications` skill
```

**The user should be able to copy-paste the frontend URL and see a working app.** If they can't, the deployment is not done.

## docker-compose.yml Translation

Many users have existing `docker-compose.yml` files. Here's how to translate common patterns:

### Service → TrueFoundry Service
```yaml
# docker-compose.yml
services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://postgres:pass@db:5432/myapp
    depends_on:
      - db
```

Translates to a TrueFoundry Service deployment:
- `build: ./backend` → `DockerFileBuild` with the backend Dockerfile
- `ports: "8000:8000"` → `Port(port=8000, ...)`
- `environment` → `env` dict (replace `db` hostname with Kubernetes DNS)
- `depends_on: db` → Deploy `db` first (Tier 1), then this service (Tier 2)

### Database Service → Helm Chart
```yaml
# docker-compose.yml
services:
  db:
    image: postgres:16
    environment:
      - POSTGRES_PASSWORD=mypass
      - POSTGRES_DB=myapp
    volumes:
      - pgdata:/var/lib/postgresql/data
```

Translates to a TrueFoundry Helm chart deployment:
- `image: postgres:16` → Bitnami PostgreSQL chart (not a raw image)
- `POSTGRES_PASSWORD` → `values.auth.postgresPassword`
- `POSTGRES_DB` → `values.auth.database`
- `volumes: pgdata` → `values.primary.persistence.enabled: true` + `size`

### Redis/Cache → Helm Chart
```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

Translates to Bitnami Redis Helm chart.

### Key Translation Rules

| docker-compose | TrueFoundry |
|----------------|-------------|
| `build: ./dir` | `deploy` skill with DockerFileBuild |
| `image: postgres:16` | `helm` skill with Bitnami chart |
| `image: redis:7` | `helm` skill with Bitnami chart |
| `image: custom:tag` | `deploy` skill or `applications` skill with pre-built image |
| `ports: "8000:8000"` | `Port(port=8000)` in service manifest |
| `environment:` | `env` dict in service manifest |
| `depends_on:` | Deploy order (infrastructure first) |
| `volumes:` | Persistence in Helm values, or ephemeral storage in service resources |
| Service name (e.g., `db`) | `{name}.{namespace}.svc.cluster.local` in Kubernetes DNS |
| `networks:` | Not needed — all services in same workspace share a namespace |

## Compound AI Application Patterns

For AI-powered applications with multiple components (LLM + vector DB + API + frontend), follow these patterns:

### RAG Application (Retrieval-Augmented Generation)

```
Architecture:
┌─────────────────────────────────────────────────────────┐
│                    Frontend (Next.js)                     │
│                         │                                │
│                         ▼                                │
│                   Backend API (FastAPI)                   │
│                    │            │                         │
│                    ▼            ▼                         │
│              LLM Service    Vector DB                    │
│              (vLLM)         (Qdrant/Weaviate)            │
│                                │                         │
│                                ▼                         │
│                          PostgreSQL                       │
│                     (metadata storage)                    │
└─────────────────────────────────────────────────────────┘

Deployment order:
1. PostgreSQL (Helm) — metadata storage
2. Qdrant/Vector DB (Helm) — embedding storage
3. LLM Service (llm-deploy skill) — inference endpoint
4. Backend API (deploy skill) — orchestration layer
5. Frontend (deploy skill) — user interface
```

**Backend API env wiring:**
```python
env = {
    # Database
    "DATABASE_URL": "postgresql://postgres:{password}@{postgres-name}-postgresql.{namespace}.svc.cluster.local:5432/ragdb",
    # Vector DB
    "QDRANT_URL": "http://{qdrant-name}-qdrant.{namespace}.svc.cluster.local:6333",
    # LLM
    "LLM_BASE_URL": "http://{llm-service-name}.{namespace}.svc.cluster.local:8000/v1",
    "LLM_MODEL_NAME": "{served-model-name}",
    # Or use AI Gateway for LLM access:
    # "LLM_BASE_URL": "https://{gateway-url}/api/llm",
    # "LLM_API_KEY": "tfy-secret://{domain}:{group}:{key}",
}
```

**Frontend env wiring:**
```python
env = {
    "NEXT_PUBLIC_API_URL": "https://{backend-host}",  # if backend is public
    # OR internal:
    # "API_URL": "http://{backend-name}.{namespace}.svc.cluster.local:8000",
}
```

### AI Agent with Tools

```
Architecture:
┌─────────────────────────────────────────────────────────┐
│                   Agent API (FastAPI)                     │
│                    │      │       │                       │
│                    ▼      ▼       ▼                       │
│               LLM     MCP Server  Database               │
│              (vLLM)   (tools)     (PostgreSQL)           │
└─────────────────────────────────────────────────────────┘

Deployment order:
1. PostgreSQL (Helm)
2. MCP Server (mcp-server skill) — tool execution
3. LLM Service (llm-deploy skill) — reasoning
4. Agent API (deploy skill) — orchestration
```

**Agent API env wiring:**
```python
env = {
    "DATABASE_URL": "postgresql://postgres:{password}@{postgres-name}-postgresql.{namespace}.svc.cluster.local:5432/agentdb",
    "LLM_BASE_URL": "http://{llm-service-name}.{namespace}.svc.cluster.local:8000/v1",
    "LLM_MODEL_NAME": "{served-model-name}",
    "MCP_SERVER_URL": "http://{mcp-server-name}.{namespace}.svc.cluster.local:8000",
}
```

### Full-Stack SaaS with AI

```
Architecture:
┌─────────────────────────────────────────────────────────┐
│                    Frontend (Next.js)                     │
│                         │                                │
│                         ▼                                │
│                   Backend API (FastAPI)                   │
│               │        │        │         │              │
│               ▼        ▼        ▼         ▼              │
│          PostgreSQL  Redis    LLM      Worker            │
│          (primary)  (cache)  (vLLM)   (Celery)          │
│                                          │               │
│                                     RabbitMQ             │
└─────────────────────────────────────────────────────────┘

Deployment order:
1. PostgreSQL, Redis, RabbitMQ (Helm — all infrastructure, can be parallel)
2. LLM Service (llm-deploy skill)
3. Celery Worker (deploy skill — connects to RabbitMQ, PostgreSQL, LLM)
4. Backend API (deploy skill — connects to everything)
5. Frontend (deploy skill — connects to Backend API)
```

**Backend API env wiring:**
```python
env = {
    "DATABASE_URL": "postgresql://postgres:{password}@{postgres-name}-postgresql.{namespace}.svc.cluster.local:5432/appdb",
    "REDIS_URL": "redis://:{password}@{redis-name}-redis-master.{namespace}.svc.cluster.local:6379/0",
    "CELERY_BROKER_URL": "amqp://admin:{password}@{rabbitmq-name}-rabbitmq.{namespace}.svc.cluster.local:5672/",
    "LLM_BASE_URL": "http://{llm-service-name}.{namespace}.svc.cluster.local:8000/v1",
    "LLM_MODEL_NAME": "{served-model-name}",
}
```

### Wiring Verification Checklist

**After deploying all components, verify:**

- [ ] Each service can reach its dependencies (check logs for connection errors)
- [ ] Database connections are established (no "connection refused" in backend logs)
- [ ] LLM endpoint responds to health checks from the backend
- [ ] Frontend can call backend API endpoints
- [ ] Environment variables are correctly set (no placeholder values)
- [ ] Secrets are properly mounted (no authentication errors)
- [ ] All URLs use correct port numbers

**If any connection fails, check:**
1. Service name matches what was deployed (case-sensitive)
2. Namespace is correct (derived from workspace)
3. Port number matches the service's configured port
4. Credentials match between infrastructure and service env vars

## Monorepo Support

For monorepos with multiple services:

1. **Detect structure** — Look for directories with their own Dockerfile, package.json, or requirements.txt
2. **Each service gets its own deployment** — Separate deploy.py or API manifest per service
3. **Shared code** — If services share code, each Dockerfile should COPY the shared directory
4. **Build context** — Set `build_context_path` to the repo root if services reference parent directories

```
monorepo/
├── services/
│   ├── api/
│   │   ├── Dockerfile
│   │   └── main.py
│   ├── worker/
│   │   ├── Dockerfile
│   │   └── worker.py
│   └── frontend/
│       ├── Dockerfile
│       └── package.json
├── shared/
│   └── models.py
└── docker-compose.yml
```

Each service gets deployed independently but wired together via env vars.

## Composability

This skill orchestrates other skills:

- **Infrastructure**: Uses `helm` skill patterns for databases, caches, queues
- **Services**: Uses `deploy` skill patterns for application services
- **LLMs**: Uses `llm-deploy` skill patterns if the app includes model serving
- **Secrets**: Uses `secrets` skill to create shared credential groups
- **Workspaces**: Uses `workspaces` skill to confirm target workspace
- **Status**: Uses `applications` skill to verify deployments

## Error Handling

### Partial Deployment Failure
```
Component {name} failed to deploy. Other components are running.
Options:
1. Fix the failing component and redeploy just that one
2. Check logs: Use `logs` skill with the application ID
3. Roll back: Use `applications` skill to remove the failed component

Already deployed components are still running and don't need redeployment.
```

### Circular Dependencies
```
Detected circular dependency: Service A depends on Service B, which depends on Service A.
This needs to be resolved before deployment.
Options:
1. Make one service start without the other (add retry/fallback logic)
2. Use a message queue for async communication instead of direct HTTP
3. Merge the services if they're tightly coupled
```

### Cross-Service Connection Failed
```
Service {name} can't connect to {dependency}.
Check:
1. Is {dependency} running? Use `applications` skill to verify
2. Is the DNS correct? Should be: {name}.{namespace}.svc.cluster.local:{port}
3. Is the port correct? Check the dependency's port configuration
4. Are credentials correct? Verify env vars match the infrastructure passwords
```
