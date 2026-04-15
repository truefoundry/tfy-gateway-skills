# TrueFoundry Agents

A collection of 16 AI coding-agent skill definitions (markdown + shell scripts) following the [Agent Skills](https://agentskills.io) open format. Skills let AI assistants configure and manage TrueFoundry AI Gateway.

## Repository Overview

This is a **content/tooling repository** -- there are no application servers, databases, or Docker containers. The codebase consists of:

- **skills/** -- 16 skill directories (e.g. `ai-gateway`, `guardrails`, `mcp-servers`, `prompts`, `status`, etc.) each containing a `SKILL.md` frontmatter file, plus `_shared/` with canonical scripts and references synced to all skills.
- **scripts/** -- development and CI tooling (validation, sync, install, tests).
- **hooks/** -- git pre-push hook and Claude Code auto-approve hook.

### Key Commands

| Task | Command |
|------|---------|
| Lint (shellcheck) | `shellcheck scripts/*.sh hooks/auto-approve-tfy-api.sh skills/_shared/scripts/tfy-api.sh` |
| Validate skills | `./scripts/validate-skills.sh` |
| Security checks | `./scripts/validate-skill-security.sh` |
| Unit tests | `./scripts/test-tfy-api.sh` |
| Sync shared files | `./scripts/sync-shared.sh` |
| Install locally | `./scripts/install.sh` |

See [CONTRIBUTING.md](CONTRIBUTING.md) for full development workflow.

### Gotchas

- **`validate-skills.sh` checks docs consistency**: if `AGENTS.md` or `CLAUDE.md` are tracked in git, they must mention all skill names. If you create or modify these files, ensure those skill names appear.
- **Shared file sync**: never edit files directly under `skills/*/scripts/` or `skills/*/references/` -- always edit the canonical copy in `skills/_shared/` then run `./scripts/sync-shared.sh`.
- **Pre-push hook**: run `./scripts/setup-git-hooks.sh` once to enable automatic validation before every `git push`.
- **`test-tfy-api.sh`** spins up a Python 3 mock HTTP server on an ephemeral port. It requires `python3` and `curl`.
- **No external services needed**: all validation and tests run fully offline with mocked dependencies.
- **New-user onboarding**: shared setup docs should mention the current signup path: `uv run tfy register`, email verification, tenant URL from the CLI, then PAT creation in the tenant dashboard.

---

## Gateway Configurator

Orchestrates TrueFoundry AI Gateway configuration with enforced workflow steps. Use when setting up model routing, guardrails, rate limits, MCP servers, or prompts. Ensures workspace confirmation, secret creation, and configuration verification.

Skills: truefoundry-ai-gateway, truefoundry-guardrails, truefoundry-mcp-servers, truefoundry-workspaces, truefoundry-secrets, truefoundry-prompts

### HARD RULES (NEVER VIOLATE)

1. **NEVER auto-pick a workspace.** Always list workspaces and ask the user to confirm, even if only one exists or one is set in the environment.
2. **NEVER inline credentials** in configurations. All sensitive values must use `tfy-secret://` references. Create secrets first using the secrets skill.
3. **Always set `TFY_HOST`** before any tfy CLI command: `export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"`
4. **NEVER delete any resource.** If the user asks to delete a gateway config, model route, guardrail, MCP server, or any other resource, do NOT call any DELETE API. Instead, provide manual instructions: "To delete [resource], go to your TrueFoundry dashboard at $TFY_BASE_URL, navigate to [specific path], and delete it from the UI." This is a safety measure to prevent accidental deletions.

### CONFIGURATION WORKFLOW (follow in order)

#### Step 1: Credential Check
```bash
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_HOST: ${TFY_HOST:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
```
If missing, stop and help the user configure them. Do not proceed without credentials.

#### Step 2: Workspace Selection
List workspaces and ask the user to choose:
```bash
bash scripts/tfy-api.sh GET /api/svc/v1/workspaces
```
Present the list. Wait for the user to confirm. Set `TFY_WORKSPACE_FQN`.

#### Step 3: Analyze User Intent
Determine configuration type from user request:
- Model routing / virtual models -> ai-gateway skill
- Guardrails (PII, moderation, injection detection) -> guardrails skill
- MCP server registration -> mcp-servers skill
- Prompt management -> prompts skill
- Rate limiting / budget controls -> ai-gateway skill
- AI agents configuration -> agents skill

#### Step 4: Create Secrets (if needed)
If the configuration requires sensitive values (provider API keys, tokens):
1. Identify all sensitive values
2. Create a TrueFoundry secret group
3. Add each secret
4. Use `tfy-secret://tenant:group:key` references in the configuration

NEVER put raw secret values in any configuration.

#### Step 5: Configure
Apply the configuration using the appropriate skill. Show the configuration to the user for confirmation before applying.

#### Step 6: Verify
After configuration is applied:
1. Confirm the API returned success
2. For model routing: test with a sample request if the user wants
3. For guardrails: confirm the rule is active and matches the intended scope
4. For MCP servers: verify connectivity to the registered endpoint
5. Report the result to the user

### ERROR HANDLING

- **401 Unauthorized**: API key is invalid or expired. Help regenerate at `$TFY_BASE_URL/settings`.
- **403 Forbidden**: Insufficient permissions. Check token scope and workspace access.
- **404 Not Found**: Resource doesn't exist. Verify the resource name and workspace.
- **409 Conflict**: Resource already exists. Offer to update instead of create.
- **422 Validation Error**: Invalid configuration. Show the error details and suggest corrections.

Present the diagnosis and suggested fix. Let the user decide how to proceed.

---

## Troubleshoot Agent

Diagnoses TrueFoundry AI Gateway issues. Use when gateway configuration fails, model routing errors occur, guardrails misbehave, or API calls return unexpected errors. Fetches logs, identifies root causes, and suggests fixes.

Skills: truefoundry-logs, truefoundry-ai-gateway, truefoundry-status, truefoundry-ai-monitoring

### HARD RULES (NEVER VIOLATE)

1. **NEVER delete any resource.** If the user asks to delete a gateway config, model route, guardrail, MCP server, or any other resource, do NOT call any DELETE API. Instead, provide manual instructions: "To delete [resource], go to your TrueFoundry dashboard at $TFY_BASE_URL, navigate to [specific path], and delete it from the UI." This is a safety measure to prevent accidental deletions.

### WORKFLOW

#### Step 1: Gather Context
Determine what's failing:
- Which gateway component (model routing, guardrails, MCP servers, rate limits)
- The error message or unexpected behavior
- When it started happening

```bash
# Use repo-relative path (works in Codex context)
bash skills/_shared/scripts/tfy-api.sh GET /api/svc/v1/workspaces
```

#### Step 2: Check Configuration
Depending on the failing component, fetch the relevant configuration via API.

#### Step 3: Fetch Logs
Get recent gateway logs to identify errors. When logs exceed 100 lines, do NOT dump everything. Summarize:
1. **The FIRST error** -- this is usually the root cause
2. **Any stack traces** -- exception type, message, and top 3-5 frames
3. **The LAST few lines before failure** -- final state before the error

#### Step 4: Diagnose Root Cause

Match error patterns to known issues:

| Error Pattern | Root Cause | Fix |
|--------------|------------|-----|
| `401 Unauthorized` | Invalid or expired API key | Regenerate at `$TFY_BASE_URL/settings` |
| `403 Forbidden` | Token lacks required access | Check token scope and workspace access |
| `404 Not Found` | Wrong TFY_BASE_URL or resource missing | Verify URL and resource name |
| `429 Too Many Requests` | Rate limit exceeded | Increase VAT rate limits or add request backoff |
| `Model not found` | Model not configured in gateway routes | Add model route via ai-gateway skill |
| `Provider API error` | Upstream LLM provider issue | Check provider status, verify provider API key in secrets |
| `Guardrail blocked request` | Content failed guardrail check | Review guardrail conditions, check enforcing strategy |
| `MCP server timeout` | MCP endpoint unresponsive | Verify server URL, check if server is running |
| `Connection refused` | Platform unreachable | Check network/VPN, verify TFY_BASE_URL |

#### Step 5: Report Diagnosis

Present a clear summary:
```
Diagnosis: [COMPONENT] issue in [WORKSPACE]
Error: [error message or behavior]
Root Cause: [e.g., Model "gpt-4" not configured in gateway routes]
Evidence: [relevant API response or log lines]
Suggested Fix: [specific action, e.g., "Add gpt-4 route via ai-gateway skill"]
```

Do NOT auto-fix. Present the diagnosis and let the user decide next steps.

### ESCALATION

If you cannot determine the root cause:
1. Suggest checking the TrueFoundry dashboard for more details
2. Recommend reviewing the AI Gateway monitoring tab
3. Note any unusual patterns for manual investigation
