#!/bin/bash
set -euo pipefail

# Deploy the FastAPI backend via tfy CLI
# Requires: TFY_WORKSPACE_FQN environment variable

if [[ -z "${TFY_WORKSPACE_FQN:-}" ]]; then
  echo "Error: TFY_WORKSPACE_FQN must be set" >&2
  exit 1
fi

export REDIS_PASSWORD="${REDIS_PASSWORD:-changeme}"
export REDIS_HOST="${REDIS_HOST:-example-redis-master.${TFY_WORKSPACE_FQN##*:}.svc.cluster.local}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST=$(envsubst < "${SCRIPT_DIR}/manifest.yaml")

# Preview
echo "=== Preview ==="
echo "${MANIFEST}" | tfy apply -f - --dry-run --show-diff
echo ""
read -p "Apply? (y/n) " -n 1 -r
echo ""
[[ $REPLY =~ ^[Yy]$ ]] || exit 0

# Apply
echo "${MANIFEST}" | tfy apply -f -
echo "==> Backend deployed successfully!"
