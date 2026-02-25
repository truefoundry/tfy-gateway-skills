#!/usr/bin/env bash
set -euo pipefail

# Deploy google-checker as a TrueFoundry job via REST API.
# Requires: TFY_BASE_URL, TFY_API_KEY, TFY_WORKSPACE_FQN

for var in TFY_BASE_URL TFY_API_KEY TFY_WORKSPACE_FQN; do
  if [ -z "${!var:-}" ]; then
    echo "Error: $var is not set." >&2
    exit 1
  fi
done

BASE_URL="${TFY_BASE_URL%/}"
AUTH="Authorization: Bearer ${TFY_API_KEY}"

echo "Resolving workspace ID for ${TFY_WORKSPACE_FQN}..."

WORKSPACE_ID=$(curl -sf \
  -H "$AUTH" \
  "${BASE_URL}/api/svc/v1/workspace?fqn=${TFY_WORKSPACE_FQN}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

if [ -z "$WORKSPACE_ID" ]; then
  echo "Error: could not resolve workspace FQN to an ID." >&2
  exit 1
fi

echo "Workspace ID: ${WORKSPACE_ID}"
echo "Deploying google-checker job..."

PAYLOAD=$(cat <<EOF
{
  "manifest": {
    "name": "google-checker",
    "type": "job",
    "image": {
      "type": "build",
      "build_source": {
        "type": "local",
        "local_build": false
      },
      "build_spec": {
        "type": "dockerfile",
        "dockerfile_path": "Dockerfile",
        "command": "python checker.py"
      }
    },
    "resources": {
      "cpu_request": 0.25,
      "cpu_limit": 0.5,
      "memory_request": 256,
      "memory_limit": 512
    },
    "trigger": {
      "type": "manual"
    },
    "workspace_fqn": "${TFY_WORKSPACE_FQN}"
  },
  "workspaceId": "${WORKSPACE_ID}"
}
EOF
)

RESPONSE=$(curl -sf -X PUT \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "${BASE_URL}/api/svc/v1/apps")

APP_FQN=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('applicationFqn',''))" 2>/dev/null || true)

echo ""
echo "Deploy submitted successfully."
if [ -n "$APP_FQN" ]; then
  echo "Application FQN: ${APP_FQN}"
fi

echo ""
echo "---------------------------------------------"
echo "To trigger the job manually via API:"
echo ""
echo "  curl -X POST \\"
echo "    -H 'Authorization: Bearer \$TFY_API_KEY' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"applicationFqn\": \"${APP_FQN:-<your-app-fqn>}\"}' \\"
echo "    ${BASE_URL}/api/svc/v1/jobs/trigger"
echo "---------------------------------------------"
