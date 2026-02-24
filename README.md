# TrueFoundry Agent Skills

Agent skills for [TrueFoundry](https://truefoundry.com) following the [Agent Skills](https://agentskills.io) open format. 25 skills that let AI coding assistants deploy, monitor, and manage ML infrastructure.

Works with Claude Code, Cursor, Codex, OpenCode, Windsurf, Cline, and Roo Code.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-agent-skills/main/scripts/install.sh | bash
export TFY_BASE_URL="https://your-org.truefoundry.cloud"
export TFY_API_KEY="tfy-..."
```

Restart your agent, then ask things like *"deploy my FastAPI app"*, *"show logs for my-service"*, or *"what's deployed?"*

## Skills

| Category | Skills |
|----------|--------|
| **Deploy** | [deploy](skills/deploy/SKILL.md), [multi-service](skills/multi-service/SKILL.md), [tfy-apply](skills/tfy-apply/SKILL.md), [gitops](skills/gitops/SKILL.md) |
| **LLM & AI** | [llm-deploy](skills/llm-deploy/SKILL.md), [llm-finetuning](skills/llm-finetuning/SKILL.md), [llm-benchmarking](skills/llm-benchmarking/SKILL.md), [ai-gateway](skills/ai-gateway/SKILL.md) |
| **Infrastructure** | [helm](skills/helm/SKILL.md), [volumes](skills/volumes/SKILL.md), [secrets](skills/secrets/SKILL.md) |
| **Jobs & Async** | [jobs](skills/jobs/SKILL.md), [workflows](skills/workflows/SKILL.md), [async-service](skills/async-service/SKILL.md) |
| **Dev Environments** | [notebooks](skills/notebooks/SKILL.md), [ssh-server](skills/ssh-server/SKILL.md), [mcp-server](skills/mcp-server/SKILL.md) |
| **Observe & Test** | [logs](skills/logs/SKILL.md), [service-test](skills/service-test/SKILL.md), [applications](skills/applications/SKILL.md) |
| **Utility** | [status](skills/status/SKILL.md), [workspaces](skills/workspaces/SKILL.md), [prompts](skills/prompts/SKILL.md), [docs](skills/docs/SKILL.md), [preferences](skills/preferences/SKILL.md) |

Skills are model-invoked — your agent picks the right one from your prompt. Five skills (`deploy`, `helm`, `llm-deploy`, `async-service`, `multi-service`) require explicit invocation.

## How It Works

Each skill is a `SKILL.md` with YAML frontmatter + markdown instructions. Skills operate in two modes:

- **Standalone** — bundled `tfy-api.sh` curl wrapper talks to the REST API directly
- **With MCP** — pair with [tfy-mcp-server](https://github.com/truefoundry/tfy-mcp-server) for structured tool calls and no Bash prompts

Both use `TFY_BASE_URL` and `TFY_API_KEY`. Skills auto-detect which mode is available.

## Development

```bash
# Edit shared files in skills/_shared/, then sync to all skills
./scripts/sync-shared.sh

# Install and restart
./scripts/install.sh
```

Never edit files inside individual skill `scripts/` or `references/` that come from `_shared/`.

## License

MIT
