# Prerequisites

## Step 0: CLI Check

Check if the TrueFoundry CLI is available:

```bash
tfy --version 2>/dev/null
```

If `TFY_API_KEY` is set and you use `tfy` CLI commands (`tfy apply`, `tfy deploy`), ensure `TFY_HOST` is set:

```bash
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"
```

If not found, install it:

```bash
pip install 'truefoundry==0.5.0'
```

> **Note:** The CLI (`tfy apply`) is the recommended deployment method, but it is not strictly required. All skills fall back to the REST API via `tfy-api.sh` when the CLI is unavailable.

If the user does not have a TrueFoundry account yet, onboard with:

```bash
uv run tfy register
```

That flow is interactive and may require a browser-based CAPTCHA or human-verification step before email verification. It then returns the tenant URL and tells the user where to create a PAT. After the PAT is created, set `TFY_API_KEY` and continue with the skills below.

## Credential Check

Run this to verify your environment:

```bash
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_HOST: ${TFY_HOST:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
echo "TFY_WORKSPACE_FQN: ${TFY_WORKSPACE_FQN:-(not set)}"
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TFY_BASE_URL` | Yes | TrueFoundry platform URL (e.g., `https://your-org.truefoundry.cloud`) |
| `TFY_HOST` | For CLI auth/deploy with API key | CLI host URL (usually same as `TFY_BASE_URL`, no trailing slash) |
| `TFY_API_KEY` | Yes | API key for authentication |
| `TFY_WORKSPACE_FQN` | For deploys | Workspace fully qualified name (e.g., `cluster-id:workspace-name`) |

### Variable Name Aliases

Different tools use different variable names. The `tfy-api.sh` script auto-resolves these:

| Canonical (used by scripts) | Alias (CLI) | Alias (.env files) | Notes |
|---|---|---|---|
| `TFY_BASE_URL` | `TFY_HOST` | `TFY_API_HOST` | `tfy-api.sh` checks all three in order |
| `TFY_API_KEY` | -- | -- | Same name everywhere |

If your `.env` uses `TFY_HOST` or `TFY_API_HOST`, the scripts will pick it up automatically. No manual renaming needed.

If your `.env` only has `TFY_BASE_URL`, derive CLI host before running `tfy deploy`/`tfy apply`:

```bash
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"
```

## Workspace FQN Rule — MANDATORY

> **HARD RULE: Never auto-pick a workspace. Never silently select a workspace. Always ask the user to confirm, even if there is only one workspace available.**

Deploying to the wrong workspace can be disruptive and hard to reverse. You MUST follow this flow:

1. **If `TFY_WORKSPACE_FQN` is set in the environment** — confirm with the user: "I see workspace `X` in your environment. Should I deploy there?"
2. **If only one workspace is returned by the API** — still confirm: "You have access to workspace `X`. Should I deploy there?"
4. **If multiple workspaces exist** — present the list and ask the user to choose.
5. **If no workspace is found** — STOP and ask. Suggest using the `workspaces` skill or the TrueFoundry dashboard.

**Do NOT skip confirmation even when the choice seems obvious.** The user must explicitly approve the target workspace before any manifest is created or deployment is started.

## .env File

Skills look for credentials in environment variables first, then fall back to `.env` in the working directory. The `tfy-api.sh` script handles this automatically.

## Generating API Keys

If the user is brand new, run `uv run tfy register` first, complete any browser-based CAPTCHA or human verification it asks for, and finish email verification.

Then visit the tenant URL returned by the CLI and go to `Settings` → `API Keys` → `Generate New Key`.

See: [API Keys](https://docs.truefoundry.com/docs/generate-api-key)
