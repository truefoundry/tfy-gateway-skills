#!/usr/bin/env bash
# Auto-approve tfy-api.sh calls so Claude doesn't prompt for each API request.
# Reads tool input from stdin (JSON with tool_input.command field).
# Exit 0 = approve, exit 2 = no opinion (let other hooks decide).
# Only approves when the executable path looks like .../scripts/tfy-(api|version).sh or .../truefoundry-*/scripts/tfy-(api|version).sh.

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Approve only if the command is a tfy-api.sh or tfy-version.sh call with no shell metacharacters.
# Rejects command chaining (;, &&, ||, |) and subshells ($(), ``) to prevent injection.
# Regex stored in variables so shellcheck doesn't try to parse them (SC1073).
# shellcheck disable=SC2016
_SAFE_ARGS='[^;&|$()'\''`]*'
_RE_DIRECT="^[[:space:]]*(bash[[:space:]]+)?(\\.?\\.?/?)*scripts/tfy-(api|version)\\.sh([[:space:]]+${_SAFE_ARGS})?$"
_RE_INSTALLED="^[[:space:]]*(bash[[:space:]]+)?(\\.?\\.?/?)*truefoundry-[^/]*/scripts/tfy-(api|version)\\.sh([[:space:]]+${_SAFE_ARGS})?$"
if [[ "$COMMAND" =~ $_RE_DIRECT ]] || [[ "$COMMAND" =~ $_RE_INSTALLED ]]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# No opinion on other commands
exit 2
