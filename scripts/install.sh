#!/usr/bin/env bash
# TrueFoundry Agent Skills installer
#
# Install:  curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-agent-skills/main/scripts/install.sh | bash
# Options:  ... | bash -s -- [--global] [--local] [--agents claude,cursor,codex]
#
# Or run from inside the repo:  ./scripts/install.sh
set -euo pipefail

REPO="truefoundry/tfy-agent-skills"
BRANCH="main"
TARBALL_URL="https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz"

# ── Colours ──────────────────────────────────────────────────────────────────
BOLD=$'\033[1m'  DIM=$'\033[2m'
RED=$'\033[31m'  GREEN=$'\033[32m'  YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'  CYAN=$'\033[36m'  NC=$'\033[0m'

info()      { printf '%s> %s%s\n' "$BOLD" "$*" "$NC"; }
warn()      { printf '%s!%s %s\n' "$YELLOW" "$NC" "$*"; }
error()     { printf '%sx %s%s\n' "$RED" "$*" "$NC" >&2; }
ok()        { printf '%s✓%s %s\n' "$GREEN" "$NC" "$*"; }

banner() {
  printf '\n%s' "$MAGENTA"
  cat <<'BANNER'
  ╔════════════════════════════════════════╗
  ║     TrueFoundry Skills Installed!     ║
  ╚════════════════════════════════════════╝
BANNER
  printf '%s\n' "$NC"
}

# ── Supported agents ─────────────────────────────────────────────────────────
# Format: config_dir|skills_subdir|display_name
#   config_dir   — parent dir whose existence means the agent is installed
#   skills_subdir — where skills go (relative to $HOME for global, CWD for local)
AGENTS_GLOBAL=(
  ".claude|.claude/skills|Claude Code"
  ".cursor|.cursor/skills|Cursor"
  ".codex|.codex/skills|OpenAI Codex"
  ".config/opencode|.config/opencode/skill|OpenCode"
  ".windsurf|.windsurf/skills|Windsurf"
  ".cline|.cline/skills|Cline"
  ".roo-code|.roo-code/skills|Roo Code"
)

# Skills to install (directory names inside skills/)
SKILL_NAMES=(
  ai-gateway applications async-service deploy docs gitops helm jobs llm-benchmarking llm-deploy llm-finetuning logs mcp-server multi-service notebooks prompts secrets ssh-server status tfy-apply volumes workflows workspaces
)

# Shared files (relative to _shared/ in source)
SHARED_SCRIPTS=( "scripts/tfy-api.sh" "scripts/tfy-version.sh" )
SHARED_REFS=( "references/api-endpoints.md" "references/deploy-template.py" "references/sdk-patterns.md" "references/sdk-version-map.md" "references/container-versions.md" )

# ── Parse args ───────────────────────────────────────────────────────────────
MODE=""            # "" = auto (global + local if applicable), "global", "local"
FILTER_AGENTS=""   # comma-separated agent names to restrict to

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global) MODE="global"; shift ;;
    --local)  MODE="local";  shift ;;
    --agents) FILTER_AGENTS="$2"; shift 2 ;;
    --help|-h)
      cat <<EOF
Usage: install.sh [--global] [--local] [--agents claude,cursor,codex]

Options:
  --global         Install to ~/.{agent}/skills/ only
  --local          Install to ./{agent}/skills/ in current directory only
  --agents LIST    Comma-separated agent names: claude,cursor,codex,opencode,windsurf,cline,roo-code

Without flags, installs globally to all detected agents,
plus locally if agent config dirs exist in the current directory.
EOF
      exit 0 ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Agent filtering helper ───────────────────────────────────────────────────
agent_allowed() {
  local name="$1"
  [ -z "$FILTER_AGENTS" ] && return 0
  echo ",$FILTER_AGENTS," | grep -qi ",$name,"
}

# ── Download source ──────────────────────────────────────────────────────────
get_source() {
  # If running from inside the repo, use local files
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)" || true
  if [ -n "$script_dir" ]; then
    local repo_root
    repo_root="$(cd "$script_dir/.." 2>/dev/null && pwd)" || true
    if [ -d "$repo_root/skills/_shared" ]; then
      info "Installing from local repo: ${CYAN}$repo_root${NC}" >&2
      echo "$repo_root"
      return 0
    fi
  fi

  # Download tarball (no git required)
  info "Downloading from ${CYAN}github.com/$REPO${NC}..."
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$TARBALL_URL" | tar xz -C "$tmpdir"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$TARBALL_URL" | tar xz -C "$tmpdir"
  else
    error "Neither curl nor wget found. Install one and retry."
    exit 1
  fi

  # GitHub tarballs extract to {repo}-{branch}/
  local extracted
  extracted=$(find "$tmpdir" -mindepth 1 -maxdepth 1 -type d | head -1)
  if [ -z "$extracted" ] || [ ! -d "$extracted/skills" ]; then
    error "Download failed or unexpected archive structure."
    exit 1
  fi

  echo "$extracted"
}

# ── Install skills into a target directory ───────────────────────────────────
install_skills() {
  local target_dir="$1"   # e.g. ~/.claude/skills
  local label="$2"        # e.g. "Claude Code"
  local source_dir="$3"   # repo root
  local src_skills="$source_dir/skills"

  mkdir -p "$target_dir"

  # Clean previous installs
  rm -rf "$target_dir"/truefoundry-* 2>/dev/null || true
  rm -rf "$target_dir"/_shared 2>/dev/null || true

  # Install _shared
  mkdir -p "$target_dir/_shared/scripts" "$target_dir/_shared/references"
  for f in "${SHARED_SCRIPTS[@]}"; do
    cp "$src_skills/_shared/$f" "$target_dir/_shared/$f"
  done
  for f in "${SHARED_REFS[@]}"; do
    cp "$src_skills/_shared/$f" "$target_dir/_shared/$f"
  done
  chmod +x "$target_dir"/_shared/scripts/*.sh 2>/dev/null || true

  # Install each skill: SKILL.md + symlinks to _shared
  local count=0
  for skill in "${SKILL_NAMES[@]}"; do
    local src="$src_skills/$skill"
    [ -f "$src/SKILL.md" ] || continue

    local dest="$target_dir/truefoundry-$skill"
    mkdir -p "$dest"
    cp "$src/SKILL.md" "$dest/SKILL.md"

    # Symlink scripts/ and references/ to _shared
    ln -sfn ../_shared/scripts    "$dest/scripts"
    ln -sfn ../_shared/references "$dest/references"

    count=$((count + 1))
  done

  ok "$label: ${GREEN}$count${NC} skills ${DIM}→${NC} ${CYAN}$target_dir${NC}"
}

# ── Detect and install ───────────────────────────────────────────────────────
detect_and_install() {
  local base="$1"    # $HOME for global, $(pwd) for local
  local suffix="$2"  # "" for global, " (project)" for local
  local found=0

  for entry in "${AGENTS_GLOBAL[@]}"; do
    local config_dir="${entry%%|*}"
    local remainder="${entry#*|}"
    local skills_dir="${remainder%%|*}"
    local display="${remainder##*|}"

    # Extract short agent name from config_dir for filtering
    local agent_name="${config_dir##*/}"
    agent_name="${agent_name#.}"  # strip leading dot (.claude → claude)

    agent_allowed "$agent_name" || continue

    if [ -d "$base/$config_dir" ]; then
      install_skills "$base/$skills_dir" "${display}${suffix}" "$SOURCE_DIR"
      found=$((found + 1))
    fi
  done

  return $((found == 0))
}

# ── Main ─────────────────────────────────────────────────────────────────────
printf '\n%sTrueFoundry Skills%s\n\n' "$BOLD" "$NC"

SOURCE_DIR="$(get_source)"
printf "\n"

installed=0

# Global install
if [ "$MODE" != "local" ]; then
  if detect_and_install "$HOME" ""; then
    installed=1
  fi
fi

# Local install (current project)
if [ "$MODE" != "global" ] && [ "$(pwd)" != "$HOME" ]; then
  if detect_and_install "$(pwd)" " (project)"; then
    installed=1
  fi
fi

if [ "$installed" -eq 0 ]; then
  error "No supported agents found."
  printf "\n  Supported agents:\n"
  for entry in "${AGENTS_GLOBAL[@]}"; do
    local_display="${entry##*|}"
    local_config="${entry%%|*}"
    printf '    %s•%s %-14s %s~/%s%s\n' "$DIM" "$NC" "$local_display" "$DIM" "$local_config" "$NC"
  done
  printf '\n  Install an agent first, or use %s--agents%s to specify.\n\n' "$CYAN" "$NC"
  exit 1
fi

banner
printf '  %sShared files in %s_shared/%s — update once, all skills use it.%s\n\n' "$DIM" "$CYAN" "$DIM" "$NC"
warn "Restart your agent to load skills."
printf "\n"
info "Run again anytime to update: ${DIM}curl -fsSL https://raw.githubusercontent.com/$REPO/$BRANCH/scripts/install.sh | bash${NC}"
printf "\n"
