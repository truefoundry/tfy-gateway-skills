# TrueFoundry Agent Skills

[![CI](https://github.com/truefoundry/tfy-agent-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/truefoundry/tfy-agent-skills/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Agent skills for [TrueFoundry](https://truefoundry.com) AI Gateway following the [Agent Skills](https://agentskills.io) open format. A curated set of skills that let AI coding assistants configure and manage the AI Gateway, agents, monitoring, integrations, guardrails, MCP servers, and prompts.

Works with Claude Code, Cursor, Codex, OpenCode, Windsurf, Cline, and Roo Code.

> Looking for deployment skills (services, jobs, Helm, LLM deploy, etc.)? See [tfy-deployment-agent-skills](https://github.com/truefoundry/tfy-deployment-agent-skills).

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-agent-skills/main/scripts/install.sh | bash
```

Restart your agent and start asking. If credentials are not set, your agent will prompt for them. You can also pre-set them via env vars or a `.env` file in your project root:

```bash
export TFY_BASE_URL=https://your-org.truefoundry.cloud
export TFY_HOST=https://your-org.truefoundry.cloud  # CLI host (same as TFY_BASE_URL)
export TFY_API_KEY=tfy-...  # https://docs.truefoundry.com/docs/generate-api-key
```

Do not commit `.env` files or API keys to Git.

If you do not have a TrueFoundry account yet, sign up first with:

```bash
uv run tfy register
```

`tfy register` is interactive. Depending on the registration server configuration, it may open a browser window for CAPTCHA or other human verification before asking you to finish email verification. After registration completes, open the tenant URL returned by the CLI, create a personal access token there, and then set `TFY_API_KEY` for the skills that use the platform API.

## What You Can Do

Just ask your agent in plain English:

- *"add a new LLM provider to the gateway"*
- *"set up guardrails for PII filtering"*
- *"register an MCP server"*
- *"create a prompt template"*
- *"register an AI agent"*
- *"show me my gateway request costs"*
- *"add an OpenAI provider"*
- *"show logs for my-service"*
- *"set up a secret for my database password"*
- *"what's my connection status?"*

Your agent picks the right skill based on what you ask.

## Skills

| Category | Skills |
|----------|--------|
| **Gateway** | [agents](skills/agents), [ai-gateway](skills/ai-gateway), [ai-monitoring](skills/ai-monitoring), [guardrails](skills/guardrails), [integrations](skills/integrations), [mcp-servers](skills/mcp-servers), [prompts](skills/prompts) |
| **Shared** | [access-control](skills/access-control), [access-tokens](skills/access-tokens), [docs](skills/docs), [logs](skills/logs), [onboarding](skills/onboarding), [secrets](skills/secrets), [status](skills/status), [tracing](skills/tracing), [workspaces](skills/workspaces) |

Each skill is a standalone markdown file (`skills/{name}/SKILL.md`) following the [Agent Skills](https://agentskills.io) open format.

## How It Works

Skills are markdown files with instructions your agent reads at runtime. When you ask a question, your agent matches it to the right skill and follows the instructions — calling TrueFoundry APIs, running CLI commands, or both.

No SDKs to learn, no code to write. Your agent handles everything.

## Development

```bash
# Edit shared files in skills/_shared/, then sync to all skills
./scripts/sync-shared.sh

# Run local validation (including offline security checks)
./scripts/validate-skills.sh
./scripts/validate-skill-security.sh

# Optional: enable pre-push hook so checks run automatically before git push
./scripts/setup-git-hooks.sh

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
