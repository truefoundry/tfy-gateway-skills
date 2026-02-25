# DAG Construction & Circular Dependency Detection

## Contents

- [Sources of Dependency Information](#sources-of-dependency-information)
- [Dependency Rules](#dependency-rules)
- [Detect Circular Dependencies](#detect-circular-dependencies)
- [Compute Deploy Order](#compute-deploy-order)
- [Poll Infrastructure Readiness](#poll-infrastructure-readiness)

## Sources of Dependency Information

### From docker-compose.yml

```yaml
services:
  backend:
    depends_on:
      - db
      - redis
    environment:
      - DATABASE_URL=postgresql://postgres:pass@db:5432/myapp  # "db" is a dependency
      - REDIS_URL=redis://redis:6379                           # "redis" is a dependency
      - FRONTEND_ORIGIN=http://frontend:3000                   # NOT a dependency (frontend depends on backend, not reverse)
```

### From environment variables

Scan env var values for references to other service names. A hostname in a connection string (`@db:5432`, `redis:6379`) implies a dependency.

### From code analysis (if no compose file)

Look at code for connection patterns:
- `DATABASE_URL`, `MONGO_URI` -> depends on database
- `REDIS_URL`, `CACHE_URL` -> depends on cache
- `BROKER_URL`, `AMQP_URL` -> depends on message queue
- `API_URL`, `BACKEND_URL` -> depends on another service

## Dependency Rules

1. **Infrastructure has no dependencies** — databases, caches, queues are leaf nodes
2. **Backend services depend on infrastructure** — and potentially on other backends
3. **Frontends depend on backends** — never on infrastructure directly
4. **Workers depend on queues + databases** — same tier as backends
5. **If A's env vars reference B's hostname -> A depends on B**
6. **`depends_on` in compose is explicit** — always respect it

## Detect Circular Dependencies

If the graph has a cycle, **stop and tell the user:**

```
Detected circular dependency: service-a -> service-b -> service-a

This cannot be deployed in sequence. Options:
1. Break the cycle by making one service start without the other (add retry logic)
2. Use async communication (message queue) instead of direct HTTP calls
3. Merge the tightly coupled services
```

## Compute Deploy Order

Topologically sort the DAG. Services with no dependencies deploy first. Services at the same level in the graph can deploy in parallel.

**Example:**
```
Graph:
  frontend -> backend
  backend  -> db, redis, worker
  worker   -> db, redis, rabbitmq
  db       -> (none)
  redis    -> (none)
  rabbitmq -> (none)

Deploy order:
  Level 0: db, redis, rabbitmq     (parallel -- no dependencies)
  Level 1: backend, worker         (parallel -- both depend only on level 0)
  Level 2: frontend                (depends on backend from level 1)
```

## Poll Infrastructure Readiness

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
