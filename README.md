# TrueFoundry Agent Skills

Agent skills for [TrueFoundry](https://truefoundry.com) following the [Agent Skills](https://agentskills.io) open format. A curated set of skills that let AI coding assistants deploy, monitor, and manage ML infrastructure.

Works with Claude Code, Cursor, Codex, OpenCode, Windsurf, Cline, and Roo Code.

## Requirements

- Access to a TrueFoundry account/workspace
- `TFY_BASE_URL` and `TFY_API_KEY` credentials
- Any supported coding agent listed above

## Quick Start

Install skills (recommended: pin to a release tag):

```bash
TFY_SKILLS_REF=vX.Y.Z \
curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-agent-skills/main/scripts/install.sh | bash
```

Replace `vX.Y.Z` with a published release tag (for example `v0.1.0`).

Optional: verify the tarball checksum for the pinned release:

```bash
TFY_SKILLS_REF=vX.Y.Z TFY_SKILLS_SHA256=<release-sha256> \
curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-agent-skills/main/scripts/install.sh | bash
```

If you prefer always-latest behavior, omit `TFY_SKILLS_REF` and install from `main`.

Set your credentials (environment variables or `.env` file in your project root):

- `TFY_BASE_URL` — your TrueFoundry platform URL (e.g., `https://your-org.truefoundry.cloud`)
- `TFY_API_KEY` — your API key ([how to generate](https://docs.truefoundry.com/docs/generate-api-key))

Skills auto-detect credentials from environment variables and `.env` files at runtime.

Restart your agent, then ask things like *"deploy my FastAPI app"*, *"show logs for my-service"*, or *"what's deployed?"*

> Keep secrets local only. Do not commit `.env` or API keys to Git.

### Optional: Auto-Approve API Calls (Claude Code only)

By default, Claude Code prompts for approval each time a skill runs `tfy-api.sh`. To auto-approve these calls, copy the hooks into your Claude Code config.

Requirement: `jq` must be installed, because the hook parses JSON tool input.

```bash
jq --version
```

Then install hooks:

```bash
cp -r hooks/ ~/.claude/hooks/
```

This installs a `PreToolUse` hook that validates and auto-approves only `tfy-api.sh` and `tfy-version.sh` commands. It rejects command chaining and shell injection patterns. All other commands still require manual approval.

Example workflow:
1. Ask: `is truefoundry connected?` (uses `status`)
2. Ask: `what clusters and workspaces are available?` (uses `workspaces` — lists clusters first, then workspaces)
3. Ask: `show logs for my-service` (uses `logs`)

## Skills

| Category | Skills |
|----------|--------|
| **Deploy** | [deploy](skills/deploy/SKILL.md), [gitops](skills/gitops/SKILL.md) |
| **LLM & AI** | [llm-deploy](skills/llm-deploy/SKILL.md), [ai-gateway](skills/ai-gateway/SKILL.md), [mcp-servers](skills/mcp-servers/SKILL.md) |
| **Infrastructure** | [helm](skills/helm/SKILL.md), [volumes](skills/volumes/SKILL.md), [secrets](skills/secrets/SKILL.md) |
| **Security** | [guardrails](skills/guardrails/SKILL.md), [access-control](skills/access-control/SKILL.md) |
| **Jobs & Async** | [jobs](skills/jobs/SKILL.md), [workflows](skills/workflows/SKILL.md) |
| **Dev Environments** | [notebooks](skills/notebooks/SKILL.md), [ssh-server](skills/ssh-server/SKILL.md) |
| **Observe & Test** | [logs](skills/logs/SKILL.md), [service-test](skills/service-test/SKILL.md), [applications](skills/applications/SKILL.md), [tracing](skills/tracing/SKILL.md) |
| **Utility** | [status](skills/status/SKILL.md), [workspaces](skills/workspaces/SKILL.md), [prompts](skills/prompts/SKILL.md), [docs](skills/docs/SKILL.md), [preferences](skills/preferences/SKILL.md), [access-tokens](skills/access-tokens/SKILL.md), [ml-repos](skills/ml-repos/SKILL.md) |

Skills are model-invoked — your agent picks the right one from your prompt. Three skills (`deploy`, `helm`, `llm-deploy`) require explicit invocation.

## How It Works

Each skill is a `SKILL.md` with YAML frontmatter + markdown instructions. Execution model is:

- **Primary for simple read/list/status** — use MCP/MTP tool calls first (`tfy_*` tool calls like list workspaces, list apps, list deployments)
- **Primary for deploy/write** — use `tfy` CLI commands (for example `tfy apply`)
- **Fallback** — use bundled `tfy-api.sh` for REST API calls only when tool calls are unavailable or CLI is unavailable / missing a required operation

Both use `TFY_BASE_URL` and `TFY_API_KEY`.

## Development

```bash
# Edit shared files in skills/_shared/, then sync to all skills
./scripts/sync-shared.sh

# Install and restart
./scripts/install.sh
```

Never edit files inside individual skill `scripts/` or `references/` that come from `_shared/`.

## Project Policies

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Support](SUPPORT.md)

## License

MIT
