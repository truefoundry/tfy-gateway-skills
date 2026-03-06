# TrueFoundry Skills

Skills for [TrueFoundry](https://truefoundry.com). Manage applications, deployments,
secrets, and infrastructure directly from your AI coding assistant.

## Skills

Skills are model-invoked — the agent decides when to use them based on user intent
matching each skill description. Each skill lives in `skills/{name}/SKILL.md`.

Read `skills/{name}/SKILL.md` for detailed usage, examples, and error handling.

The explicit-only skills are: `deploy`, `helm`, and `llm-deploy`.
If intent is ambiguous, ask a short clarifying question before selecting one.

Available skills in this repo:
- `access-control`
- `access-tokens`
- `ai-gateway`
- `applications`
- `deploy`
- `docs`
- `gitops`
- `guardrails`
- `helm`
- `jobs`
- `llm-deploy`
- `logs`
- `mcp-servers`
- `ml-repos`
- `notebooks`
- `preferences`
- `prompts`
- `secrets`
- `service-test`
- `ssh-server`
- `status`
- `tracing`
- `volumes`
- `workflows`
- `workspaces`

## Architecture

Execution order is:

1. **MCP tool-call path (preferred for simple read operations)** -- For list/get/status calls (for example workspaces, clusters, applications, deployments, logs), invoke tool calls first.
2. **CLI path (preferred for deploy/write operations)** -- Use `tfy` CLI commands (`tfy apply`, `tfy deploy workflow`, etc.) for deployment and infrastructure changes.
3. **Direct API fallback** -- Use `scripts/tfy-api.sh` only when the tool-call path is unavailable or CLI is unavailable / missing the required operation. It reads `TFY_BASE_URL` and `TFY_API_KEY` from env or `.env`.

If the MCP server is not configured or the tool call is unavailable, do not fail the task -- fall back automatically.

**Script path:** Agents usually run commands from the project root, not the skill
directory. Invoke `tfy-api.sh` with a full path or `cd` into the skill directory first.

```bash
# Full path (installed skill example)
~/.codex/skills/truefoundry-workspaces/scripts/tfy-api.sh GET /api/svc/v1/workspaces

# Or from skill directory
cd ~/.codex/skills/truefoundry-workspaces && scripts/tfy-api.sh GET /api/svc/v1/workspaces
```

**TrueFoundry SDK** — The `deploy` skill uses the Python SDK (`truefoundry` package)
for deploying local code. This is separate from the `tfy` CLI and REST fallback flow.

## Credentials

All skills need:
- `TFY_BASE_URL` — TrueFoundry platform URL
- `TFY_API_KEY` — API key (raw, no Bearer prefix)

For deploy:
- `TFY_WORKSPACE_FQN` — required, never auto-picked

Set via env vars or `.env` file.

## Composability

Common flows:

- Deploy flow: `status` -> `workspaces` (pick cluster, then workspace FQN) -> `deploy` -> `applications` (verify)
- Infra flow: `status` -> `workspaces` (pick cluster, then workspace FQN) -> choose method (`helm` chart or `deploy` containerized service) -> `applications` (verify)
- Debug flow: `applications` -> `logs` (check output)
- Setup flow: `status` -> `secrets` (create groups) -> `deploy`
- Access control flow: `status` -> `access-control` (create roles/teams) -> `deploy`/`mcp-servers`/`secrets` (assign collaborators)
- MCP flow: `status` -> `workspaces` -> `mcp-servers` (register servers) -> `guardrails` (add safety rules)

## Ambiguous Intents

Do not hard-route requests that can map to multiple valid deployment strategies.

For example, "deploy Postgres" can mean:
- Helm chart infrastructure deployment (`helm` skill)
- Containerized service deployment (`deploy` skill, prebuilt image or source build)

Routing rule:
- If the user explicitly says `docker`, `container`, `image`, or `dockerfile`, choose the containerized `deploy` path.
- If the user explicitly says `helm` or `chart`, choose the `helm` path.
- If neither is specified, ask one short clarifying question and proceed with the user's choice.

## Post-Deploy Verification

Deployment verification is mandatory and automatic:
- After every deploy/apply action, immediately perform at least one status check.
- Do this without asking an extra "should I verify?" prompt.
- Prefer MCP read tool calls for verification; fall back to CLI/API when unavailable.

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
- `skills/_shared/references/manifest-schema.md` — Complete manifest schema reference
- `skills/_shared/references/manifest-defaults.md` — Default values and templates
- `skills/_shared/references/intent-clarification.md` — Reusable clarification prompts for ambiguous intents

## Adding New Skills

1. Create `skills/{name}/SKILL.md` with YAML frontmatter
2. Include MCP-first read/list instructions, CLI guidance for deploy/write, and direct API fallback where needed
3. Reference the `status` skill for preflight checks
4. Run `./scripts/sync-shared.sh` to copy shared files
5. Test locally with `./scripts/install.sh` and reload your agent

## References

- TrueFoundry Documentation: https://docs.truefoundry.com
- TrueFoundry API Reference: https://docs.truefoundry.com/api-reference
- Agent Skills spec: https://agentskills.io
- Claude Code skills: https://code.claude.com/docs/en/skills
- Cursor skills: https://cursor.com/docs/context/skills
