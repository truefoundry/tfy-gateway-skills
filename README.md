# TrueFoundry Skills

Agent skills for [TrueFoundry](https://truefoundry.com), following the [Agent Skills](https://agentskills.io) open format.

Deploy, monitor, and manage your ML infrastructure without leaving your editor.

## Quick Start

```bash
# 1. Install skills (auto-detects Claude Code, Cursor, Codex, etc.)
curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-agent-skills/main/scripts/install.sh | bash

# 2. Set credentials (or add to .env)
export TFY_BASE_URL="https://your-org.truefoundry.cloud"
export TFY_API_KEY="tfy-..."

# 3. Restart your agent, then just ask:
#    "Deploy my FastAPI app to TrueFoundry"
#    "What's deployed in my workspace?"
#    "Show logs for my-service"
```

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
| [Windsurf](https://windsurf.com) | `~/.windsurf/skills/` |
| [Cline](https://cline.bot) | `~/.cline/skills/` |
| [Roo Code](https://roocode.com) | `~/.roo-code/skills/` |

### Manual Installation

**Any agent (copy skills):**

```bash
cp -R skills/* ~/.claude/skills/    # or ~/.cursor/skills/, etc.
```

The install script prefixes each skill with `truefoundry-` (e.g. `truefoundry-deploy`, `truefoundry-status`).

## Available Skills

### Core Deployment

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [status](skills/status/SKILL.md) | "is truefoundry connected" | Verify credentials and connection |
| [workspaces](skills/workspaces/SKILL.md) | "list workspaces" | Browse workspaces and clusters |
| [deploy](skills/deploy/SKILL.md) | "deploy to truefoundry" | Ship local code to TrueFoundry |
| [applications](skills/applications/SKILL.md) | "what's deployed" | List and inspect running services |
| [multi-service](skills/multi-service/SKILL.md) | "deploy frontend and backend" | Deploy multi-component applications |
| [tfy-apply](skills/tfy-apply/SKILL.md) | "tfy apply" | Declarative YAML-based deployments |
| [gitops](skills/gitops/SKILL.md) | "setup gitops" | CI/CD pipelines with GitHub Actions / GitLab CI |

### LLM & AI

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [llm-deploy](skills/llm-deploy/SKILL.md) | "deploy a model" | Deploy LLMs with vLLM, TGI, or NIM |
| [llm-finetuning](skills/llm-finetuning/SKILL.md) | "finetune a model" | Fine-tune LLMs with LoRA/QLoRA |
| [llm-benchmarking](skills/llm-benchmarking/SKILL.md) | "benchmark model" | Measure LLM latency and throughput |
| [ai-gateway](skills/ai-gateway/SKILL.md) | "use AI gateway" | Unified API for LLMs with rate limiting and guardrails |

### Infrastructure

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [helm](skills/helm/SKILL.md) | "deploy a database" | Deploy Helm charts (Postgres, Redis, Qdrant, etc.) |
| [volumes](skills/volumes/SKILL.md) | "create a volume" | Persistent storage for pods |
| [secrets](skills/secrets/SKILL.md) | "list secrets" | Manage secret groups and values |

### Jobs & Async

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [jobs](skills/jobs/SKILL.md) | "show job runs" | Deploy and monitor batch jobs |
| [workflows](skills/workflows/SKILL.md) | "create a workflow" | Multi-step pipelines built on Flyte |
| [async-service](skills/async-service/SKILL.md) | "deploy async service" | Queue-based processing (SQS, Kafka, NATS) |

### Development Environments

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [notebooks](skills/notebooks/SKILL.md) | "launch a notebook" | Jupyter notebooks with GPU support |
| [ssh-server](skills/ssh-server/SKILL.md) | "launch ssh server" | Remote development with VS Code |
| [mcp-server](skills/mcp-server/SKILL.md) | "deploy MCP server" | Host Model Context Protocol servers |

### Observability & Reference

| Skill | Trigger | What it does |
|-------|---------|--------------|
| [logs](skills/logs/SKILL.md) | "show logs" | Stream and download app logs |
| [prompts](skills/prompts/SKILL.md) | "show my prompts" | Browse prompt registry versions |
| [docs](skills/docs/SKILL.md) | "truefoundry docs" | Fetch platform documentation |

Skills are model-invoked — your agent picks the right one based on what you ask. The exceptions are `deploy`, `helm`, `llm-deploy`, `async-service`, and `multi-service`, which only run when you explicitly request them.

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

**Standalone (default)** — Every skill bundles `scripts/tfy-api.sh`, a lightweight authenticated curl wrapper that talks to the TrueFoundry REST API. No server needed — just env vars and credentials.

**With MCP Server (recommended for best experience)** — Pair skills with [tfy-mcp-server](https://github.com/truefoundry/tfy-mcp-server) for structured tool calls, compound operations, and no Bash permission prompts. See [Enhanced Setup with MCP Server](#enhanced-setup-with-mcp-server-optional) below.

Both modes use the same credentials. Skills include instructions for each path, so they adapt automatically.

## Enhanced Setup with MCP Server (Optional)

For the best experience, pair agent skills with the [TrueFoundry MCP Server](https://github.com/truefoundry/tfy-mcp-server). Skills provide the decision-making context (when to deploy, what resources to use, how to handle errors), while the MCP server provides structured tool execution.

### Benefits of adding MCP Server

| Feature | Skills Only | Skills + MCP Server |
|---------|------------|---------------------|
| API calls | Raw bash + JSON parsing | Typed tool calls with validation |
| Compound operations | Multiple sequential calls | Single tool (e.g. cluster + status + addons) |
| Permission prompts | Prompted per bash call (unless hooks configured) | No prompts for MCP tool calls |
| Token usage | Full JSON responses in context | Pre-formatted, concise responses |
| Mutation safety | Agent follows instructions | Server enforces human approval |

### Quick MCP Setup

**Option 1: Local server (stdio)**

```bash
# Install
git clone https://github.com/truefoundry/tfy-mcp-server.git
cd tfy-mcp-server
python3 -m venv .venv && source .venv/bin/activate
pip install -e .
```

Add to your MCP client config:

<details>
<summary><b>Claude Code</b> (~/.claude.json)</summary>

```json
{
  "mcpServers": {
    "truefoundry": {
      "command": "/path/to/tfy-mcp-server/.venv/bin/tfy-mcp-server",
      "env": {
        "TFY_MCP_TRANSPORT": "stdio",
        "TFY_BASE_URL": "https://your-org.truefoundry.cloud",
        "TFY_API_KEY": "tfy-..."
      }
    }
  }
}
```
</details>

<details>
<summary><b>Cursor</b> (~/.cursor/mcp.json)</summary>

```json
{
  "mcpServers": {
    "truefoundry": {
      "command": "/path/to/tfy-mcp-server/.venv/bin/tfy-mcp-server",
      "env": {
        "TFY_MCP_TRANSPORT": "stdio",
        "TFY_BASE_URL": "https://your-org.truefoundry.cloud",
        "TFY_API_KEY": "tfy-..."
      }
    }
  }
}
```
</details>

<details>
<summary><b>VS Code</b> (~/.vscode/mcp.json)</summary>

```json
{
  "mcpServers": {
    "truefoundry": {
      "command": "/path/to/tfy-mcp-server/.venv/bin/tfy-mcp-server",
      "env": {
        "TFY_MCP_TRANSPORT": "stdio",
        "TFY_BASE_URL": "https://your-org.truefoundry.cloud",
        "TFY_API_KEY": "tfy-..."
      }
    }
  }
}
```
</details>

**Option 2: Remote server (HTTP)**

Deploy tfy-mcp-server to TrueFoundry (or any host), then point your client at the URL:

```json
{
  "mcpServers": {
    "truefoundry": {
      "transport": "http",
      "url": "https://your-mcp-server.example.com/mcp",
      "headers": {
        "TFY_BASE_URL": "https://your-org.truefoundry.cloud",
        "TFY_API_KEY": "tfy-...",
        "TFY_CLUSTER_ID": "your-cluster-id"
      }
    }
  }
}
```

### MCP Tools Available

The MCP server provides 16 tools that complement the skills:

| MCP Tool | Corresponding Skill |
|----------|-------------------|
| `tfy_config_status` | status |
| `tfy_workspaces_list` | workspaces |
| `tfy_clusters_list` | workspaces |
| `tfy_applications_list`, `tfy_applications_create_deployment` | applications, deploy |
| `tfy_jobs_list_runs` | jobs |
| `tfy_secrets_list`, `tfy_secret_groups_create` | secrets |
| `tfy_prompts_list` | prompts |
| `tfy_logs_download` | logs |
| `tfy_mlrepos_list` | — |
| `tfy_model_deployments_get_specs` | llm-deploy |

Skills without MCP equivalents (ai-gateway, helm, llm-deploy, llm-finetuning, volumes, workflows, notebooks, ssh-server, gitops, etc.) continue to work via `tfy-api.sh`.

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
│   │   │   ├── tfy-api.sh         # Authenticated REST helper
│   │   │   └── tfy-version.sh     # SDK/CLI/Python version detection
│   │   └── references/
│   │       ├── api-endpoints.md
│   │       ├── container-versions.md
│   │       ├── deploy-template.py
│   │       ├── sdk-patterns.md
│   │       └── sdk-version-map.md
│   ├── ai-gateway/SKILL.md
│   ├── applications/SKILL.md
│   ├── async-service/SKILL.md
│   ├── deploy/SKILL.md
│   ├── docs/SKILL.md
│   ├── gitops/SKILL.md
│   ├── helm/SKILL.md
│   ├── jobs/SKILL.md
│   ├── llm-benchmarking/SKILL.md
│   ├── llm-deploy/SKILL.md
│   ├── llm-finetuning/SKILL.md
│   ├── logs/SKILL.md
│   ├── mcp-server/SKILL.md
│   ├── multi-service/SKILL.md
│   ├── notebooks/SKILL.md
│   ├── prompts/SKILL.md
│   ├── secrets/SKILL.md
│   ├── ssh-server/SKILL.md
│   ├── status/SKILL.md
│   ├── tfy-apply/SKILL.md
│   ├── volumes/SKILL.md
│   ├── workflows/SKILL.md
│   └── workspaces/SKILL.md
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

## Troubleshooting

### Skills not appearing

- Restart your editor/agent after installation
- Verify skills are installed: `ls ~/.claude/skills/truefoundry-*` (or equivalent for your agent)
- Re-run the install script: `./scripts/install.sh`

### Credentials not working

```bash
# Verify env vars are set
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"

# Test connection
curl -s -H "Authorization: Bearer $TFY_API_KEY" "$TFY_BASE_URL/api/svc/v1/workspaces" | head -c 200
```

### `jq` not installed

The auto-approve hook requires `jq`. Install it:

- **macOS**: `brew install jq`
- **Ubuntu/Debian**: `sudo apt install jq`
- **Fedora/RHEL**: `sudo dnf install jq`

## References

- [TrueFoundry Documentation](https://docs.truefoundry.com)
- [TrueFoundry API Reference](https://docs.truefoundry.com/api-reference)
- [Agent Skills Specification](https://agentskills.io)

## License

MIT
