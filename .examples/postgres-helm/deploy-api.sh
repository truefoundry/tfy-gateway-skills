#!/usr/bin/env bash
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
APP_NAME="example-postgres"
CHART_VERSION="16.4.3"
OCI_CHART_URL="oci://registry-1.docker.io/bitnamicharts/postgresql"

# ── Load .env if present ──────────────────────────────────────────────────────
if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

# ── Validate required env vars ────────────────────────────────────────────────
missing=()
[[ -z "${TFY_BASE_URL:-}" ]] && missing+=("TFY_BASE_URL")
[[ -z "${TFY_API_KEY:-}" ]] && missing+=("TFY_API_KEY")
[[ -z "${TFY_WORKSPACE_FQN:-}" ]] && missing+=("TFY_WORKSPACE_FQN")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Error: missing required environment variables: ${missing[*]}" >&2
  echo "Set them or add a .env file. See README.md for details." >&2
  exit 1
fi

BASE_URL="${TFY_BASE_URL%/}"

# ── Resolve workspace ID from FQN ────────────────────────────────────────────
echo "Resolving workspace FQN: ${TFY_WORKSPACE_FQN}"

workspace_response=$(curl -sf \
  -H "Authorization: Bearer ${TFY_API_KEY}" \
  "${BASE_URL}/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}")

workspace_id=$(echo "${workspace_response}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ws = data[0] if isinstance(data, list) else data
print(ws['id'])
" 2>/dev/null) || {
  echo "Error: could not resolve workspace ID for FQN '${TFY_WORKSPACE_FQN}'." >&2
  echo "Response: ${workspace_response}" >&2
  exit 1
}

echo "Workspace ID: ${workspace_id}"

# ── Deploy PostgreSQL Helm chart ──────────────────────────────────────────────
echo "Deploying ${APP_NAME} (chart ${CHART_VERSION})..."

deploy_payload=$(cat <<EOF
{
  "manifest": {
    "name": "${APP_NAME}",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "${CHART_VERSION}",
      "oci_chart_url": "${OCI_CHART_URL}"
    },
    "values": {
      "auth": {
        "postgresPassword": "example-password-change-me",
        "database": "salesdb"
      },
      "primary": {
        "persistence": {
          "size": "10Gi"
        }
      }
    },
    "workspace_fqn": "${TFY_WORKSPACE_FQN}"
  },
  "workspaceId": "${workspace_id}"
}
EOF
)

deploy_response=$(curl -sf \
  -X PUT \
  -H "Authorization: Bearer ${TFY_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${deploy_payload}" \
  "${BASE_URL}/api/svc/v1/apps")

echo "Deployment submitted."
echo "${deploy_response}" | python3 -m json.tool 2>/dev/null || echo "${deploy_response}"

# ── Print connection details ──────────────────────────────────────────────────
# Extract namespace from workspace FQN (last segment)
namespace=$(echo "${TFY_WORKSPACE_FQN}" | awk -F: '{print $NF}')

cat <<INFO

────────────────────────────────────────────────
  PostgreSQL Connection Details
────────────────────────────────────────────────
  Host : ${APP_NAME}-postgresql.${namespace}.svc.cluster.local
  Port : 5432
  User : postgres
  Pass : example-password-change-me
  DB   : salesdb

  DSN  : postgresql://postgres:example-password-change-me@${APP_NAME}-postgresql.${namespace}.svc.cluster.local:5432/salesdb
────────────────────────────────────────────────
INFO
