# Contributing to TrueFoundry Agent Skills

Thank you for your interest in contributing! This guide covers how to add new skills, modify existing ones, and submit changes.

## Quick Start

```bash
# Clone the repo
git clone https://github.com/truefoundry/tfy-gateway-skills.git
cd tfy-gateway-skills

# Install skills locally
./scripts/install.sh

# After editing shared files, sync to all skills
./scripts/sync-shared.sh
```

## Adding a New Skill

1. **Create the skill directory and file:**
   ```
   skills/{name}/SKILL.md
   ```

2. **Add YAML frontmatter:**
   ```yaml
   ---
   name: my-skill
   description: Trigger phrases for when the agent should use this skill.
   allowed-tools: Bash(*/tfy-api.sh *)
   ---
   ```
   - `description` controls auto-invocation — include the phrases users would say

3. **Use CLI-first instructions with Direct API fallback.** Every skill should work when CLI is available, with API fallback when needed.

4. **Reference shared files** instead of duplicating content:
   - `references/prerequisites.md` — credential checks, env vars
   - `references/tfy-api-setup.md` — agent path table for tfy-api.sh
   - `references/gpu-reference.md` — GPU types and sizing
   - `references/cluster-discovery.md` — cluster ID, base domains, storage classes
   - `references/health-probes.md` — probe configuration
   - `references/resource-estimation.md` — CPU/memory/replica sizing

5. **Reference the `status` skill** for preflight checks.

6. **Add the skill name to the `SKILL_NAMES` array** in `scripts/install.sh`.

7. **Sync and test:**
   ```bash
   ./scripts/sync-shared.sh
   ./scripts/install.sh
   ```

## Modifying Shared Files

Shared files live in `skills/_shared/`. **Never edit files in individual skill `scripts/` or `references/` directories** — those are copies.

1. Edit the canonical file in `skills/_shared/`
2. Run `./scripts/sync-shared.sh` to propagate
3. Test with `./scripts/install.sh`

## Skill Structure

Every skill should have:

- **When to Use** — clear triggers for invocation
- **When NOT to Use** — redirect to the correct skill
- **Prerequisites** — what's needed before the skill runs (reference `prerequisites.md`)
- **API instructions** — CLI-first flow and direct API fallback via `tfy-api.sh`
- **Error handling** — common errors and how to resolve them
- **Composability** — links to related skills

## Code Style

- **Shell scripts**: Must pass `shellcheck` (CI enforces this)
- **Markdown**: Use ATX headings (`##`), fenced code blocks with language tags
- **Frontmatter**: Follow the [Agent Skills](https://agentskills.io) spec
- **Line length**: No hard limit, but keep tables readable

## Testing

Before submitting a PR:

1. Run `shellcheck` on any modified shell scripts:
   ```bash
   shellcheck scripts/*.sh hooks/auto-approve-tfy-api.sh skills/_shared/scripts/*.sh
   ```

2. Run validation and failure-mode tests:
   ```bash
   ./scripts/validate-skills.sh
   ./scripts/validate-skill-security.sh
   ./scripts/test-tfy-api.sh
   ```

3. (Optional but recommended) Enable local pre-push checks once:
   ```bash
   ./scripts/setup-git-hooks.sh
   ```
   This installs a git pre-push hook that runs both `validate-skills.sh` and
   `validate-skill-security.sh --changed` before every push.

4. Run the installer to verify skills install correctly:
   ```bash
   ./scripts/install.sh
   ```

5. Spot-check modified skills by reading them end-to-end for coherence.

## Submitting Changes

1. Fork the repo and create a feature branch
2. Make your changes following the guidelines above
3. Run `sync-shared.sh` if you modified anything in `_shared/`
4. Open a pull request with:
   - Summary of what changed and why
   - Which skills are affected
   - How you tested the changes
5. Keep PRs focused and small enough to review quickly.

## Key Rules

- **Never auto-pick `TFY_WORKSPACE_FQN`** — always ask the user
- **Keep decision logic inline** in skills — only extract lookup tables and boilerplate to shared refs
- **Don't hardcode environment-specific values** in examples — use placeholders or env vars
- **Never commit secrets** (`.env`, API keys, tokens) — use `.env.example` placeholders only
- **CLI-first and API fallback paths** must be documented in every skill that makes API calls

## Questions?

- Open an issue at https://github.com/truefoundry/tfy-gateway-skills/issues
- See [AGENTS.md](AGENTS.md) for agent-specific documentation
- See [SUPPORT.md](SUPPORT.md) for troubleshooting guidance
