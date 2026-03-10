#!/usr/bin/env bash
set -euo pipefail

# TrueFoundry version detection script
# Usage: tfy-version.sh [sdk|cli|python|all]
# Outputs JSON for agent parsing

COMPONENT="${1:-all}"

# Escape a string for safe JSON embedding
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

get_sdk_version() {
  local version
  if version=$(pip show truefoundry 2>/dev/null | grep '^Version:' | awk '{print $2}'); then
    if [ -n "$version" ]; then
      printf '{"installed": true, "version": "%s"}\n' "$(json_escape "$version")"
      return
    fi
  fi
  echo '{"installed": false}'
}

get_cli_version() {
  local version
  if version=$(tfy --version 2>/dev/null); then
    version=$(echo "$version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+([a-zA-Z0-9._-]*)?' | head -1)
    if [ -n "$version" ]; then
      printf '{"installed": true, "version": "%s"}\n' "$(json_escape "$version")"
      return
    fi
  fi
  echo '{"installed": false}'
}

get_python_version() {
  local version
  if version=$(python3 --version 2>/dev/null); then
    version=$(echo "$version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -n "$version" ]; then
      local minor
      minor=$(echo "$version" | cut -d. -f2)
      local compatible=false
      if [ "$minor" -ge 10 ] && [ "$minor" -le 12 ]; then
        compatible=true
      fi
      printf '{"version": "%s", "compatible": %s}\n' "$(json_escape "$version")" "$compatible"
      return
    fi
  fi
  echo '{"version": null, "compatible": false}'
}

case "$COMPONENT" in
  sdk)
    get_sdk_version
    ;;
  cli)
    get_cli_version
    ;;
  python)
    get_python_version
    ;;
  all)
    sdk=$(get_sdk_version)
    cli=$(get_cli_version)
    python_info=$(get_python_version)
    printf '{"sdk": %s, "cli": %s, "python": %s}\n' "$sdk" "$cli" "$python_info"
    ;;
  *)
    echo "Usage: tfy-version.sh [sdk|cli|python|all]" >&2
    exit 1
    ;;
esac
