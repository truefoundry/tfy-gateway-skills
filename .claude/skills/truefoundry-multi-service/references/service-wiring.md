# Environment Variable Translation & DNS Wiring

## Table of Contents

- [Translation Rule](#translation-rule)
- [Common Wiring Patterns](#common-wiring-patterns)
- [Internal DNS Pattern](#internal-dns-pattern)
- [Helm-Deployed Infrastructure DNS](#helm-deployed-infrastructure-dns)
- [Public URL Pattern](#public-url-pattern)
- [Secrets for Credentials](#secrets-for-credentials)

## Translation Rule

In docker-compose, services reference each other by service name:
```yaml
DATABASE_URL=postgresql://postgres:pass@db:5432/myapp
```

In TrueFoundry, replace the service name with Kubernetes DNS:
```
DATABASE_URL=postgresql://postgres:pass@APP_NAME-db-postgresql.NAMESPACE.svc.cluster.local:5432/myapp
```

## Common Wiring Patterns

| Compose Env Var | TrueFoundry Env Var |
|----------------|---------------------|
| `@db:5432` | `@{name}-db-postgresql.{ns}.svc.cluster.local:5432` |
| `@redis:6379` | `@{name}-redis-redis-master.{ns}.svc.cluster.local:6379` |
| `@rabbitmq:5672` | `@{name}-rabbitmq-rabbitmq.{ns}.svc.cluster.local:5672` |
| `@mongo:27017` | `@{name}-mongo-mongodb.{ns}.svc.cluster.local:27017` |
| `http://backend:8000` | `http://{name}-backend.{ns}.svc.cluster.local:8000` |
| `http://frontend:3000` | `https://{name}-frontend-{ws}.{base_domain}` (if public) |

## Internal DNS Pattern

All services in the same workspace share a namespace:
```
{service-name}.{namespace}.svc.cluster.local:{port}
```

## Helm-Deployed Infrastructure DNS

For Helm-deployed infrastructure, the DNS includes the chart name:
```
{release-name}-postgresql.{namespace}.svc.cluster.local:5432
{release-name}-redis-master.{namespace}.svc.cluster.local:6379
{release-name}-rabbitmq.{namespace}.svc.cluster.local:5672
```

## Public URL Pattern

1. Fetch cluster base domains: `$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID`
2. Pick wildcard domain (e.g., `*.ml.your-org.truefoundry.cloud`), strip `*.` to get base domain
3. Construct host: `{service-name}-{workspace-name}.{base_domain}`

## Secrets for Credentials

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
