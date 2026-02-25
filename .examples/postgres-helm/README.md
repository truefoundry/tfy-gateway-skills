# Deploy PostgreSQL via Helm on TrueFoundry

This example deploys a PostgreSQL 16 instance on TrueFoundry using the Bitnami Helm chart (`bitnami/postgresql` v16.4.3).

## Prerequisites

- The `tfy` CLI installed and logged in (`pip install truefoundry && tfy login`)
- `envsubst` available (included in most systems via `gettext`)
- `TFY_WORKSPACE_FQN` environment variable set

## Usage (CLI)

```bash
export TFY_WORKSPACE_FQN="tfy-org:cluster:workspace"

./deploy.sh
```

The script previews the manifest with `--dry-run`, asks for confirmation, then applies it. Connection details are printed after deployment.

To apply directly without the interactive wrapper:

```bash
export TFY_WORKSPACE_FQN="tfy-org:cluster:workspace"
envsubst < manifest.yaml | tfy apply -f -
```

## API Fallback

If the `tfy` CLI is not available, use the REST API approach:

```bash
export TFY_BASE_URL="https://app.truefoundry.com"
export TFY_API_KEY="your-api-key"
export TFY_WORKSPACE_FQN="tfy-org:cluster:workspace"

./deploy-api.sh
```

## Connecting from other services

Once deployed, PostgreSQL is available inside the cluster at:

```
example-postgres-postgresql.<namespace>.svc.cluster.local:5432
```

Default credentials:

- **User:** `postgres`
- **Password:** `example-password-change-me`
- **Database:** `salesdb`
- **Port:** `5432`

The namespace is derived from your workspace. The script prints the exact DNS name after deployment.

## Customization

Edit `manifest.yaml` to change:

| Setting | Location in manifest | Default |
|---|---|---|
| Application name | `name` | `example-postgres` |
| Chart version | `source.version` | `16.4.3` |
| Postgres password | `values.auth.postgresPassword` | `example-password-change-me` |
| Database name | `values.auth.database` | `salesdb` |
| Storage size | `values.primary.persistence.size` | `10Gi` |

For production use, replace the password with a strong secret or use TrueFoundry secret groups.
