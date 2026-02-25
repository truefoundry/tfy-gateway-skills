# TrueFoundry Skills

Skills for [TrueFoundry](https://truefoundry.com). Manage applications, deployments,
secrets, and infrastructure directly from your AI coding assistant.

## Skills

Skills are model-invoked — the agent decides when to use them based on user intent
matching each skill description. Each skill lives in `skills/{name}/SKILL.md`.

Read `skills/{name}/SKILL.md` for detailed usage, examples, and error handling.

The explicit-only skills are: `deploy`, `helm`, `llm-deploy`, `async-service`, and `multi-service`.

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
- `multi-service`
- `notebooks`
- `preferences`
- `prompts`
- `secrets`
- `service-test`
- `ssh-server`
- `status`
- `tfy-apply`
- `volumes`
- `workflows`
- `workspaces`

## Architecture

Skills are **CLI-first**:

**CLI path** — Prefer `tfy` CLI commands (`tfy apply`, `tfy deploy workflow`, etc.) for
deployment and infrastructure workflows.

**Direct API fallback** — Use `scripts/tfy-api.sh` only when CLI is unavailable or a required operation is not yet exposed in CLI. It reads `TFY_BASE_URL` and `TFY_API_KEY` from env or `.env`.

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
2. Include CLI-first instructions and direct API fallback where needed
3. Reference the `status` skill for preflight checks
4. Run `./scripts/sync-shared.sh` to copy shared files
5. Test locally with `./scripts/install.sh` and reload your agent

## References

- TrueFoundry Documentation: https://docs.truefoundry.com
- TrueFoundry API Reference: https://docs.truefoundry.com/api-reference
- Agent Skills spec: https://agentskills.io
- Claude Code skills: https://code.claude.com/docs/en/skills
- Cursor skills: https://cursor.com/docs/context/skills
