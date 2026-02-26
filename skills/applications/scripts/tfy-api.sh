#!/usr/bin/env bash
# TrueFoundry API helper — authenticated curl for TFY REST API.
# Usage: tfy-api.sh <METHOD> <PATH> [JSON_BODY]
#
# Examples:
#   tfy-api.sh GET /api/svc/v1/workspaces
#   tfy-api.sh GET '/api/svc/v1/apps?workspaceFqn=my-workspace'
#   tfy-api.sh POST /api/svc/v1/secret-groups '{"name":"my-group"}'
#   tfy-api.sh PUT  /api/svc/v1/apps '{"manifest":{...}}'
#
# Reads TFY_BASE_URL and TFY_API_KEY from env, or from .env in current dir.

set -euo pipefail

# Load .env if present (safe line-by-line parser — never `source` .env)
if [[ -f ".env" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Strip optional 'export ' prefix
    line="${line#export }"
    # Only process lines matching KEY=VALUE (alphanumeric/underscore keys only)
    if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      key="${line%%=*}"
      value="${line#*=}"
      # Strip surrounding quotes if present
      value="${value#\"}" && value="${value%\"}"
      value="${value#\'}" && value="${value%\'}"
      export "$key=$value"
    fi
  done < .env
fi

# Resolve common aliases (TFY_HOST used by CLI, TFY_API_HOST used by some .env files)
TFY_BASE_URL="${TFY_BASE_URL:-${TFY_HOST:-${TFY_API_HOST:-}}}"

if [[ -z "${TFY_BASE_URL:-}" ]]; then
  echo '{"error": "TFY_BASE_URL not set. Export it or add to .env"}' >&2
  exit 1
fi

if [[ -z "${TFY_API_KEY:-}" ]]; then
  echo '{"error": "TFY_API_KEY not set. Export it or add to .env"}' >&2
  exit 1
fi

METHOD="${1:?Usage: tfy-api.sh METHOD PATH [JSON_BODY]}"
API_PATH="${2:?Usage: tfy-api.sh METHOD PATH [JSON_BODY]}"
JSON_BODY="${3-}"

# Validate method and path
case "$METHOD" in
  GET|POST|PUT|PATCH|DELETE) ;;
  *)
    echo '{"error": "METHOD must be GET, POST, PUT, PATCH, or DELETE"}' >&2
    exit 1
    ;;
esac

if [[ "$API_PATH" != /* ]]; then
  echo '{"error": "API_PATH must start with /"}' >&2
  exit 1
fi

BASE="${TFY_BASE_URL%/}"
CONNECT_TIMEOUT="${TFY_API_CONNECT_TIMEOUT:-10}"
MAX_TIME="${TFY_API_MAX_TIME:-60}"
RETRY_COUNT="${TFY_API_RETRY:-2}"

# --fail-with-body is preferred to preserve JSON error payloads while still
# exiting non-zero on HTTP 4xx/5xx. Fall back to --fail on older curl versions.
CURL_FAIL_FLAG="--fail"
if curl --help all 2>/dev/null | grep -q -- '--fail-with-body'; then
  CURL_FAIL_FLAG="--fail-with-body"
fi

CURL_ARGS=(
  --silent
  --show-error
  "$CURL_FAIL_FLAG"
  --connect-timeout "$CONNECT_TIMEOUT"
  --max-time "$MAX_TIME"
  --retry "$RETRY_COUNT"
  --retry-delay 1
  --retry-connrefused
  -X "$METHOD"
  "${BASE}${API_PATH}"
  -H "Authorization: Bearer ${TFY_API_KEY}"
  -H "Content-Type: application/json"
)

if [[ -n "$JSON_BODY" ]]; then
  CURL_ARGS+=( -d "$JSON_BODY" )
fi

curl "${CURL_ARGS[@]}"
