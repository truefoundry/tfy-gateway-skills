# TrueFoundry Agent Skills

[![CI](https://github.com/truefoundry/tfy-agent-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/truefoundry/tfy-agent-skills/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Skills](https://img.shields.io/badge/skills.sh-truefoundry-blue)](https://skills.sh/truefoundry/tfy-agent-skills)

Agent skills for [TrueFoundry](https://truefoundry.com) following the [Agent Skills](https://agentskills.io) open format. A curated set of skills that let AI coding assistants deploy, monitor, and manage ML infrastructure.

Works with Claude Code, Cursor, Codex, OpenCode, Windsurf, Cline, and Roo Code.

## Install

```bash
npx skills add truefoundry/tfy-agent-skills
```

Or use the direct installer:

```bash
curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-agent-skills/main/scripts/install.sh | bash
```

For reproducible installs, set `TFY_SKILLS_REF=vX.Y.Z` before running the installer.

Set your credentials (env vars or `.env` in your project root):

```bash
export TFY_BASE_URL=https://your-org.truefoundry.cloud
export TFY_API_KEY=tfy-...  # https://docs.truefoundry.com/docs/generate-api-key
```

Restart your agent. That's it.

> Do not commit `.env` or API keys to Git.

## What You Can Do

Just ask your agent in plain English:

- *"deploy my FastAPI app"*
- *"show logs for my-service"*
- *"what's deployed?"*
- *"launch a Jupyter notebook with a GPU"*
- *"deploy Postgres with Helm"*
- *"set up a secret for my database password"*

Your agent picks the right skill based on what you ask. For deploy actions, use explicit wording like "deploy", "helm", or "llm deploy".

## Skills

| Category | Skills |
|----------|--------|
| **Deploy** | [deploy](skills/deploy), [gitops](skills/gitops) |
| **LLM & AI** | [llm-deploy](skills/llm-deploy), [ai-gateway](skills/ai-gateway), [mcp-servers](skills/mcp-servers) |
| **Infrastructure** | [helm](skills/helm), [volumes](skills/volumes), [secrets](skills/secrets) |
| **Security** | [guardrails](skills/guardrails), [access-control](skills/access-control) |
| **Jobs & Pipelines** | [jobs](skills/jobs), [workflows](skills/workflows) |
| **Dev Environments** | [notebooks](skills/notebooks), [ssh-server](skills/ssh-server) |
| **Observe & Debug** | [logs](skills/logs), [service-test](skills/service-test), [applications](skills/applications), [tracing](skills/tracing) |
| **Utility** | [status](skills/status), [workspaces](skills/workspaces), [prompts](skills/prompts), [docs](skills/docs), [preferences](skills/preferences), [access-tokens](skills/access-tokens), [ml-repos](skills/ml-repos) |

Each skill is a standalone markdown file (`skills/{name}/SKILL.md`) following the [Agent Skills](https://agentskills.io) open format.

## How It Works

Skills are markdown files with instructions your agent reads at runtime. When you ask a question, your agent matches it to the right skill and follows the instructions — calling TrueFoundry APIs, running CLI commands, or both.

No SDKs to learn, no code to write. Your agent handles everything.

## Development

```bash
# Edit shared files in skills/_shared/, then sync to all skills
./scripts/sync-shared.sh

# Install and restart
./scripts/install.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on adding new skills.

## Community

- [Contributing Guide](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)
- [Support](SUPPORT.md)

## License

MIT
