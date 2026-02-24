#!/usr/bin/env bash
# Sync shared files from _shared/ to each skill directory.
# Run after editing files in skills/_shared/.
# Must be run from the repository root (directory containing scripts/ and skills/).
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
SHARED_DIR="$SKILLS_DIR/_shared"

if [ ! -d "$SHARED_DIR" ]; then
  echo "Error: $SHARED_DIR not found" >&2
  exit 1
fi

count=0
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  [[ "$skill_name" == _* ]] && continue
  [ -f "$skill_dir/SKILL.md" ] || continue

  # Sync scripts
  if [ -d "$SHARED_DIR/scripts" ]; then
    mkdir -p "$skill_dir/scripts"
    cp -R "$SHARED_DIR"/scripts/* "$skill_dir/scripts/" 2>/dev/null || true
  fi

  # Sync references
  if [ -d "$SHARED_DIR/references" ]; then
    mkdir -p "$skill_dir/references"
    cp -R "$SHARED_DIR"/references/* "$skill_dir/references/" 2>/dev/null || true
  fi

  count=$((count + 1))
done

# Make scripts executable
find "$SKILLS_DIR"/*/scripts -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

# Verify copies match canonical source
errors=0
for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  [[ "$skill_name" == _* ]] && continue
  [ -f "$skill_dir/SKILL.md" ] || continue

  for shared_file in "$SHARED_DIR"/scripts/* "$SHARED_DIR"/references/*; do
    [ -f "$shared_file" ] || continue
    rel_path="${shared_file#"$SHARED_DIR"/}"
    target="$skill_dir/$rel_path"
    if [ -f "$target" ] && ! cmp -s "$shared_file" "$target"; then
      echo "ERROR: $skill_name/$rel_path differs from _shared/" >&2
      errors=$((errors + 1))
    fi
  done
done

if [ "$errors" -gt 0 ]; then
  echo "FAILED: $errors files out of sync after copy" >&2
  exit 1
fi

echo "Synced shared files to $count skills."
