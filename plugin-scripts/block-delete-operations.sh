#!/usr/bin/env bash
# PreToolUse hook: block ALL DELETE API operations.
# This plugin must NEVER perform delete operations. Instead it instructs the
# user to delete resources manually via the TrueFoundry dashboard.
#
# Reads hook JSON from stdin (has tool_input.command).
# Exit 1 = block the command, exit 2 = no opinion (non-delete commands).

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Nothing to check if command is empty
if [[ -z "$COMMAND" ]]; then
  exit 2
fi

BLOCKED=false
RESOURCE="the resource"

# --- Pattern 1: tfy-api.sh DELETE ... ---
if [[ "$COMMAND" =~ tfy-api\.sh[[:space:]]+DELETE ]]; then
  BLOCKED=true
  # Try to extract the endpoint path for a friendlier message
  endpoint=$(echo "$COMMAND" | grep -oE 'DELETE[[:space:]]+[^[:space:]]+' | head -1 | awk '{print $2}')
  if [[ -n "$endpoint" ]]; then
    RESOURCE="$endpoint"
  fi
fi

# --- Pattern 2: curl ... -X DELETE ... or curl ... --request DELETE ... ---
if [[ "$COMMAND" =~ curl[[:space:]] ]]; then
  if [[ "$COMMAND" =~ -X[[:space:]]*DELETE ]] || [[ "$COMMAND" =~ -XDELETE ]] || [[ "$COMMAND" =~ --request[[:space:]]+DELETE ]]; then
    BLOCKED=true
    # Try to extract the URL for a friendlier message
    url=$(echo "$COMMAND" | grep -oE 'https?://[^[:space:]"'"'"']+' | head -1)
    if [[ -n "$url" ]]; then
      RESOURCE="$url"
    fi
  fi
fi

# --- Pattern 3: tfy CLI destructive commands ---
if [[ "$COMMAND" =~ (^|[[:space:];&|])(tfy[[:space:]]+(delete|destroy|remove|purge)) ]]; then
  BLOCKED=true
  # Extract the subcommand for context
  subcmd=$(echo "$COMMAND" | grep -oE 'tfy[[:space:]]+(delete|destroy|remove|purge)[^;&|]*' | head -1)
  if [[ -n "$subcmd" ]]; then
    RESOURCE="target of '$subcmd'"
  fi
fi

if [[ "$BLOCKED" == "true" ]]; then
  dashboard_url="${TFY_BASE_URL:-https://app.truefoundry.com}"
  # Use jq to safely construct JSON (avoids injection from $RESOURCE)
  if command -v jq &>/dev/null; then
    jq -n --arg res "$RESOURCE" --arg url "$dashboard_url" \
      '{"decision":"block","reason":"Delete operations are not supported via this plugin. To delete \($res), go to your TrueFoundry dashboard at \($url) and navigate to the resource you want to delete."}'
  else
    # Fallback: sanitize by removing quotes from variables
    safe_resource="${RESOURCE//\"/}"
    safe_url="${dashboard_url//\"/}"
    echo "{\"decision\":\"block\",\"reason\":\"Delete operations are not supported via this plugin. To delete ${safe_resource}, go to your TrueFoundry dashboard at ${safe_url} and navigate to the resource you want to delete.\"}"
  fi
  exit 1
fi

# No opinion on non-delete commands
exit 2
