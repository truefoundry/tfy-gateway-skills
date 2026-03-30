# CLI Detection & Fallback

Standard pattern for detecting the `tfy` CLI and falling back to REST API when unavailable. All deployment skills should reference this file for consistent behavior.

## Detect CLI

```bash
tfy --version 2>/dev/null
```

| Result | Action |
|--------|--------|
| `tfy version X.Y.Z` (>= 0.5.0) | Use `tfy apply -f manifest.yaml` (primary path) |
| `tfy version X.Y.Z` (0.3.x-0.4.x) | Upgrade recommended: install a pinned version (example: `pip install 'truefoundry==0.5.0'`). Core `tfy apply` should still work. |
| `servicefoundry version X.Y.Z` | Legacy CLI. Upgrade to pinned `truefoundry` package (example: `pip install 'truefoundry==0.5.0'`) |
| Command not found | Fall back to REST API (see below) |

## CLI Path (Primary)

```bash
# tfy CLI expects TFY_HOST when TFY_API_KEY is set
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"

# Write manifest to file
cat > tfy-manifest.yaml << 'EOF'
name: my-service
type: service
# ... full manifest ...
workspace_fqn: cluster-id:workspace-name
EOF

# Preview changes before applying
tfy apply -f tfy-manifest.yaml --dry-run --show-diff

# Apply the manifest
tfy apply -f tfy-manifest.yaml
```

Always recommend `--dry-run --show-diff` first so the user can review changes.

## REST API Fallback

When `tfy` CLI is unavailable, convert the YAML manifest to JSON and deploy via REST API.

### Conversion Steps

1. Remove `workspace_fqn` from the manifest body (it becomes a separate parameter)
2. Convert the remaining YAML to JSON -- this becomes the `manifest` object
3. Look up the internal workspace ID from the FQN
4. Send the deploy request

### API Calls

```bash
# 1. Get workspace ID from FQN
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"
# Extract the "id" field from the response

# 2. Deploy (create or update)
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-service",
    "type": "service",
    ... (manifest fields as JSON, without workspace_fqn)
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID_FROM_STEP_1"
}'
```

See `references/rest-api-manifest.md` for complete REST API examples for each deployment type.

### Poll Status After Deploy

```bash
$TFY_API_SH GET "/api/svc/v1/apps?workspaceFqn=${TFY_WORKSPACE_FQN}&applicationName=SERVICE_NAME"
```

## Install CLI

```bash
pip install 'truefoundry==0.5.0'

# New user signup
uv run tfy register

# Existing account: interactive login (recommended — avoids exposing credentials in shell history)
tfy login --host "${TFY_HOST:-${TFY_BASE_URL%/}}"

# Non-interactive login for CI/CD (TFY_API_KEY must be a masked CI secret)
# SECURITY: Avoid running this locally — the API key will appear in shell history.
tfy login --host "${TFY_HOST:-${TFY_BASE_URL%/}}" --api-key "$TFY_API_KEY"
```

For first-time setup, `tfy register` is interactive and may open a browser for CAPTCHA or other human verification. It then guides the user through email verification, returns the tenant URL, and points them to create a PAT. After that, export `TFY_API_KEY` and use the normal CLI or API flows.

## `tfy apply` vs `tfy deploy`

**Critical:** `tfy apply` only supports `image.type: image` (pre-built images). For build sources (local code or git), use `tfy deploy`.

| Situation | Command |
|---|---|
| Pre-built Docker image (`type: image`) | `tfy apply -f manifest.yaml` |
| Local code + Dockerfile (`type: build`, `build_source.type: local`) | `tfy deploy -f truefoundry.yaml --no-wait` |
| Git source + Dockerfile (`type: build`, `build_source.type: git`) | `tfy deploy -f truefoundry.yaml --no-wait` |
| Git source + Buildpack (`type: build`, `build_source.type: git`) | `tfy deploy -f truefoundry.yaml --no-wait` |

> **Note:** `tfy apply` with a `build_source` will fail with "must match exactly one schema in oneOf". Always use `tfy deploy -f` for source-based deployments.

### `tfy deploy` Usage

```bash
# Ensure TFY_HOST is set for CLI auth context
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"

# Deploy from local source or git (builds remotely on TrueFoundry)
tfy deploy -f truefoundry.yaml --no-wait

# The manifest file is typically named truefoundry.yaml for tfy deploy
# It uses the same schema as tfy apply manifests
```

## Decision Flowchart

```
tfy --version
  |
  ├── Found (>= 0.5.0) ──→ tfy apply -f manifest.yaml
  |
  ├── Found (< 0.5.0)  ──→ Suggest upgrade, try tfy apply anyway
  |
  └── Not found ──────────→ REST API via tfy-api.sh
                              └── Convert YAML → JSON
                              └── PUT /api/svc/v1/apps
```
