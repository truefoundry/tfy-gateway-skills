#!/usr/bin/env bash
set -e

# TrueFoundry version detection script
# Usage: tfy-version.sh [sdk|cli|python|all]
# Outputs JSON for agent parsing

COMPONENT="${1:-all}"

get_sdk_version() {
  local version
  if version=$(pip show truefoundry 2>/dev/null | grep '^Version:' | awk '{print $2}'); then
    [ -n "$version" ] && echo "{\"installed\": true, \"version\": \"$version\"}" && return
  fi
  echo '{"installed": false}'
}

get_cli_version() {
  local version
  if version=$(tfy --version 2>/dev/null); then
    version=$(echo "$version" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[a-zA-Z0-9.\-]*' | head -1)
    [ -n "$version" ] && echo "{\"installed\": true, \"version\": \"$version\"}" && return
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
      echo "{\"version\": \"$version\", \"compatible\": $compatible}"
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
    echo "{\"sdk\": $sdk, \"cli\": $cli, \"python\": $python_info}"
    ;;
  *)
    echo "Usage: tfy-version.sh [sdk|cli|python|all]" >&2
    exit 1
    ;;
esac
