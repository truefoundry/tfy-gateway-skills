# TrueFoundry Skills

Skills for [TrueFoundry](https://truefoundry.com). Manage applications, deployments,
secrets, and infrastructure directly from your AI coding assistant.

## Skills

Skills are model-invoked — the agent decides when to use them based on user intent
matching each skill description. Each skill lives in `skills/{name}/SKILL.md`.

Read `skills/{name}/SKILL.md` for detailed usage, examples, and error handling.

Exception: `deploy` and `helm` have `disable-model-invocation: true` — they only run when
the user explicitly asks to deploy (never auto-triggered).

Available skills in this repo:
- `ai-gateway`
- `applications`
- `async-service`
- `deploy`
- `docs`
- `gitops`
- `helm`
- `jobs`
- `llm-benchmarking`
- `llm-deploy`
- `llm-finetuning`
- `logs`
- `mcp-server`
- `multi-service`
- `notebooks`
- `prompts`
- `secrets`
- `ssh-server`
- `status`
- `tfy-apply`
- `volumes`
- `workflows`
- `workspaces`

## Architecture

Skills can use either the **MCP server** or **direct API**:

**MCP tools** — When `tfy-mcp-server` is configured in the agent, skills reference MCP
tool names like `tfy_applications_list`, `tfy_workspaces_list`, etc. The agent calls
these tools directly.

**Direct API** — Each skill includes `scripts/tfy-api.sh` for authenticated REST calls
when MCP is not available. It reads `TFY_BASE_URL` and `TFY_API_KEY` from env or `.env`.

**Script path:** Agents usually run commands from the project root, not the skill
directory. Invoke `tfy-api.sh` with a full path or `cd` into the skill directory first.

```bash
# Full path (installed skill example)
~/.codex/skills/truefoundry-workspaces/scripts/tfy-api.sh GET /api/svc/v1/workspaces

# Or from skill directory
cd ~/.codex/skills/truefoundry-workspaces && scripts/tfy-api.sh GET /api/svc/v1/workspaces
```

**TrueFoundry SDK** — The `deploy` skill uses the Python SDK (`truefoundry` package)
for deploying local code. This is separate from MCP and direct API.

## Credentials

All skills need:
- `TFY_BASE_URL` — TrueFoundry platform URL
- `TFY_API_KEY` — API key (raw, no Bearer prefix)

For deploy:
- `TFY_WORKSPACE_FQN` — required, never auto-picked

Set via env vars, `.env` file, or MCP server headers.

## Composability

Common flows:

- Deploy flow: `status` -> `workspaces` (find FQN) -> `deploy` -> `applications` (verify)
- Infra flow: `status` -> `workspaces` (find FQN) -> `helm` (deploy database/redis) -> `applications` (verify)
- Debug flow: `applications` -> `logs` (check output)
- Setup flow: `status` -> `secrets` (create groups) -> `deploy`

## Shared Files

Scripts and references are shared across skills. Canonical versions live in
`skills/_shared/`. Each skill has its own copy for portability.

**Do not edit files in individual skill `scripts/` or `references/` directories.**
Edit canonical files in `_shared/`, then run:

```bash
./scripts/sync-shared.sh
```

Shared files:
- `skills/_shared/scripts/tfy-api.sh` — REST API helper
- `skills/_shared/references/api-endpoints.md` — Endpoint reference
- `skills/_shared/references/deploy-template.py` — Deploy script template
- `skills/_shared/references/sdk-patterns.md` — SDK usage patterns

## Adding New Skills

1. Create `skills/{name}/SKILL.md` with YAML frontmatter
2. Include both MCP and direct API instructions
3. Reference the `status` skill for preflight checks
4. Run `./scripts/sync-shared.sh` to copy shared files
5. Test locally with `./scripts/install.sh` and reload your agent

## References

- TrueFoundry Documentation: https://docs.truefoundry.com
- TrueFoundry API Reference: https://docs.truefoundry.com/api-reference
- Agent Skills spec: https://agentskills.io
- Claude Code skills: https://code.claude.com/docs/en/skills
- Cursor skills: https://cursor.com/docs/context/skills
