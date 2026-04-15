# TrueFoundry Gateway Skills

[![CI](https://github.com/truefoundry/tfy-gateway-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/truefoundry/tfy-gateway-skills/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Configure and manage TrueFoundry AI Gateway using AI coding assistants.

Works as a **plugin** for Claude Code and Codex CLI (with enforced workflows, credential checks, and secret scanning), and as **rules + skills** for Cursor.

## Quick Start

### Prerequisites

Set your TrueFoundry credentials via environment variables or a `.env` file in your project root:

```bash
export TFY_BASE_URL=https://your-org.truefoundry.cloud
export TFY_API_KEY=tfy-...
```

No account yet? Run `uv run tfy register` to sign up. The `tfy` CLI and workspace selection are handled automatically -- skills install the CLI if missing and list your available workspaces.

### Claude Code (Plugin -- Full Enforcement)

Install from the Claude Code plugin marketplace:

```
/install-plugin truefoundry/tfy-gateway-skills
```

What you get:
- 16 skills loaded automatically
- 2 specialized agents (gateway configurator, troubleshoot)
- 4 hooks enforcing safe gateway workflows
- Automatic credential checks on session start

### Codex CLI (Plugin -- Full Enforcement)

Install from the Codex plugin marketplace:

```
codex install truefoundry/tfy-gateway-skills
```

Enable hooks in your `config.toml`:

```toml
codex_hooks = true
```

Same hooks and skills as Claude Code. Agents are not yet supported in Codex.

### Cursor (Rules -- Advisory)

Copy the skills into Cursor's config directory:

```bash
npx skills add truefoundry/tfy-gateway-skills -g -a cursor -s '*' -y
```

What you get:
- 16 skills as context rules
- No hook enforcement (Cursor does not support hooks)
- Skills provide guidance but cannot block unsafe operations

### Standalone Skills (Any Agent)

For any agent that supports the [Agent Skills](https://agentskills.io) open format:

```bash
npx skills add truefoundry/tfy-gateway-skills -g -a claude-code -a cursor -a codex -s '*' -y
```

Or install for all detected agents:

```bash
npx skills add truefoundry/tfy-gateway-skills --all
```

## What You Can Do

Just ask your agent in plain English:

- *"set up model routing for gpt-4 and claude-3"*
- *"add a PII guardrail to the gateway"*
- *"register an MCP server"*
- *"configure rate limits for my API token"*
- *"show my gateway monitoring dashboard"*
- *"what's my connection status?"*

## What's Included

### 16 Skills

| Category | Skills |
|----------|--------|
| **Gateway** | [agents](skills/agents), [ai-gateway](skills/ai-gateway), [ai-monitoring](skills/ai-monitoring), [guardrails](skills/guardrails), [integrations](skills/integrations), [mcp-servers](skills/mcp-servers), [prompts](skills/prompts) |
| **Platform** | [access-control](skills/access-control), [access-tokens](skills/access-tokens), [docs](skills/docs), [logs](skills/logs), [onboarding](skills/onboarding), [secrets](skills/secrets), [status](skills/status), [tracing](skills/tracing), [workspaces](skills/workspaces) |

Installed skill names are namespaced as `truefoundry-<skill>` (e.g., `truefoundry-ai-gateway`).

### Plugin Hooks (Claude Code and Codex)

| Hook | Type | What It Does |
|------|------|-------------|
| **Session Start** | SessionStart | Verifies credentials, auto-installs/upgrades the `tfy` CLI, tests API connectivity, lists accessible workspaces |
| **Block Deletes** | PreToolUse | Blocks all DELETE API calls -- redirects users to the TrueFoundry dashboard for manual deletion |
| **Auto-Approve API** | PreToolUse | Auto-approves `tfy-api.sh` and `tfy-version.sh` calls so the agent does not prompt for each API request |
| **Secret Scan** | PreToolUse | Blocks commands containing hardcoded API keys, tokens, or credentials -- enforces `tfy-secret://` references |

### Agents (Claude Code)

| Agent | Purpose |
|-------|---------|
| **gateway-configurator** | Orchestrates AI Gateway configuration: credential check, workspace selection, secret creation, model routing, guardrails, MCP servers, rate limits, and verification. |
| **troubleshoot** | Diagnoses gateway issues by checking configuration, fetching logs, and matching error patterns (401, 403, 429, model not found, guardrail blocked, etc.) to root causes. |

### Safety Guardrails

- **No delete operations** -- all delete requests are blocked and redirected to the dashboard
- **No hardcoded secrets** -- commands with inline credentials are blocked before execution
- **Mandatory workspace confirmation** -- agents always list workspaces and ask you to choose

## Feature Comparison

| Feature | Claude Code | Codex CLI | Cursor | Standalone Skills |
|---------|:-----------:|:---------:|:------:|:-----------------:|
| 16 skills | yes | yes | yes | yes |
| Hook enforcement | yes | yes | no | no |
| Auto credential check | yes | yes | no | no |
| Delete blocking | yes | yes | no | no |
| Secret scan | yes | yes | no | no |
| Specialized agents | yes | no | no | no |
| CLI auto-install | yes | yes | no | no |

## Architecture

```
tfy-gateway-skills/
  .claude-plugin/
    plugin.json            # Plugin manifest (name, version, userConfig)
    marketplace.json       # Marketplace metadata
  hooks/
    hooks.json             # Hook definitions (SessionStart, PreToolUse)
    auto-approve-tfy-api.sh
  plugin-scripts/          # Hook implementations
    session-start.sh       # Credential + CLI bootstrap
    block-delete-operations.sh
    pre-tool-secret-scan.sh
  agents/
    gateway-configurator.md
    troubleshoot.md
  skills/
    _shared/               # Canonical copies of shared scripts and references
      scripts/             # tfy-api.sh, tfy-version.sh
      references/          # 13 shared reference docs
    ai-gateway/SKILL.md    # One directory per skill
    guardrails/SKILL.md
    ...
  scripts/                 # Dev tooling (lint, validate, sync, install)
```

Shared scripts and references live in `skills/_shared/` and are synced to individual skill directories via `./scripts/sync-shared.sh`. Never edit files in `skills/*/scripts/` or `skills/*/references/` directly.

## Development

```bash
./scripts/sync-shared.sh              # Sync shared files to all skills
./scripts/validate-skills.sh           # Validate skill structure
./scripts/validate-skill-security.sh   # Offline security checks
./scripts/test-tfy-api.sh             # Unit tests (needs python3 + curl)
./scripts/install.sh                   # Install locally
```

Shell scripts must pass `shellcheck`. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT
