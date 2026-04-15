#!/usr/bin/env bash
# PreToolUse hook for Bash: scans commands for hardcoded secrets/credentials.
# Blocks execution if a likely API key or token is found inline.
#
# Exit 0 = approve (no secrets detected).
# Exit 2 = no opinion (not a command we care about).
# Non-zero (1) with message = block with reason.

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [[ -z "$COMMAND" ]]; then
  exit 2
fi

# Skip simple read-only commands unless they chain into API calls
if [[ "$COMMAND" =~ ^[[:space:]]*(ls|cat|head|tail|grep|find|echo|pwd|cd|which|tfy[[:space:]]--version) ]]; then
  if ! echo "$COMMAND" | grep -qE '(tfy-api\.sh|/api/svc/v1/|/api/gateway/v1/)'; then
    exit 2
  fi
fi

# --- Pattern matching for likely hardcoded secrets ---
blocked=false
reason=""

# TrueFoundry API keys (tfy-* pattern, typically 40+ chars)
if echo "$COMMAND" | grep -qE '(TFY_API_KEY|api.key|api_key)[[:space:]]*[=:][[:space:]]*["'"'"']?tfy-[A-Za-z0-9]{20,}'; then
  blocked=true
  reason="Hardcoded TFY_API_KEY detected. Use environment variable or .env file instead."
fi

# Generic long tokens in config YAML/JSON (env var values that look like secrets)
if echo "$COMMAND" | grep -qE 'value:[[:space:]]*["'"'"'][A-Za-z0-9+/=_-]{40,}["'"'"']'; then
  if echo "$COMMAND" | grep -qE '(tfy-api\.sh|/api/svc/v1/|/api/gateway/v1/)'; then
    blocked=true
    reason="Hardcoded secret value detected in API call. Use tfy-secret:// references instead. See the secrets skill for how to create and reference secrets."
  fi
fi

# AWS/GCP/Azure credential patterns
if echo "$COMMAND" | grep -qE '(AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35})'; then
  blocked=true
  reason="Cloud provider credential detected in command. Store in TrueFoundry secrets and use tfy-secret:// references."
fi

if $blocked; then
  echo "$reason"
  exit 1
fi

# No secrets detected — defer to other hooks (exit 2 = no opinion)
exit 2
