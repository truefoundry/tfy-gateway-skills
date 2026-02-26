# TrueFoundry Agent Skills

Agent skills for [TrueFoundry](https://truefoundry.com) following the [Agent Skills](https://agentskills.io) open format. 27 skills that let AI coding assistants deploy, monitor, and manage ML infrastructure.

Works with Claude Code, Cursor, Codex, OpenCode, Windsurf, Cline, and Roo Code.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-agent-skills/main/scripts/install.sh | bash
export TFY_BASE_URL="https://your-org.truefoundry.cloud"
export TFY_API_KEY="tfy-..."
export TFY_CLUSTER_FQN="tfy-..."
```

Keep secrets local only. Do not commit `.env` or API keys to Git.

Restart your agent, then ask things like *"deploy my FastAPI app"*, *"show logs for my-service"*, or *"what's deployed?"*

Example workflow:
1. Ask: `is truefoundry connected?` (uses `status`)
2. Ask: `what workspaces are available?` (uses `workspaces`)
3. Ask: `show logs for my-service` (uses `logs`)

## Skills

| Category | Skills |
|----------|--------|
| **Deploy** | [deploy](skills/deploy/SKILL.md), [multi-service](skills/multi-service/SKILL.md), [tfy-apply](skills/tfy-apply/SKILL.md), [gitops](skills/gitops/SKILL.md) |
| **LLM & AI** | [llm-deploy](skills/llm-deploy/SKILL.md), [ai-gateway](skills/ai-gateway/SKILL.md) |
| **Infrastructure** | [helm](skills/helm/SKILL.md), [volumes](skills/volumes/SKILL.md), [secrets](skills/secrets/SKILL.md) |
| **Jobs & Async** | [jobs](skills/jobs/SKILL.md), [workflows](skills/workflows/SKILL.md), [async-service](skills/async-service/SKILL.md) |
| **Dev Environments** | [notebooks](skills/notebooks/SKILL.md), [ssh-server](skills/ssh-server/SKILL.md) |
| **Observe & Test** | [logs](skills/logs/SKILL.md), [service-test](skills/service-test/SKILL.md), [applications](skills/applications/SKILL.md), [tracing](skills/tracing/SKILL.md) |
| **Utility** | [status](skills/status/SKILL.md), [workspaces](skills/workspaces/SKILL.md), [prompts](skills/prompts/SKILL.md), [docs](skills/docs/SKILL.md), [preferences](skills/preferences/SKILL.md), [access-tokens](skills/access-tokens/SKILL.md), [ml-repos](skills/ml-repos/SKILL.md) |

Skills are model-invoked — your agent picks the right one from your prompt. Five skills (`deploy`, `helm`, `llm-deploy`, `async-service`, `multi-service`) require explicit invocation.

## How It Works

Each skill is a `SKILL.md` with YAML frontmatter + markdown instructions. Execution model is CLI-first:

- **Primary** — use `tfy` CLI commands (for example `tfy apply`) for deployment and management flows
- **Fallback** — use bundled `tfy-api.sh` for REST API calls only when CLI is unavailable or missing a required operation

Both use `TFY_BASE_URL` and `TFY_API_KEY`.

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
