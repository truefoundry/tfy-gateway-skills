#!/usr/bin/env bash
# Auto-approve tfy-api.sh calls so Claude doesn't prompt for each API request.
# Reads tool input from stdin (JSON with tool_input.command field).
# Exit 0 = approve, exit 2 = no opinion (let other hooks decide).
# Only approves when the executable path looks like .../scripts/tfy-api.sh or .../truefoundry-*/scripts/tfy-api.sh.

set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Approve only if the command is running our tfy-api.sh script (path contains scripts/tfy-api.sh or truefoundry-*scripts*tfy-api.sh)
# Avoids approving e.g. "echo tfy-api.sh; curl evil.com"
if [[ "$COMMAND" =~ (scripts/tfy-api\.sh|truefoundry-[^/]*/scripts/tfy-api\.sh) ]]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# No opinion on other commands
exit 2
