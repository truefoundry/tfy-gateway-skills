#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

mode="all"
if [[ "${1:-}" == "--changed" ]]; then
  mode="changed"
fi

declare -a files=()

collect_all_files() {
  while IFS= read -r file; do
    files+=("$file")
  done < <(find "$REPO_ROOT/skills" -type f -name '*.md' | sort)
}

collect_changed_files() {
  local base_ref

  if git -C "$REPO_ROOT" rev-parse --verify origin/main >/dev/null 2>&1; then
    base_ref="origin/main...HEAD"
  elif git -C "$REPO_ROOT" rev-parse --verify HEAD~1 >/dev/null 2>&1; then
    base_ref="HEAD~1...HEAD"
  else
    collect_all_files
    return
  fi

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ "$file" =~ ^skills/.*\.md$ ]] || continue
    files+=("$REPO_ROOT/$file")
  done < <(git -C "$REPO_ROOT" diff --name-only --diff-filter=ACMR "$base_ref")

  if [[ "${#files[@]}" -eq 0 ]]; then
    collect_all_files
  fi
}

if [[ "$mode" == "changed" ]]; then
  collect_changed_files
else
  collect_all_files
fi

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "No markdown files found under skills/."
  exit 0
fi

errors=0
has_rg=0
if command -v rg >/dev/null 2>&1; then
  has_rg=1
fi

search_matches() {
  local pattern="$1"

  if [[ "$has_rg" -eq 1 ]]; then
    rg -n --no-heading --color never -e "$pattern" "${files[@]}" || true
    return
  fi

  local file
  for file in "${files[@]}"; do
    grep -nE "$pattern" "$file" | sed "s|^|$file:|" || true
  done
}

match_quiet() {
  local pattern="$1"
  local file="$2"
  local ignore_case="${3:-0}"

  if [[ "$has_rg" -eq 1 ]]; then
    if [[ "$ignore_case" -eq 1 ]]; then
      rg -qi -e "$pattern" "$file"
    else
      rg -q -e "$pattern" "$file"
    fi
    return
  fi

  if [[ "$ignore_case" -eq 1 ]]; then
    grep -Eqi "$pattern" "$file"
  else
    grep -Eq "$pattern" "$file"
  fi
}

report_match() {
  local rule_id="$1"
  local description="$2"
  local pattern="$3"
  local output

  output="$(search_matches "$pattern")"
  if [[ -n "$output" ]]; then
    echo "ERROR [$rule_id] $description" >&2
    echo "$output" >&2
    echo >&2
    errors=$((errors + 1))
  fi
}

echo "Running local skill security validation ($mode mode)..."

# W007-like checks: insecure credential handling patterns.
report_match \
  "W007" \
  "Hardcoded bearer token placeholders found." \
  'Authorization:[[:space:]]*"Bearer[[:space:]]*(my-token|my-api-token|YOUR_KEY|YOUR_API_KEY|my-secret-token|my-client-secret|<token>|<value>)'

report_match \
  "W007" \
  "Insecure literal secret placeholders found in examples." \
  '(client_secret|api[_-]?key|token|password)[[:space:]]*:[[:space:]]*"?((my|test|dummy|example)[-_]?(secret|token|key)|YOUR_[A-Z0-9_]+)"?'

# W011/W012-like checks: avoid explicit remote fetch instructions in prompt text.
report_match \
  "W011" \
  "Raw WebFetch instructions found; prefer trusted-source policy language." \
  'WebFetch[[:space:]]+https?://'

# W013-like checks: privileged machine mutation examples.
report_match \
  "W013" \
  "Privileged system/service modification examples found." \
  '(sudo[[:space:]]+apt(-get)?[[:space:]]+install[[:space:]]+proxy-?tunnel|>>[[:space:]]*/home/jovyan/\.ssh/authorized_keys)'

# Supply-chain hygiene for CLI guidance.
report_match \
  "SC001" \
  "Unpinned TrueFoundry CLI install command found." \
  'pip install[[:space:]]+truefoundry([[:space:]]|$)'

# PAT safety policy must remain strict.
if [[ -f "$REPO_ROOT/skills/access-tokens/SKILL.md" ]]; then
  if ! match_quiet 'Token \(masked\)' "$REPO_ROOT/skills/access-tokens/SKILL.md"; then
    echo "ERROR [W007] access-tokens/SKILL.md must include masked-token guidance." >&2
    errors=$((errors + 1))
  fi
  if ! match_quiet 'explicit user confirmation|explicitly confirms' "$REPO_ROOT/skills/access-tokens/SKILL.md"; then
    echo "ERROR [W007] access-tokens/SKILL.md must require explicit confirmation before full token reveal." >&2
    errors=$((errors + 1))
  fi
fi

# Remote trust policy check for high-risk runtime URL patterns.
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  if match_quiet '(agent_card_url:|type:[[:space:]]*remote|mcp-server/openapi)' "$file"; then
    if ! match_quiet '(trusted|untrusted|explicit user confirmation|security)' "$file" 1; then
      echo "ERROR [W012] $file contains runtime remote URL patterns without trust/safety guidance." >&2
      errors=$((errors + 1))
    fi
  fi
done < <(printf '%s\n' "${files[@]}")

if [[ "$errors" -gt 0 ]]; then
  echo "Local skill security validation failed with $errors error(s)." >&2
  exit 1
fi

echo "Local skill security validation passed."
