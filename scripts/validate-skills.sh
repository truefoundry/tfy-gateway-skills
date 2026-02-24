#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

errors=0

fail() {
  echo "ERROR: $*" >&2
  errors=$((errors + 1))
}

require_file_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    fail "$file missing required text: $needle"
  fi
}

get_frontmatter_value() {
  local file="$1"
  local key="$2"
  sed -n '1,/^---$/p' "$file" | grep -m1 "^${key}:" | sed "s/^${key}:[[:space:]]*//"
}

echo "Validating skill frontmatter..."

while IFS= read -r skill_md; do
  skill_dir="$(basename "$(dirname "$skill_md")")"

  delimiter_count="$(grep -c '^---$' "$skill_md")"
  if [[ "$delimiter_count" -lt 2 ]]; then
    fail "$skill_md must have YAML frontmatter delimiters"
    continue
  fi

  name="$(get_frontmatter_value "$skill_md" name)"
  description="$(get_frontmatter_value "$skill_md" description)"
  allowed_tools="$(get_frontmatter_value "$skill_md" allowed-tools)"

  [[ -n "$name" ]] || fail "$skill_md missing frontmatter field: name"
  [[ -n "$description" ]] || fail "$skill_md missing frontmatter field: description"
  [[ -n "$allowed_tools" ]] || fail "$skill_md missing frontmatter field: allowed-tools"

  if [[ "$name" != "$skill_dir" ]]; then
    fail "$skill_md name '$name' must match directory '$skill_dir'"
  fi

  if ! [[ "$name" =~ ^[a-z0-9-]+$ ]]; then
    fail "$skill_md has invalid name '$name' (allowed: lowercase letters, digits, hyphens)"
  fi

  if [[ "$allowed_tools" == *,* ]]; then
    fail "$skill_md allowed-tools should be space-separated, not comma-separated"
  fi

done < <(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md | sort)

echo "Validating disable-model-invocation policy..."

expected_disabled="async-service deploy helm llm-deploy multi-service"
actual_disabled="$({
  for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
    # Check both legacy top-level field and current metadata nested field
    frontmatter="$(sed -n '1,/^---$/p' "$skill_md")"
    if echo "$frontmatter" | grep -q '^disable-model-invocation:[[:space:]]*true$' || \
       echo "$frontmatter" | grep -q 'disable-model-invocation:[[:space:]]*"true"'; then
      basename "$(dirname "$skill_md")"
    fi
  done
} | sort | paste -sd' ' -)"

if [[ "$actual_disabled" != "$expected_disabled" ]]; then
  fail "disable-model-invocation mismatch. expected='$expected_disabled' actual='$actual_disabled'"
fi

echo "Validating shared file sync..."

while IFS= read -r shared_file; do
  rel_path="${shared_file#"$SKILLS_DIR/_shared/"}"
  while IFS= read -r skill_dir; do
    skill_name="$(basename "$skill_dir")"
    [[ "$skill_name" == _shared ]] && continue
    target="$skill_dir/$rel_path"
    if [[ ! -f "$target" ]]; then
      fail "missing shared file copy: $target"
      continue
    fi
    if ! cmp -s "$shared_file" "$target"; then
      fail "shared file drift: $target differs from _shared/$rel_path"
    fi
  done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
done < <(find "$SKILLS_DIR/_shared" -type f | sort)

echo "Validating docs consistency..."

# Verify all three docs mention the explicit-only skills
for doc in README.md AGENTS.md CLAUDE.md; do
  for skill in deploy helm llm-deploy async-service multi-service; do
    if ! grep -q "$skill" "$REPO_ROOT/$doc"; then
      fail "$doc does not mention explicit-only skill: $skill"
    fi
  done
done

if [[ "$errors" -gt 0 ]]; then
  echo "Validation failed with $errors error(s)." >&2
  exit 1
fi

echo "All skill validation checks passed."
