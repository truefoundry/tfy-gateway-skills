#!/usr/bin/env bash
# SessionStart hook: verify TrueFoundry credentials and auto-install CLI.
# Runs at the beginning of every Claude Code session.
# Outputs status that feeds back into the conversation context.

set -euo pipefail

# --- Load .env if present (same safe parser as tfy-api.sh) ---
if [[ -f ".env" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    line="${line#export }"
    if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      key="${line%%=*}"
      value="${line#*=}"
      # Only strip matching outer quotes (avoid over-stripping mixed quotes)
      if [[ "$value" =~ ^\".*\"$ ]]; then
        value="${value#\"}" && value="${value%\"}"
      elif [[ "$value" =~ ^\'.*\'$ ]]; then
        value="${value#\'}" && value="${value%\'}"
      fi
      export "$key=$value"
    fi
  done < .env
fi

# Bridge Claude plugin userConfig values (exported as CLAUDE_PLUGIN_OPTION_<KEY>)
# so scripts work whether credentials come from .env, env vars, or plugin userConfig.
TFY_BASE_URL="${TFY_BASE_URL:-${CLAUDE_PLUGIN_OPTION_TFY_BASE_URL:-}}"
TFY_API_KEY="${TFY_API_KEY:-${CLAUDE_PLUGIN_OPTION_TFY_API_KEY:-}}"

# Resolve aliases
TFY_BASE_URL="${TFY_BASE_URL:-${TFY_HOST:-${TFY_API_HOST:-}}}"

# --- Credential check ---
cred_status="ok"
cred_messages=()

if [[ -z "${TFY_BASE_URL:-}" ]]; then
  cred_status="missing"
  cred_messages+=("TFY_BASE_URL is not set. Export it or add to .env")
fi

if [[ -z "${TFY_API_KEY:-}" ]]; then
  cred_status="missing"
  cred_messages+=("TFY_API_KEY is not set. Export it or add to .env")
fi

# --- CLI check & auto-install ---
cli_version=""
cli_status="missing"
cli_messages=()
MIN_CLI_VERSION="0.5.0"
TARGET_CLI_VERSION="0.5.0"

# Helper: compare semver strings (returns 0 if $1 < $2)
version_lt() {
  local IFS=.
  # shellcheck disable=SC2206
  local i a=($1) b=($2)
  for ((i = 0; i < ${#b[@]}; i++)); do
    local av="${a[i]:-0}" bv="${b[i]:-0}"
    if ((av < bv)); then return 0; fi
    if ((av > bv)); then return 1; fi
  done
  return 1
}

# Helper: extract version number from tfy --version output
extract_version() {
  local ver_str="$1"
  echo "$ver_str" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

install_tfy_cli() {
  install_ok=false

  PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "unknown")
  PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
  PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)

  has_uv=false
  has_pip=false
  command -v uv &>/dev/null && has_uv=true
  python3 -m pip --version &>/dev/null 2>&1 && has_pip=true

  if $has_uv; then
    if uv tool install --python 3.12 "truefoundry==${TARGET_CLI_VERSION}" 2>/dev/null; then
      install_ok=true
    fi
  elif [[ "$PY_VERSION" = "unknown" ]]; then
    cli_messages+=("No python3 found. Install Python 3.9+ or uv (https://docs.astral.sh/uv/)")
  elif [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -lt 9 ]]; then
    cli_messages+=("Python ${PY_VERSION} is not supported. TrueFoundry CLI requires Python 3.9+")
  elif ! $has_pip; then
    cli_messages+=("No Python package manager found. Install pip or uv (https://docs.astral.sh/uv/)")
  elif [[ "$PY_MAJOR" -eq 3 && "$PY_MINOR" -ge 14 ]]; then
    if python3 -m pip install --quiet "truefoundry==${TARGET_CLI_VERSION}" "pydantic>=2.13.0b1" 2>/dev/null; then
      install_ok=true
    else
      cli_messages+=("Python ${PY_VERSION} install failed. Python 3.14+ requires pydantic beta which may not be available yet. Try: uv tool install --python 3.12 truefoundry==${TARGET_CLI_VERSION}")
    fi
  else
    if python3 -m pip install --quiet "truefoundry==${TARGET_CLI_VERSION}" 2>/dev/null; then
      install_ok=true
    fi
  fi
}

if tfy_ver=$(tfy --version 2>/dev/null); then
  cli_version="$tfy_ver"
  cli_status="ok"

  parsed_ver=$(extract_version "$tfy_ver")
  if [[ -n "$parsed_ver" ]] && version_lt "$parsed_ver" "$MIN_CLI_VERSION"; then
    cli_messages+=("CLI version ${parsed_ver} is outdated (minimum: ${MIN_CLI_VERSION}). Upgrading...")
    cli_status="upgrading"
    install_tfy_cli
    if $install_ok && tfy_ver=$(tfy --version 2>/dev/null); then
      cli_version="$tfy_ver"
      cli_status="upgraded"
      cli_messages+=("Upgraded to ${cli_version}")
    else
      cli_status="outdated"
      cli_messages+=("Auto-upgrade failed. Please run: pip install --upgrade truefoundry==${TARGET_CLI_VERSION}")
    fi
  fi
else
  cli_status="installing"
  install_tfy_cli

  if $install_ok && tfy_ver=$(tfy --version 2>/dev/null); then
    cli_version="$tfy_ver"
    cli_status="installed"
  else
    cli_status="unavailable"
  fi
fi

# --- Connection test (only if credentials are present) ---
conn_status="skipped"
conn_messages=()
workspace_count=0
workspace_names=()

if [[ "$cred_status" = "ok" ]]; then
  BASE="${TFY_BASE_URL%/}"
  response_file=$(mktemp)
  http_code=$(curl -s -o "$response_file" -w '%{http_code}' \
    --connect-timeout 5 --max-time 10 \
    -H "Authorization: Bearer ${TFY_API_KEY}" \
    "${BASE}/api/svc/v1/workspaces" 2>/dev/null || echo "000")

  if [[ "$http_code" =~ ^2 ]]; then
    conn_status="connected"

    if command -v python3 &>/dev/null; then
      workspace_info=$(python3 -c "
import json, sys
try:
    data = json.load(open('$response_file'))
    workspaces = data if isinstance(data, list) else data.get('workspaces', data.get('data', []))
    names = [w.get('name', w.get('fqn', 'unnamed')) for w in workspaces if isinstance(w, dict)]
    print(len(names))
    for n in names:
        print(n)
except Exception:
    print('0')
" 2>/dev/null || echo "0")

      workspace_count=$(echo "$workspace_info" | head -1)
      if [[ "$workspace_count" -gt 0 ]] 2>/dev/null; then
        while IFS= read -r ws_name; do
          workspace_names+=("$ws_name")
        done < <(echo "$workspace_info" | tail -n +2)
      fi

      if [[ "$workspace_count" -eq 0 ]]; then
        conn_messages+=("WARNING: API key has access to zero workspaces. The key may have insufficient permissions.")
      fi
    fi
  elif [[ "$http_code" = "401" || "$http_code" = "403" ]]; then
    conn_status="auth_failed"
    conn_messages+=("API key is invalid, expired, or has insufficient permissions")
  elif [[ "$http_code" = "404" ]]; then
    conn_status="endpoint_not_found"
    conn_messages+=("TFY_BASE_URL may be incorrect - the API endpoint was not found at ${BASE}/api/svc/v1/workspaces")
  elif [[ "$http_code" =~ ^5 ]]; then
    conn_status="server_error"
    conn_messages+=("TrueFoundry server error (HTTP ${http_code}) - the platform may be experiencing issues")
  elif [[ "$http_code" = "000" ]]; then
    conn_status="unreachable"
    conn_messages+=("Cannot reach TrueFoundry at ${BASE} - check network/VPN")
  else
    conn_status="unreachable"
    conn_messages+=("Unexpected HTTP ${http_code} from TrueFoundry at ${BASE}")
  fi

  rm -f "$response_file"
fi

# --- Output summary ---
echo "TrueFoundry environment check:"
echo "  Credentials: $cred_status"
for msg in "${cred_messages[@]+"${cred_messages[@]}"}"; do
  echo "    - $msg"
done
echo "  CLI: $cli_status${cli_version:+ ($cli_version)}"
for msg in "${cli_messages[@]+"${cli_messages[@]}"}"; do
  echo "    - $msg"
done
echo "  Connection: $conn_status"
for msg in "${conn_messages[@]+"${conn_messages[@]}"}"; do
  echo "    - $msg"
done

if [[ "$conn_status" = "connected" ]]; then
  echo "  Workspaces accessible: $workspace_count"
  if [[ ${#workspace_names[@]} -gt 0 ]]; then
    for ws in "${workspace_names[@]}"; do
      echo "    - $ws"
    done
  fi
fi

if [[ "$cred_status" != "ok" ]]; then
  echo ""
  echo "Set credentials before configuring the gateway:"
  echo "  export TFY_BASE_URL=https://your-org.truefoundry.cloud"
  echo "  export TFY_API_KEY=your-api-key"
  echo "Or add them to a .env file in your project directory."
fi

if [[ "$conn_status" = "auth_failed" ]]; then
  echo ""
  echo "API key is invalid, expired, or has insufficient permissions. Generate a new one at:"
  echo "  ${TFY_BASE_URL%/}/settings"
fi

if [[ "$conn_status" = "endpoint_not_found" ]]; then
  echo ""
  echo "Verify TFY_BASE_URL is correct (e.g., https://your-org.truefoundry.cloud)"
fi
