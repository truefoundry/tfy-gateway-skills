# TrueFoundry Agent Skills — Developer Guide

A collection of 16 AI coding-agent skill definitions (markdown + shell scripts) following the [Agent Skills](https://agentskills.io) open format. Skills let AI assistants configure and manage the TrueFoundry AI Gateway, agents, monitoring, integrations, guardrails, MCP servers, and prompts.

## Repository Overview

This is a **content/tooling repository** — there are no application servers, databases, or Docker containers. The codebase consists of:

- **skills/** — 16 skill directories (e.g. `agents`, `ai-gateway`, `ai-monitoring`, `guardrails`, `integrations`, `mcp-servers`, `prompts`, `status`, `tracing`, `workspaces`, etc.) each containing a `SKILL.md` frontmatter file, plus `_shared/` with canonical scripts and references synced to all skills.
- **scripts/** — development and CI tooling (validation, sync, install, tests).
- **hooks/** — git pre-push hook and Claude Code auto-approve hook.

### Key Commands

| Task | Command |
|------|---------|
| Lint (shellcheck) | `shellcheck scripts/*.sh hooks/auto-approve-tfy-api.sh skills/_shared/scripts/tfy-api.sh` |
| Validate skills | `./scripts/validate-skills.sh` |
| Security checks | `./scripts/validate-skill-security.sh` |
| Unit tests | `./scripts/test-tfy-api.sh` |
| Sync shared files | `./scripts/sync-shared.sh` |
| Install locally | `./scripts/install.sh` |
| Install help | `bash scripts/install.sh --help` |

See [CONTRIBUTING.md](CONTRIBUTING.md) for full development workflow.

## Cursor Cloud specific instructions

### System Dependencies

The only system package not pre-installed is **shellcheck** — it is installed automatically by the update script on VM startup.

### Running CI Checks Locally

All CI checks can be reproduced locally with these commands (run from repo root):

```bash
shellcheck scripts/*.sh hooks/auto-approve-tfy-api.sh skills/_shared/scripts/tfy-api.sh
./scripts/validate-skills.sh
./scripts/validate-skill-security.sh
./scripts/test-tfy-api.sh
```

### Gotchas

- **Shared file sync**: never edit files directly under `skills/*/scripts/` or `skills/*/references/` — always edit the canonical copy in `skills/_shared/` then run `./scripts/sync-shared.sh`.
- **Pre-push hook**: run `./scripts/setup-git-hooks.sh` once to enable automatic validation before every `git push`.
- **`test-tfy-api.sh`** spins up a Python 3 mock HTTP server on an ephemeral port. It requires `python3` and `curl`.
- **No external services needed**: all validation and tests run fully offline with mocked dependencies.
- **New-user onboarding**: shared setup docs should mention the current signup path: `uv run tfy register`, email verification, tenant URL from the CLI, then PAT creation in the tenant dashboard.
