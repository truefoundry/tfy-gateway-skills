# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Agent skills for [TrueFoundry](https://truefoundry.com) following the [Agent Skills](https://agentskills.io) open format. Each skill is a standalone Markdown file (`SKILL.md`) with YAML frontmatter that tells AI coding assistants how to interact with TrueFoundry's platform API.

Skills work across Claude Code, Cursor, OpenAI Codex, and OpenCode.

## Dev Commands

```bash
# Install skills to all detected agents on this machine
./scripts/install.sh

# After editing anything in skills/_shared/, sync copies to all skill directories
./scripts/sync-shared.sh

# Install skills and restart agent
./scripts/install.sh
```

## Architecture

### Deployment modes

Deploy skills use a CLI-first approach with REST API as fallback:

1. **CLI** (`tfy apply`) — Primary. Write a YAML manifest and apply it. Works everywhere `tfy` CLI is installed.
2. **REST API** (fallback) — When CLI is unavailable, convert YAML to JSON and use `tfy-api.sh`. See `cli-fallback.md`.
3. **MCP tools** — When `tfy-mcp-server` is configured, non-deploy skills reference tool names like `tfy_applications_list`.

All modes use `TFY_BASE_URL` and `TFY_API_KEY` from env or `.env`.

### Skill format

Each skill lives in `skills/{name}/SKILL.md` with this structure:

```yaml
---
name: skill-name
description: Trigger phrases for model invocation.
allowed-tools: Bash(*/tfy-api.sh *)
---
# Instructions for the agent...
```

- `description` controls when the agent auto-invokes the skill (model-invoked).
- The explicit-only skills are: `deploy`, `helm`, `llm-deploy`, `async-service`, and `multi-service`.
- `allowed-tools` grants the skill permission to run specific commands without prompting.

### Shared files

`skills/_shared/` is the canonical source for files shared across all skills:

- `_shared/scripts/tfy-api.sh` — authenticated REST helper
- `_shared/references/api-endpoints.md` — endpoint reference
- `_shared/references/manifest-schema.md` — complete YAML manifest field reference (single source of truth)
- `_shared/references/manifest-defaults.md` — per-service-type defaults with YAML templates
- `_shared/references/cli-fallback.md` — CLI detection and REST API fallback pattern

**Never edit files inside individual skill `scripts/` or `references/` directories.** Edit `_shared/`, then run `./scripts/sync-shared.sh`. The install script symlinks `_shared/` into each installed skill; `sync-shared.sh` copies files for the dev layout.

### Installer

`scripts/install.sh` installs skills with `truefoundry-` prefix (e.g. `truefoundry-deploy`) and symlinks shared files from a single `_shared/` directory. It auto-detects installed agents (`~/.claude/`, `~/.cursor/`, `~/.codex/`, etc.).

### Hooks

`hooks/hooks.json` registers a `PreToolUse` hook that auto-approves Bash commands matching `scripts/tfy-api.sh` patterns, so the agent doesn't prompt on every API call. The approval script (`hooks/auto-approve-tfy-api.sh`) validates the command path before approving.

## Key Conventions

- The repo root `skills/` directory is the source of truth for development.
- Skills reference each other for composability (e.g. deploy tells users to check `workspaces` skill first). Common flows: `status → workspaces → deploy → applications`, `applications → logs`.
- `TFY_WORKSPACE_FQN` is never auto-picked by any skill — always ask the user.
- When adding a new skill, include CLI-first instructions with direct API fallback, reference the `status` skill for preflight checks, and run `sync-shared.sh` afterward.

## Version Awareness

Skills detect the `tfy` CLI version before deploying to ensure compatibility.

### Detection flow

1. Run `tfy --version` → check CLI is installed and current
2. Check `references/container-versions.md` for latest image versions
3. If CLI unavailable → fall back to REST API via `cli-fallback.md`

### Key rules

- CLI >= 0.5.0: use `tfy apply` as documented
- CLI 0.3.x–0.4.x: upgrade recommended, core `tfy apply` still works
- CLI not installed: fall back to REST API via `tfy-api.sh`
- Container images: always check `container-versions.md` for pinned versions; use WebFetch to check for newer stable releases when deploying

### Freshness strategy

| Asset | Staleness Risk | Strategy |
|-------|---------------|----------|
| REST API endpoints | Low | Manual updates to `api-endpoints.md` |
| Manifest schema | Low | `manifest-schema.md` documents all field types |
| Container images | High | Pinned in `container-versions.md`, WebFetch on demand |
| CLI version | Low | `tfy --version` check at runtime |

## Agent Teams

When working on this repo, always use agent teams for parallel work. The codebase has many independent skills and shared files that can be edited concurrently. Use `TeamCreate` to coordinate multi-file changes, especially when:

- Modifying multiple skills simultaneously
- Creating new shared references while updating skills that use them
- Running sync and install scripts after edits

## Agent Skills Spec Compliance

Skills follow the [Agent Skills](https://agentskills.io) open format. Frontmatter fields currently in use:

| Field | Used | Purpose |
|-------|------|---------|
| `name` | Yes | Skill identifier, used for install prefix |
| `description` | Yes | Trigger phrases for model invocation |
| `allowed-tools` | Yes | Auto-approved tool patterns |
| `disable-model-invocation` | Yes | Opt-out of auto-triggering (deploy, helm, llm-deploy, async-service, multi-service) |

Optional fields to consider adding:

| Field | Status | Notes |
|-------|--------|-------|
| `license` | Not yet | Could add `Apache-2.0` to all skills |
| `compatibility` | Not yet | Could specify agent version requirements |
| `metadata` | Not yet | Could add tags, categories, author info |
