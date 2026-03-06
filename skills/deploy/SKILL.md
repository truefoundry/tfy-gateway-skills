---
name: deploy
description: Deploys applications to TrueFoundry. Handles single HTTP services, async/queue workers, multi-service projects, and declarative manifest apply. Supports `tfy apply`, `tfy deploy`, docker-compose translation, and CI/CD pipelines. Use when deploying apps, applying manifests, shipping services, or orchestrating multi-service deployments.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
metadata:
  disable-model-invocation: "true"
allowed-tools: Bash(tfy*) Bash(*/tfy-api.sh *) Bash(*/tfy-version.sh *) Bash(docker *) Bash(tfy deploy*)
---

> Routing note: For ambiguous user intents, use the shared clarification templates in [references/intent-clarification.md](references/intent-clarification.md).

# Deploy to TrueFoundry

Route user intent to the right deployment workflow. Load only the references you need.

## Intent Router

| User Intent | Action | Reference |
|---|---|---|
| "deploy", "deploy my app", "ship this" | Single HTTP service | [deploy-service.md](references/deploy-service.md) |
| "tfy apply", "apply manifest", "deploy from yaml" | Declarative manifest apply | [deploy-apply.md](references/deploy-apply.md) |
| "deploy everything", "full stack", docker-compose | Multi-service orchestration | [deploy-multi.md](references/deploy-multi.md) |
| "async service", "queue consumer", "worker" | Async/queue service | [deploy-async.md](references/deploy-async.md) |
| "deploy LLM", "serve model" | Model serving intent (may be ambiguous) | Ask user: dedicated model serving (`llm-deploy`) or generic service deploy (`deploy`) |
| "deploy helm chart" | Helm chart intent | Confirm Helm path and collect chart details, then proceed with `helm` workflow |
| "deploy postgres docker", "dockerized postgres", "deploy redis docker", "database in docker/container" | Containerized database intent | Proceed with `deploy` workflow (do not route to Helm) |
| "deploy database", "deploy postgres", "deploy redis" | Ambiguous infra intent | Ask user: Helm chart (`helm`) or containerized service (`deploy`) |

**Load only the reference file matching the user's intent.** Do not preload all references.

## Prerequisites (All Workflows)

```bash
# 1. Check credentials
grep '^TFY_' .env 2>/dev/null || true
env | grep '^TFY_' 2>/dev/null || true

# 2. Derive TFY_HOST for CLI (MUST run before any tfy command)
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"

# 3. Check CLI
tfy --version 2>/dev/null || echo "Install: pip install truefoundry"

# 4. Check for existing manifests
ls tfy-manifest.yaml truefoundry.yaml 2>/dev/null
```

- `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`).
- **`TFY_HOST` must be set before any `tfy` CLI command.** The export above handles this automatically.
- `TFY_WORKSPACE_FQN` required. **Never auto-pick. Always ask the user.**
- For full credential setup, see `references/prerequisites.md`.

> **WARNING:** Never use `source .env`. The `tfy-api.sh` script handles `.env` parsing automatically. For shell access: `grep KEY .env | cut -d= -f2-`

## Quick Ops (Inline)

### Apply a manifest (most common)

```bash
# tfy CLI expects TFY_HOST when TFY_API_KEY is set
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"

# Preview changes
tfy apply -f tfy-manifest.yaml --dry-run --show-diff

# Apply
tfy apply -f tfy-manifest.yaml
```

### Deploy from source (local code or git)

```bash
# tfy CLI expects TFY_HOST when TFY_API_KEY is set
export TFY_HOST="${TFY_HOST:-${TFY_BASE_URL%/}}"

# tfy deploy builds remotely — use for local code or git sources
tfy deploy -f truefoundry.yaml --no-wait
```

> **`tfy apply` does NOT support `build_source`.** Use `tfy deploy -f` for source-based deployments.

### Minimal service manifest template

```yaml
name: my-service
type: service
image:
  type: image
  image_uri: docker.io/myorg/my-api:v1.0
ports:
  - port: 8000
    expose: true
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
env:
  LOG_LEVEL: info
replicas: 1
workspace_fqn: "WORKSPACE_FQN_HERE"
```

### Check deployment status

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh
bash $TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=SERVICE_NAME'
```

Or use the `applications` skill.

## Post-Deploy Verification (Automatic)

After any successful deploy/apply action, verify deployment status automatically without asking an extra prompt.

Preferred verification path:
1. Use MCP tool call first:
```
tfy_applications_list(filters={"workspace_fqn": "WORKSPACE_FQN", "application_name": "SERVICE_NAME"})
```
2. If MCP tool calls are unavailable, fall back to:
```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh
bash $TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=SERVICE_NAME'
```

Always report the observed status (`BUILDING`, `DEPLOYING`, `RUNNING`, `FAILED`, etc.) in the same response.

### REST API fallback (when CLI unavailable)

See `references/cli-fallback.md` for converting YAML to JSON and deploying via `tfy-api.sh`.

## Auto-Detection: Single vs Multi-Service

**Before creating any manifest, scan the project:**

1. Check for `docker-compose.yml` / `compose.yaml` — if found, likely multi-service
2. Look for multiple `Dockerfile` files across the project
3. Check for service directories with their own dependency files in `services/`, `apps/`, `frontend/`, `backend/`

- **Single service** → Load `references/deploy-service.md`
- **Multiple services** → Load `references/deploy-multi.md`

## Secrets Handling

**Never put sensitive values directly in manifests.** Store them as TrueFoundry secrets and reference with `tfy-secret://` format:

```yaml
env:
  LOG_LEVEL: info                                              # plain text OK
  DB_PASSWORD: tfy-secret://my-org:my-service-secrets:DB_PASSWORD  # sensitive
```

Pattern: `tfy-secret://<TENANT_NAME>:<SECRET_GROUP_NAME>:<SECRET_KEY>` where TENANT_NAME is the subdomain of `TFY_BASE_URL`.

Use the `secrets` skill for guided secret group creation. For the full secrets workflow, see `references/deploy-service.md` (Secrets Handling section).

## Shared References

These references are available for all workflows — load as needed:

| Reference | Contents |
|---|---|
| `manifest-schema.md` | Complete YAML field reference (single source of truth) |
| `manifest-defaults.md` | Per-service-type defaults with YAML templates |
| `cli-fallback.md` | CLI detection and REST API fallback pattern |
| `cluster-discovery.md` | Extract cluster ID, base domains, available GPUs |
| `resource-estimation.md` | CPU, memory, GPU sizing rules of thumb |
| `health-probes.md` | Startup, readiness, liveness probe configuration |
| `gpu-reference.md` | GPU types and VRAM reference |
| `container-versions.md` | Pinned container image versions |
| `prerequisites.md` | Credential setup and .env configuration |
| `rest-api-manifest.md` | Full REST API manifest reference |

## Workflow-Specific References

| Reference | Used By |
|---|---|
| `deploy-api-examples.md` | deploy-service |
| `deploy-errors.md` | deploy-service |
| `deploy-scaling.md` | deploy-service |
| `load-analysis-questions.md` | deploy-service |
| `codebase-analysis.md` | deploy-service |
| `tfy-apply-cicd.md` | deploy-apply |
| `tfy-apply-extra-manifests.md` | deploy-apply |
| `compose-translation.md` | deploy-multi |
| `dependency-graph.md` | deploy-multi |
| `multi-service-errors.md` | deploy-multi |
| `multi-service-patterns.md` | deploy-multi |
| `service-wiring.md` | deploy-multi |
| `async-errors.md` | deploy-async |
| `async-queue-configs.md` | deploy-async |
| `async-python-library.md` | deploy-async |
| `async-sidecar-deploy.md` | deploy-async |

## Composability

- **Find workspace**: Use `workspaces` skill
- **Check what's deployed**: Use `applications` skill
- **View logs**: Use `logs` skill
- **Manage secrets**: Use `secrets` skill
- **Deploy Helm charts**: Use `helm` skill
- **Deploy LLMs**: Use `llm-deploy` skill
- **Test after deploy**: Use `service-test` skill
- **Save preferences**: Use `preferences` skill

## Success Criteria

- User confirmed service name, resources, port, and deployment source before deploying
- Deployment URL and status reported back to the user
- Deployment status verified automatically immediately after apply/deploy (no extra prompt)
- Health probes configured for production deployments
- Secrets stored securely (not hardcoded in manifests)
- For multi-service: all services wired together and working end-to-end
