# TrueFoundry Gateway Skills

[![CI](https://github.com/truefoundry/tfy-gateway-skills/actions/workflows/ci.yml/badge.svg)](https://github.com/truefoundry/tfy-gateway-skills/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Markdown skill files that let AI coding agents configure and manage the [TrueFoundry](https://truefoundry.com) AI Gateway. Works with Claude Code, Cursor, Codex, OpenCode, Windsurf, Cline, and Roo Code.

> Looking to deploy workloads? TrueFoundry Enterprise with a connected cluster is required. See [truefoundry.com](https://truefoundry.com).

## Install

```bash
npx skills add truefoundry/tfy-gateway-skills --all
```

`--all` installs all skills for all agents without interactive selection prompts.

Or via curl:

```bash
curl -fsSL https://raw.githubusercontent.com/truefoundry/tfy-gateway-skills/main/scripts/install.sh | bash
```

Restart your agent. If credentials are not set, your agent will prompt for them. You can also pre-set them:

```bash
export TFY_BASE_URL=https://your-org.truefoundry.cloud
export TFY_API_KEY=tfy-...  # https://docs.truefoundry.com/docs/generate-api-key
```

New to TrueFoundry? Run `uv run tfy register` to sign up interactively.

## Skills

| Category | Skills |
|----------|--------|
| **Gateway** | [agents](skills/agents), [ai-gateway](skills/ai-gateway), [ai-monitoring](skills/ai-monitoring), [guardrails](skills/guardrails), [integrations](skills/integrations), [mcp-servers](skills/mcp-servers), [prompts](skills/prompts) |
| **Platform** | [access-control](skills/access-control), [access-tokens](skills/access-tokens), [docs](skills/docs), [logs](skills/logs), [onboarding](skills/onboarding), [secrets](skills/secrets), [status](skills/status), [tracing](skills/tracing), [workspaces](skills/workspaces) |

Just ask your agent in plain English — it picks the right skill automatically.

Installed skill names are namespaced as `truefoundry-<skill>` (for example, `truefoundry-ai-gateway`) to avoid collisions with generic skill names.

## Development

```bash
./scripts/sync-shared.sh              # sync shared files to all skills
./scripts/validate-skills.sh          # validate frontmatter and structure
./scripts/validate-skill-security.sh  # offline security checks
./scripts/install.sh                  # install locally
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT
