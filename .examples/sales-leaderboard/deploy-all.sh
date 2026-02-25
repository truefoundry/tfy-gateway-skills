#!/usr/bin/env bash
set -euo pipefail

# Master deploy script for the Sales Leaderboard example
# Deploys: Redis -> Backend -> Frontend using tfy apply

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "  Sales Leaderboard - Full Stack Deploy"
echo "============================================"
echo ""

# Check prerequisites
if [[ -z "${TFY_WORKSPACE_FQN:-}" ]]; then
  echo "Error: TFY_WORKSPACE_FQN must be set"
  echo ""
  echo "Example:"
  echo "  export TFY_WORKSPACE_FQN=org:cluster:workspace"
  exit 1
fi

if ! command -v tfy &>/dev/null; then
  echo "Error: tfy CLI is required but not installed."
  echo "Install it with: pip install truefoundry"
  exit 1
fi

if ! command -v envsubst &>/dev/null; then
  echo "Error: envsubst is required but not installed."
  exit 1
fi

export REDIS_PASSWORD="${REDIS_PASSWORD:-changeme}"
export REDIS_HOST="${REDIS_HOST:-example-redis-master.${TFY_WORKSPACE_FQN##*:}.svc.cluster.local}"
export BACKEND_URL="${BACKEND_URL:-}"

echo "Workspace: ${TFY_WORKSPACE_FQN}"
echo ""

# Step 1: Redis
echo "--------------------------------------------"
echo "[1/3] Deploying Redis..."
echo "--------------------------------------------"
envsubst < "${SCRIPT_DIR}/redis/manifest.yaml" | tfy apply -f -
echo ""

# Step 2: Backend
echo "--------------------------------------------"
echo "[2/3] Deploying Backend..."
echo "--------------------------------------------"
envsubst < "${SCRIPT_DIR}/backend/manifest.yaml" | tfy apply -f -
echo ""

# Step 3: Frontend
echo "--------------------------------------------"
echo "[3/3] Deploying Frontend..."
echo "--------------------------------------------"
envsubst < "${SCRIPT_DIR}/frontend/manifest.yaml" | tfy apply -f -
echo ""

echo "============================================"
echo "  Deployment Complete!"
echo "============================================"
echo ""
echo "Components deployed:"
echo "  - example-redis          (Helm chart)"
echo "  - example-sales-backend  (FastAPI on port 8000)"
echo "  - example-sales-frontend (nginx on port 80)"
echo ""
echo "Note: It may take a few minutes for builds to"
echo "complete and services to become available."
