# Prerequisites

## Step 0: CLI Check

Check if the TrueFoundry CLI is available:

```bash
tfy --version 2>/dev/null
```

If not found, install it:

```bash
pip install truefoundry && tfy login --host "$TFY_BASE_URL"
```

> **Note:** The CLI (`tfy apply`) is the recommended deployment method, but it is not strictly required. All skills fall back to the REST API via `tfy-api.sh` when the CLI is unavailable.

## Credential Check

Run this to verify your environment:

```bash
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
echo "TFY_WORKSPACE_FQN: ${TFY_WORKSPACE_FQN:-(not set)}"
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `TFY_BASE_URL` | Yes | TrueFoundry platform URL (e.g., `https://your-org.truefoundry.cloud`) |
| `TFY_API_KEY` | Yes | API key for authentication |
| `TFY_WORKSPACE_FQN` | For deploys | Workspace fully qualified name (e.g., `cluster-id:workspace-name`) |

### Variable Name Aliases

Different tools use different variable names. The `tfy-api.sh` script auto-resolves these:

| Canonical (used by scripts) | Alias (CLI) | Alias (.env files) | Notes |
|---|---|---|---|
| `TFY_BASE_URL` | `TFY_HOST` | `TFY_API_HOST` | `tfy-api.sh` checks all three in order |
| `TFY_API_KEY` | -- | -- | Same name everywhere |

If your `.env` uses `TFY_HOST` or `TFY_API_HOST`, the scripts will pick it up automatically. No manual renaming needed.

## Workspace FQN Rule

**Never auto-pick a workspace.** Always ask the user.

Users may have access to multiple workspaces across clusters, and deploying to the wrong one can be disruptive. If `TFY_WORKSPACE_FQN` is not set, STOP and ask the user. Suggest using the `workspaces` skill or the TrueFoundry dashboard.

## .env File

Skills look for credentials in environment variables first, then fall back to `.env` in the working directory. The `tfy-api.sh` script handles this automatically.

## Generating API Keys

Visit `{TFY_BASE_URL}/settings` → API Keys → Generate New Key.

See: [API Keys](https://docs.truefoundry.com/docs/generate-api-key)
