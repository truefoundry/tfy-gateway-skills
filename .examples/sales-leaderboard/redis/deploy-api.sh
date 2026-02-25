#!/usr/bin/env bash
set -euo pipefail

# Deploy Redis via Helm chart on TrueFoundry
# Requires: TFY_BASE_URL, TFY_API_KEY, TFY_WORKSPACE_FQN

if [[ -z "${TFY_BASE_URL:-}" || -z "${TFY_API_KEY:-}" || -z "${TFY_WORKSPACE_FQN:-}" ]]; then
  echo "Error: TFY_BASE_URL, TFY_API_KEY, and TFY_WORKSPACE_FQN must be set"
  exit 1
fi

APP_NAME="example-redis"
REDIS_PASSWORD="${REDIS_PASSWORD:-changeme}"

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
echo "==> Deploying Redis helm chart..."

PAYLOAD=$(cat <<EOF
{
  "name": "${APP_NAME}",
  "type": "helm",
  "workspace_id": "${WORKSPACE_ID}",
  "components": [
    {
      "name": "${APP_NAME}",
      "type": "helm",
      "helm_chart": {
        "repo": "oci://registry-1.docker.io/bitnamicharts/redis",
        "version": "20.6.2"
      },
      "values": {
        "auth": {
          "enabled": true,
          "password": "${REDIS_PASSWORD}"
        },
        "master": {
          "persistence": {
            "size": "1Gi"
          },
          "resources": {
            "requests": {
              "cpu": "100m",
              "memory": "128Mi"
            },
            "limits": {
              "cpu": "250m",
              "memory": "256Mi"
            }
          }
        },
        "replica": {
          "replicaCount": 0
        }
      }
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
  echo "==> Redis deployed successfully!"
  echo "${BODY}" | python3 -m json.tool 2>/dev/null || echo "${BODY}"
else
  echo "Error: Deploy failed (HTTP ${HTTP_CODE})"
  echo "${BODY}"
  exit 1
fi
