# docker-compose.yml Translation Reference

## Proactive Detection

**IMPORTANT:** When a user asks to deploy a project, **always check for compose files first** before asking them about architecture. Scan for:

```
docker-compose.yml
docker-compose.yaml
compose.yml
compose.yaml
docker-compose.override.yml
docker-compose.prod.yml
docker-compose.production.yml
```

If found, tell the user:

```
I found a docker-compose.yml in your project. I'll use it to understand your
service architecture and deploy each component to TrueFoundry.

Note: TrueFoundry deploys each service independently to Kubernetes rather than
using Docker Compose directly. I'll translate your compose configuration into
equivalent TrueFoundry deployments and wire everything together.

Here's what I found: ...
```

## Service Classification Algorithm

For each service in the compose file, classify it using this algorithm:

```
FOR each service in docker-compose.yml:
  IF service has `image:` field:
    Extract the image name (strip registry prefix and tag)
    IF image matches: postgres, postgresql, mysql, mariadb, mongo, mongodb
      -> CLASSIFY as "Helm Database"
    ELSE IF image matches: redis, valkey, memcached
      -> CLASSIFY as "Helm Cache"
    ELSE IF image matches: rabbitmq, nats, kafka
      -> CLASSIFY as "Helm Queue"
    ELSE IF image matches: elasticsearch, opensearch, qdrant, weaviate, milvus, chroma
      -> CLASSIFY as "Helm Search/VectorDB"
    ELSE IF image matches: vllm, tgi, triton, ollama
      -> CLASSIFY as "LLM Service"
    ELSE
      -> CLASSIFY as "Application Service" (pre-built image)
  ELSE IF service has `build:` field:
    -> CLASSIFY as "Application Service" (build from source)
  ELSE
    -> ERROR: service has neither image nor build
```

### Classification Quick Reference

| Image Pattern | Classification | TFY Deployment Type |
|--------------|----------------|---------------------|
| `postgres:*`, `postgresql:*` | Database | `type: helm` |
| `mysql:*`, `mariadb:*` | Database | `type: helm` |
| `mongo:*`, `mongodb:*` | Database | `type: helm` |
| `redis:*`, `valkey:*` | Cache | `type: helm` |
| `memcached:*` | Cache | `type: helm` |
| `rabbitmq:*` | Queue | `type: helm` |
| `elasticsearch:*` | Search | `type: helm` |
| `qdrant/qdrant:*` | VectorDB | `type: helm` (Qdrant) |
| Custom image or `build:` | Application | `type: service` |

## Step-by-Step Conversion Procedure

### Step 1: Parse and Classify All Services

Read the compose file. For each service, extract:
- Name
- Image or build context
- Ports
- Environment variables
- depends_on
- Volumes
- Health checks
- Classification (from algorithm above)

### Step 2: Choose TFY Release Names

Use a consistent naming convention: `{project}-{service}` where:
- `{project}` = user's app name (ask if unclear)
- `{service}` = short name from compose (e.g., `db`, `cache`, `backend`, `frontend`)

For Helm charts, use short names that don't repeat the chart type:
- Compose `redis` -> TFY name `{project}-cache` (NOT `{project}-redis`)
- Compose `db` or `postgres` -> TFY name `{project}-db` (NOT `{project}-postgresql`)

### Step 3: Resolve the Namespace

Get the workspace namespace for DNS construction:
```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh
$TFY_API_SH GET '/api/svc/v1/workspace?workspaceFqn=WORKSPACE_FQN'
```
The namespace is typically the workspace name from the FQN.

### Step 4: Translate Environment Variables

For each env var that references another compose service:
1. Find the compose service name in the value (e.g., `redis` in `redis://redis:6379`)
2. Look up the TFY release name you chose for that service
3. Look up the DNS pattern for that service type (see `service-wiring.md`)
4. Replace the compose hostname with the full Kubernetes DNS name

### Step 5: Generate YAML Manifests

Create one manifest file per service. See examples below.

### Step 6: Deploy in Dependency Order

Deploy leaf nodes first (infrastructure), then dependent services. See `dependency-graph.md`.

## Complete Translation Examples

### Example: Compose with backend + frontend + Redis

**Input docker-compose.yaml:**
```yaml
services:
  backend:
    build:
      context: ./backend
    ports:
      - "8000:8000"
    environment:
      REDIS_URL: redis://redis:6379
    depends_on:
      - redis

  frontend:
    build:
      context: ./frontend
    ports:
      - "3000:3000"
    environment:
      BACKEND_URL: http://backend:8000
    depends_on:
      - backend

  redis:
    image: redis:7
    ports:
      - "6379:6379"
```

**Step 1 - Classification:**
- `redis` -> image `redis:7` -> **Helm Cache**
- `backend` -> has `build:` -> **Application Service**
- `frontend` -> has `build:` -> **Application Service**

**Step 2 - TFY names** (project = `myapp`):
- `redis` -> `myapp-cache`
- `backend` -> `myapp-backend`
- `frontend` -> `myapp-frontend`

**Step 3 - Namespace:** `your-workspace` (from workspace FQN)

**Step 4 - Environment variable translation:**
- Backend `REDIS_URL: redis://redis:6379` -> `redis://myapp-cache-redis-master.your-workspace.svc.cluster.local:6379`
- Frontend `BACKEND_URL: http://backend:8000` -> `http://myapp-backend.your-workspace.svc.cluster.local:8000`

**Step 5 - Generated manifests:**

```yaml
# tfy-manifest-cache.yaml
name: myapp-cache
type: helm
source:
  type: oci-repo
  version: "20.6.2"
  oci_chart_url: oci://REGISTRY/CHART_NAME  # Search Artifact Hub for the official chart
values:
  auth:
    enabled: false
  master:
    persistence:
      enabled: true
      size: "5Gi"
    resources:
      requests:
        cpu: "0.25"
        memory: 256Mi
      limits:
        cpu: "0.5"
        memory: 512Mi
workspace_fqn: your-cluster:your-workspace
```

```yaml
# tfy-manifest-backend.yaml
name: myapp-backend
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: https://github.com/user/repo
    ref: main
    branch_name: main
  build_spec:
    type: dockerfile
    dockerfile_path: backend/Dockerfile
    build_context_path: backend/
ports:
  - port: 8000
    protocol: TCP
    expose: false
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
env:
  REDIS_URL: "redis://myapp-cache-redis-master.your-workspace.svc.cluster.local:6379"
replicas: 1
workspace_fqn: your-cluster:your-workspace
```

```yaml
# tfy-manifest-frontend.yaml
name: myapp-frontend
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: https://github.com/user/repo
    ref: main
    branch_name: main
  build_spec:
    type: dockerfile
    dockerfile_path: frontend/Dockerfile
    build_context_path: frontend/
ports:
  - port: 3000
    protocol: TCP
    expose: true
    app_protocol: http
    host: myapp-frontend-your-workspace.example.truefoundry.cloud
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
env:
  BACKEND_URL: "http://myapp-backend.your-workspace.svc.cluster.local:8000"
replicas: 1
workspace_fqn: your-cluster:your-workspace
```

**Step 6 - Deploy order:**
```
Level 0: myapp-cache (redis - no dependencies)
Level 1: myapp-backend (depends on redis)
Level 2: myapp-frontend (depends on backend)
```

```bash
tfy apply -f tfy-manifest-cache.yaml
# Wait for redis to be ready...
tfy deploy -f tfy-manifest-backend.yaml --no-wait
# Wait for backend to be ready...
tfy deploy -f tfy-manifest-frontend.yaml --no-wait
```

### Example: Compose with backend + PostgreSQL + Redis

**Input docker-compose.yaml:**
```yaml
services:
  app:
    build: .
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://postgres:DB_PASSWORD@db:5432/myapp
      REDIS_URL: redis://:REDIS_PASSWORD@redis:6379/0
    depends_on:
      - db
      - redis

  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: DB_PASSWORD
      POSTGRES_DB: myapp
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7
    command: redis-server --requirepass REDIS_PASSWORD
    volumes:
      - redisdata:/data
```

**Generated manifests:**

```yaml
# tfy-manifest-db.yaml
name: myapp-db
type: helm
source:
  type: oci-repo
  version: "16.7.21"
  oci_chart_url: oci://REGISTRY/CHART_NAME  # Search Artifact Hub for the official chart
values:
  auth:
    postgresPassword: "GENERATED_STRONG_PASSWORD"
    database: myapp
  primary:
    persistence:
      enabled: true
      size: "10Gi"
    resources:
      requests:
        cpu: "0.5"
        memory: 512Mi
      limits:
        cpu: "1"
        memory: 1Gi
workspace_fqn: your-cluster:your-workspace
```

```yaml
# tfy-manifest-cache.yaml
name: myapp-cache
type: helm
source:
  type: oci-repo
  version: "20.6.2"
  oci_chart_url: oci://REGISTRY/CHART_NAME  # Search Artifact Hub for the official chart
values:
  auth:
    password: "GENERATED_STRONG_PASSWORD"
  master:
    persistence:
      enabled: true
      size: "5Gi"
    resources:
      requests:
        cpu: "0.25"
        memory: 256Mi
      limits:
        cpu: "0.5"
        memory: 512Mi
workspace_fqn: your-cluster:your-workspace
```

```yaml
# tfy-manifest-app.yaml
name: myapp-app
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: https://github.com/user/repo
    ref: main
    branch_name: main
  build_spec:
    type: dockerfile
    dockerfile_path: Dockerfile
    build_context_path: "."
ports:
  - port: 8000
    protocol: TCP
    expose: true
    app_protocol: http
    host: myapp-app-your-workspace.example.truefoundry.cloud
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
env:
  DATABASE_URL: "postgresql://postgres:GENERATED_STRONG_PASSWORD@myapp-db-postgresql.your-workspace.svc.cluster.local:5432/myapp"
  REDIS_URL: "redis://:GENERATED_STRONG_PASSWORD@myapp-cache-redis-master.your-workspace.svc.cluster.local:6379/0"
replicas: 1
workspace_fqn: your-cluster:your-workspace
```

## Field-by-Field Translation

### Ports

```yaml
# Compose
ports:
  - "8000:8000"      # host:container
  - "3000"           # container only

# TFY manifest
ports:
  - port: 8000       # container port only (host port is irrelevant in K8s)
    protocol: TCP
    expose: false     # true if needs public URL
    app_protocol: http
```

### Health Checks

```yaml
# Compose
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s

# TFY manifest
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 10
  period_seconds: 30
  timeout_seconds: 10
  failure_threshold: 3
readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 10
  period_seconds: 30
  timeout_seconds: 10
  failure_threshold: 3
```

### Volumes

| Compose Volume | TrueFoundry Equivalent |
|---------------|----------------------|
| Named volume on DB | `persistence.enabled: true, persistence.size: "10Gi"` in Helm values |
| Named volume on app service | TrueFoundry Volume mount (use `mounts` field) |
| Bind mount (`./data:/app/data`) | Not supported directly -- use a TrueFoundry Volume or bake data into the image |
| tmpfs | `ephemeral_storage` in resources |

### Environment Variables and Secrets

```yaml
# Compose patterns:
environment:
  - API_KEY=sk-123              # Plain value -> env var
  - API_KEY                     # From host env -> ask user for value
  - API_KEY=${API_KEY}          # Variable substitution -> ask user for value

env_file:
  - .env                        # Read the file, extract vars

secrets:
  api_key:
    file: ./secrets/api_key.txt  # File-based secret -> TrueFoundry secret
```

**Translation:**
- Plain values -> `env` dict in manifest
- Host-env / substitution -> ask user, or create TrueFoundry secret
- `env_file` -> read the file, add to `env` dict (warn about sensitive values)
- Compose `secrets` -> create TrueFoundry secret group, reference as `tfy-secret://`

### Networks

```yaml
networks:
  backend:
    driver: bridge
```

**In TrueFoundry:** Networks are not needed. All services in the same workspace share a Kubernetes namespace and can reach each other via DNS. Simply ignore `networks:` config.

### depends_on

```yaml
# Compose
depends_on:
  db:
    condition: service_healthy
  redis:
    condition: service_started
```

**Translation:** `depends_on` determines deployment order only. Deploy `db` and `redis` first, wait for them to be healthy, then deploy this service. TrueFoundry does not have a native depends_on -- you handle ordering by deploying services in the correct sequence.

### Unsupported Compose Features

| Feature | Why | Workaround |
|---------|-----|------------|
| `network_mode: host` | Not supported in K8s | Use service ports |
| `privileged: true` | Security risk | Not needed for most apps |
| `pid: host` | Not supported | Redesign if required |
| `links:` | Deprecated in compose too | Use DNS (automatic) |
| `extends:` | Compose-specific | Manually merge |
| `profiles:` | Compose-specific | Deploy the services you need |
| `build.target` | Multi-stage builds | Set in Dockerfile, works with DockerFileBuild |
