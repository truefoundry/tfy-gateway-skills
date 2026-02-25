# Google Checker Job

A TrueFoundry job that checks the availability of google.com and reports status, response time, and content length.

## What This Does

Deploys a one-off job to TrueFoundry that sends an HTTP GET to `https://www.google.com`, measures the response, and prints a status report. The job exits with code 0 on success and 1 on failure, making it easy to monitor via job run history.

## Prerequisites

- The `tfy` CLI installed and logged in (`pip install truefoundry && tfy login`)
- `envsubst` available (included in most systems via `gettext`)
- `TFY_WORKSPACE_FQN` environment variable set

## Deploy (CLI)

```bash
export TFY_WORKSPACE_FQN="tfy-org:cluster:workspace"

./deploy.sh
```

The script previews the manifest with `--dry-run`, asks for confirmation, then applies it.

To apply directly without the interactive wrapper:

```bash
export TFY_WORKSPACE_FQN="tfy-org:cluster:workspace"
envsubst < manifest.yaml | tfy apply -f -
```

## API Fallback

If the `tfy` CLI is not available, use the REST API approach:

```bash
export TFY_BASE_URL="https://your-org.truefoundry.cloud"
export TFY_API_KEY="tfy-..."
export TFY_WORKSPACE_FQN="tfy-org:cluster:workspace"

./deploy-api.sh
```

## Trigger the Job

### Via CLI

```bash
tfy jobs trigger --name google-checker --workspace $TFY_WORKSPACE_FQN
```

### Via API

```bash
curl -X POST \
  -H "Authorization: Bearer $TFY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"applicationFqn": "<your-app-fqn>"}' \
  "${TFY_BASE_URL}/api/svc/v1/jobs/trigger"
```

The application FQN is printed by `deploy-api.sh` after a successful deploy.

### Via Dashboard

1. Open the TrueFoundry dashboard
2. Navigate to your workspace
3. Find the **google-checker** job
4. Click **Trigger** to start a run

## Check Results

View job run logs through the dashboard or via the TrueFoundry logs API:

```bash
curl -H "Authorization: Bearer $TFY_API_KEY" \
  "${TFY_BASE_URL}/api/svc/v1/logs?applicationFqn=<your-app-fqn>"
```

## Add a Cron Schedule

To run the checker on a schedule, change the `trigger` section in `manifest.yaml`:

```yaml
trigger:
  type: cron
  expression: "0 */6 * * *"
```

This example runs the job every 6 hours. Redeploy with `./deploy.sh` after making the change.
