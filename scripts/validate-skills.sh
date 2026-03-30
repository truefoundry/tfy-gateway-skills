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

get_frontmatter_block() {
  local file="$1"
  awk '
    $0 == "---" {
      delimiter_count++
      if (delimiter_count == 1) {
        next
      }
      if (delimiter_count == 2) {
        exit
      }
    }
    delimiter_count == 1 {
      print
    }
  ' "$file"
}

get_frontmatter_value() {
  local file="$1"
  local key="$2"
  get_frontmatter_block "$file" | awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
      sub("^[[:space:]]*" key ":[[:space:]]*", "", $0)
      print
      exit
    }
  '
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

echo "Validating skill coverage..."

all_skill_dirs="$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name _shared -exec basename {} \; | sort | paste -sd' ' -)"
installer_skills="$(awk '
  /^SKILL_NAMES=\(/ { in_array=1; next }
  in_array && /^\)/ { exit }
  in_array {
    gsub(/#.*/, "", $0)
    for (i = 1; i <= NF; i++) {
      if ($i != "") print $i
    }
  }
' "$REPO_ROOT/scripts/install.sh" | sort -u | paste -sd' ' -)"

if [[ "$installer_skills" != "$all_skill_dirs" ]]; then
  fail "install skill list mismatch. expected='$all_skill_dirs' actual='$installer_skills'"
fi

if [[ "$errors" -gt 0 ]]; then
  echo "Validation failed with $errors error(s)." >&2
  exit 1
fi

echo "All skill validation checks passed."
