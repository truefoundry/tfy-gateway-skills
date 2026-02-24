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

## Service-Level Translation

### Application Service (has `build:`)
```yaml
# docker-compose.yml
services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://postgres:pass@db:5432/myapp
      REDIS_URL: redis://redis:6379/0
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Translates to TrueFoundry Service:**
- `build.context` -> Use `deploy` skill with `DockerFileBuild(dockerfile_path="./backend/Dockerfile", build_context_path="./backend")`
- `ports: "8000:8000"` -> `Port(port=8000, protocol="TCP")`
- `environment` -> `env` dict with DNS-rewritten hostnames
- `depends_on` -> deploy order (db and redis first)
- `healthcheck` -> TrueFoundry health probes:
  ```json
  {
    "liveness_probe": {
      "path": "/health",
      "port": 8000,
      "period_seconds": 30,
      "timeout_seconds": 10,
      "failure_threshold": 3
    }
  }
  ```

### Application Service (has `image:` with custom image)
```yaml
services:
  api:
    image: ghcr.io/myorg/api:v1.2.0
    ports:
      - "8080:8080"
```

**Translates to TrueFoundry Service with pre-built image:**
```json
{
  "kind": "Service",
  "name": "api",
  "image": { "type": "image", "image_uri": "ghcr.io/myorg/api:v1.2.0" },
  "ports": [{ "port": 8080, "protocol": "TCP" }]
}
```

### Database/Cache/Queue (well-known images)

| Compose Image | TrueFoundry Deployment | Chart |
|--------------|----------------------|-------|
| `postgres:*` | Helm: `bitnami/postgresql` | Map `POSTGRES_PASSWORD` -> `auth.postgresPassword`, `POSTGRES_DB` -> `auth.database`, `POSTGRES_USER` -> `auth.username` |
| `mysql:*` / `mariadb:*` | Helm: `bitnami/mysql` or `bitnami/mariadb` | Map `MYSQL_ROOT_PASSWORD` -> `auth.rootPassword`, `MYSQL_DATABASE` -> `auth.database` |
| `mongo:*` | Helm: `bitnami/mongodb` | Map `MONGO_INITDB_ROOT_USERNAME` -> `auth.rootUser`, `MONGO_INITDB_ROOT_PASSWORD` -> `auth.rootPassword` |
| `redis:*` / `valkey:*` | Helm: `bitnami/redis` | Map password if set, default `architecture: standalone` |
| `rabbitmq:*` | Helm: `bitnami/rabbitmq` | Map `RABBITMQ_DEFAULT_USER` -> `auth.username`, `RABBITMQ_DEFAULT_PASS` -> `auth.password` |
| `elasticsearch:*` | Helm: `bitnami/elasticsearch` | Map `ELASTIC_PASSWORD` -> `security.elasticPassword` |

### Volumes

| Compose Volume | TrueFoundry Equivalent |
|---------------|----------------------|
| Named volume on DB | `persistence.enabled: true, persistence.size: "10Gi"` in Helm values |
| Named volume on app service | TrueFoundry Volume (use `volumes` skill) |
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
  frontend:
    driver: bridge
```

**In TrueFoundry:** Networks are not needed. All services in the same workspace share a Kubernetes namespace and can reach each other via DNS. Simply ignore `networks:` config.

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
