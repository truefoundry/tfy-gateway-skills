#!/bin/bash
set -euo pipefail

# Deploy PostgreSQL via tfy CLI
# Requires: TFY_WORKSPACE_FQN environment variable

if [[ -z "${TFY_WORKSPACE_FQN:-}" ]]; then
  echo "Error: TFY_WORKSPACE_FQN must be set" >&2
  echo "Example: export TFY_WORKSPACE_FQN=tfy-org:cluster:workspace" >&2
  exit 1
fi

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

# Print connection details
namespace=$(echo "${TFY_WORKSPACE_FQN}" | awk -F: '{print $NF}')

cat <<INFO

────────────────────────────────────────────────
  PostgreSQL Connection Details
────────────────────────────────────────────────
  Host : example-postgres-postgresql.${namespace}.svc.cluster.local
  Port : 5432
  User : postgres
  Pass : example-password-change-me
  DB   : salesdb

  DSN  : postgresql://postgres:example-password-change-me@example-postgres-postgresql.${namespace}.svc.cluster.local:5432/salesdb
────────────────────────────────────────────────
INFO
