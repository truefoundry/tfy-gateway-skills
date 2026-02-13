#!/usr/bin/env bash
# TrueFoundry API helper — authenticated curl for TFY REST API.
# Usage: tfy-api.sh <METHOD> <PATH> [JSON_BODY]
#
# Examples:
#   tfy-api.sh GET /api/svc/v1/workspaces
#   tfy-api.sh GET '/api/svc/v1/apps?workspaceFqn=my-ws'
#   tfy-api.sh POST /api/svc/v1/secret-groups '{"name":"my-group"}'
#   tfy-api.sh PUT  /api/svc/v1/apps '{"manifest":{...}}'
#
# Reads TFY_BASE_URL and TFY_API_KEY from env, or from .env in current dir.

set -e

# Load .env if present
if [[ -f ".env" ]]; then
  set -a; source .env; set +a
fi

if [[ -z "$TFY_BASE_URL" ]]; then
  echo '{"error": "TFY_BASE_URL not set. Export it or add to .env"}' >&2
  exit 1
fi

if [[ -z "$TFY_API_KEY" ]]; then
  echo '{"error": "TFY_API_KEY not set. Export it or add to .env"}' >&2
  exit 1
fi

METHOD="${1:?Usage: tfy-api.sh METHOD PATH [JSON_BODY]}"
API_PATH="${2:?Usage: tfy-api.sh METHOD PATH [JSON_BODY]}"
JSON_BODY="$3"

# Validate method and path
case "$METHOD" in
  GET|POST|PUT|PATCH|DELETE) ;;
  *) echo '{"error": "METHOD must be GET, POST, PUT, PATCH, or DELETE"}' >&2; exit 1 ;;
esac
[[ "$API_PATH" != /* ]] && echo '{"error": "API_PATH must start with /"}' >&2 && exit 1

BASE="${TFY_BASE_URL%/}"

if [[ -n "$JSON_BODY" ]]; then
  curl -s -X "$METHOD" "${BASE}${API_PATH}" \
    -H "Authorization: Bearer ${TFY_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY"
else
  curl -s -X "$METHOD" "${BASE}${API_PATH}" \
    -H "Authorization: Bearer ${TFY_API_KEY}" \
    -H "Content-Type: application/json"
fi
