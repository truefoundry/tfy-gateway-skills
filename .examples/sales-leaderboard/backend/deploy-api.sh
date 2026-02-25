#!/usr/bin/env bash
set -euo pipefail

# Deploy the FastAPI backend service to TrueFoundry
# Requires: TFY_BASE_URL, TFY_API_KEY, TFY_WORKSPACE_FQN

if [[ -z "${TFY_BASE_URL:-}" || -z "${TFY_API_KEY:-}" || -z "${TFY_WORKSPACE_FQN:-}" ]]; then
  echo "Error: TFY_BASE_URL, TFY_API_KEY, and TFY_WORKSPACE_FQN must be set"
  exit 1
fi

APP_NAME="example-sales-backend"
REDIS_PASSWORD="${REDIS_PASSWORD:-changeme}"
REDIS_HOST="${REDIS_HOST:-example-redis-master.${TFY_WORKSPACE_FQN##*:}.svc.cluster.local}"

echo "==> Resolving workspace ID for ${TFY_WORKSPACE_FQN}..."
WORKSPACE_ID=$(curl -s -H "Authorization: Bearer ${TFY_API_KEY}" \
  "${TFY_BASE_URL}/api/svc/v1/workspace?name=${TFY_WORKSPACE_FQN}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
ws = data if isinstance(data, dict) and 'id' in data else (data[0] if isinstance(data, list) and data else None)
if ws: print(ws['id'])
else: sys.exit(1)
")

echo "==> Workspace ID: ${WORKSPACE_ID}"
echo "==> Deploying ${APP_NAME}..."

PAYLOAD=$(cat <<EOF
{
  "name": "${APP_NAME}",
  "type": "service",
  "workspace_id": "${WORKSPACE_ID}",
  "components": [
    {
      "name": "${APP_NAME}",
      "type": "service",
      "image": {
        "type": "build",
        "build_source": {
          "type": "local",
          "local_path": "$(pwd)"
        },
        "build_spec": {
          "type": "dockerfile",
          "dockerfile_path": "Dockerfile",
          "build_context_path": "."
        }
      },
      "ports": [
        {
          "port": 8000,
          "protocol": "TCP",
          "expose": true
        }
      ],
      "env": {
        "REDIS_HOST": "${REDIS_HOST}",
        "REDIS_PASSWORD": "${REDIS_PASSWORD}",
        "REDIS_PORT": "6379"
      },
      "resources": {
        "cpu_request": 0.2,
        "cpu_limit": 0.5,
        "memory_request": 256,
        "memory_limit": 512
      },
      "replicas": 1
    }
  ]
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
  -H "Authorization: Bearer ${TFY_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" \
  "${TFY_BASE_URL}/api/svc/v1/apps")

HTTP_CODE=$(echo "${RESPONSE}" | tail -1)
BODY=$(echo "${RESPONSE}" | sed '$d')

if [[ "${HTTP_CODE}" =~ ^2 ]]; then
  echo "==> Backend deployed successfully!"
  echo "${BODY}" | python3 -m json.tool 2>/dev/null || echo "${BODY}"
else
  echo "Error: Deploy failed (HTTP ${HTTP_CODE})"
  echo "${BODY}"
  exit 1
fi
