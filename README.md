# TrueFoundry Skills

Agent skills for [TrueFoundry](https://truefoundry.com), following the [Agent Skills](https://agentskills.io) open format.

Deploy, monitor, and manage your ML infrastructure without leaving your editor.

## Installation

### Prerequisites

You'll need these tools available on your machine:
- `bash` (supports arrays/functions)
- `curl` or `wget`
- `tar`
- `jq` (required by `hooks/auto-approve-tfy-api.sh`)

**Quick install** (auto-detects your tools):

```bash
curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-agent-skills/main/scripts/install.sh | bash
```

This installs skills for every supported tool found on your machine. Re-run anytime to update.

### Supported Tools

| Tool | Skills directory |
|------|-----------------|
| [Claude Code](https://claude.ai/code) | `~/.claude/skills/` |
| [OpenAI Codex](https://openai.com/index/codex/) | `~/.codex/skills/` |
| [Cursor](https://cursor.com) | `~/.cursor/skills/` |
| [OpenCode](https://opencode.ai) | `~/.config/opencode/skill/` |

### Manual Installation

**Any agent (copy skills):**

```bash
cp -R skills/* ~/.claude/skills/    # or ~/.cursor/skills/, etc.
```

The install script prefixes each skill with `truefoundry-` (e.g. `truefoundry-deploy`, `truefoundry-status`).

## Available Skills

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [status](skills/status/SKILL.md) | "is truefoundry connected" | Verify credentials and connection |
| [workspaces](skills/workspaces/SKILL.md) | "list workspaces" | Browse workspaces and clusters |
| [deploy](skills/deploy/SKILL.md) | "deploy to truefoundry" | Ship local code to TrueFoundry |
| [helm](skills/helm/SKILL.md) | "deploy a database" | Deploy Helm charts (Postgres, Redis, etc.) |
| [applications](skills/applications/SKILL.md) | "what's deployed" | List and inspect running services |
| [jobs](skills/jobs/SKILL.md) | "show job runs" | Monitor job executions |
| [logs](skills/logs/SKILL.md) | "show logs" | Stream and download app logs |
| [secrets](skills/secrets/SKILL.md) | "list secrets" | Manage secret groups and values |
| [prompts](skills/prompts/SKILL.md) | "show my prompts" | Browse prompt registry versions |
| [docs](skills/docs/SKILL.md) | "truefoundry docs" | Fetch platform documentation |

Skills are model-invoked — your agent picks the right one based on what you ask. The exceptions are `deploy` and `helm`, which only run when you explicitly request them.

## Setup

Set these environment variables (or add to `.env` in your project root):

```bash
export TFY_BASE_URL="https://your-org.truefoundry.cloud"
export TFY_API_KEY="tfy-..."
```

| Variable | Required | Description |
|----------|----------|-------------|
| `TFY_BASE_URL` | Yes | Your TrueFoundry platform URL |
| `TFY_API_KEY` | Yes | API key ([generate one](https://docs.truefoundry.com/docs/generating-truefoundry-api-keys)) |
| `TFY_WORKSPACE_FQN` | For deploy | Target workspace (e.g. `cluster-name:workspace-name`) |
| `TFY_CLUSTER_ID` | No | Default cluster for filtering |

## How Skills Work

Each skill works in two modes — pick whichever fits your setup:

**With MCP Server (recommended)** — If you have [tfy-mcp-server](https://github.com/truefoundry/tfy-mcp-server) running, skills call MCP tools like `tfy_applications_list` and `tfy_workspaces_list` directly. The full deploy workflow — workspace discovery, deploy, verify, debug — works best in this mode since the agent can chain tool calls with structured data and no Bash permission prompts.

**Standalone** — Every skill bundles `scripts/tfy-api.sh`, a lightweight authenticated curl wrapper that talks to the TrueFoundry REST API. No server needed — just env vars. This is the fallback for tools that don't support MCP yet.

Both modes use the same credentials. Skills include instructions for each path, so they adapt automatically.

## Hooks

The plugin includes a `PreToolUse` hook that auto-approves `tfy-api.sh` calls, so you don't get a permission prompt on every API request.

```
hooks/
├── hooks.json              # Hook configuration
└── auto-approve-tfy-api.sh # Approval script
```

## Skill Composition

Skills are designed to chain together. Common workflows:

```
Deploy:     status → workspaces → deploy → applications
Debug:      applications → logs
Onboard:    status → secrets → deploy → applications
```

## Repository Structure

```
tfy-agent-skills/
├── scripts/
│   ├── install.sh                 # Universal installer
│   └── sync-shared.sh             # Distribute shared files
├── skills/
│   ├── _shared/                   # Canonical shared files
│   │   ├── scripts/
│   │   │   └── tfy-api.sh         # Authenticated REST helper
│   │   └── references/
│   │       ├── api-endpoints.md
│   │       └── deploy-template.py
│   ├── status/SKILL.md
│   ├── workspaces/SKILL.md
│   ├── deploy/SKILL.md
│   ├── applications/SKILL.md
│   ├── jobs/SKILL.md
│   ├── logs/SKILL.md
│   ├── secrets/SKILL.md
│   ├── prompts/SKILL.md
│   └── docs/SKILL.md
├── hooks/
│   ├── hooks.json                 # Auto-approve API calls
│   └── auto-approve-tfy-api.sh
├── AGENTS.md
├── CLAUDE.md
└── README.md
```

## Development

### Creating a New Skill

Create `skills/{name}/SKILL.md` with YAML frontmatter:

```yaml
---
name: my-skill
description: When to invoke this skill — phrases the user might say.
allowed-tools: Bash(*/tfy-api.sh *)
---

# Skill Title

Instructions for the agent...
```

Include both MCP tool and direct API (`tfy-api.sh`) instructions so the skill works in either mode.

### Shared Files

Scripts and references live in `skills/_shared/` and are copied into each skill for portability. Always edit the canonical version, then sync:

```bash
./scripts/sync-shared.sh
```

Never edit files inside individual skill `scripts/` or `references/` directories directly — they get overwritten on sync.

### Testing Locally

```bash
# Install to your tool and restart
./scripts/install.sh
```

## References

- [TrueFoundry Documentation](https://docs.truefoundry.com)
- [TrueFoundry API Reference](https://docs.truefoundry.com/api-reference)
- [Agent Skills Specification](https://agentskills.io)
- [tfy-mcp-server](https://github.com/truefoundry/tfy-mcp-server) — MCP server for TrueFoundry

## License

MIT
