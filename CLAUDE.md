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

# Test locally with Claude Code (plugin mode)
claude --plugin-dir ./plugins/truefoundry
```

## Architecture

### Dual-mode operation

Every skill provides two equivalent instruction paths:

1. **MCP tools** — When `tfy-mcp-server` is configured, skills reference tool names like `tfy_applications_list`. The agent calls these directly.
2. **Direct API** — Each skill bundles `scripts/tfy-api.sh`, an authenticated curl wrapper. Used when MCP is unavailable.

Both modes use `TFY_BASE_URL` and `TFY_API_KEY` from env or `.env`.

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
- `disable-model-invocation: true` (used by `deploy` and `helm`) means the skill only runs on explicit user request.
- `allowed-tools` grants the skill permission to run specific commands without prompting.

### Shared files

`skills/_shared/` is the canonical source for files shared across all skills:

- `_shared/scripts/tfy-api.sh` — authenticated REST helper
- `_shared/references/api-endpoints.md` — endpoint reference
- `_shared/references/deploy-template.py` — deploy script template

**Never edit files inside individual skill `scripts/` or `references/` directories.** Edit `_shared/`, then run `./scripts/sync-shared.sh`. The install script symlinks `_shared/` into each installed skill; `sync-shared.sh` copies files for the dev layout.

### Installer

`scripts/install.sh` installs skills with `truefoundry-` prefix (e.g. `truefoundry-deploy`) and symlinks shared files from a single `_shared/` directory. It auto-detects installed agents (`~/.claude/`, `~/.cursor/`, `~/.codex/`, etc.).

### Hooks

`hooks/hooks.json` registers a `PreToolUse` hook that auto-approves Bash commands matching `scripts/tfy-api.sh` patterns, so the agent doesn't prompt on every API call. The approval script (`hooks/auto-approve-tfy-api.sh`) validates the command path before approving.

## Key Conventions

- `sync-shared.sh` references `plugins/truefoundry/skills/` as the skills directory path — this is the plugin layout. The repo root `skills/` directory is the source of truth for development.
- Skills reference each other for composability (e.g. deploy tells users to check `workspaces` skill first). Common flows: `status → workspaces → deploy → applications`, `applications → logs`.
- `TFY_WORKSPACE_FQN` is never auto-picked by any skill — always ask the user.
- When adding a new skill, include both MCP and direct API instructions, reference the `status` skill for preflight checks, and run `sync-shared.sh` afterward.
