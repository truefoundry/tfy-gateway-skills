---
name: notebooks
description: This skill should be used when the user asks "launch a notebook", "deploy jupyter", "start a notebook", "jupyter notebook", "create notebook", "notebook for development", "start jupyterlab", "GPU notebook", "notebook with GPU", "data exploration environment", "ML development environment", "run jupyter on cloud", or wants to run Jupyter notebooks on TrueFoundry infrastructure.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Jupyter Notebooks

Launch Jupyter Notebooks on TrueFoundry with GPU support, persistent storage, auto-shutdown, and VS Code integration.

## When to Use

- User asks "launch a notebook", "start jupyter", "create notebook"
- User needs a development environment with GPU access
- User wants to explore data or prototype ML models
- User asks about notebook images, auto-shutdown, or persistent storage

## When NOT to Use

- User wants to deploy a production service → use `deploy` skill
- User wants to deploy a model → use `llm-deploy` skill
- User wants an SSH server → use `ssh-server` skill

</objective>

<instructions>

## Launch Notebook via UI

The fastest way is through the TrueFoundry dashboard:
1. Go to **Deployments → New Deployment → Jupyter Notebook**
2. Select workspace and configure resources
3. Click Deploy

## Launch Notebook via API

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

### Create Notebook

```bash
TFY_API_SH=~/.claude/skills/truefoundry-notebooks/scripts/tfy-api.sh

$TFY_API_SH POST /api/svc/v1/applications -d '{
  "name": "my-notebook",
  "type": "notebook",
  "workspace_fqn": "WORKSPACE_FQN",
  "manifest": {
    "name": "my-notebook",
    "components": {
      "image": {
        "type": "image",
        "image_uri": "public.ecr.aws/truefoundrycloud/jupyter:0.4.6-py3.11.14-sudo"
      },
      "resources": {
        "cpu_request": 2,
        "cpu_limit": 4,
        "memory_request": 4000,
        "memory_limit": 8000,
        "ephemeral_storage_request": 5000,
        "ephemeral_storage_limit": 10000,
        "storage": 20000
      },
      "auto_shutdown": {
        "wait_time": 30
      }
    }
  }
}'
```

### GPU Notebook

```bash
$TFY_API_SH POST /api/svc/v1/applications -d '{
  "name": "gpu-notebook",
  "type": "notebook",
  "workspace_fqn": "WORKSPACE_FQN",
  "manifest": {
    "name": "gpu-notebook",
    "components": {
      "image": {
        "type": "image",
        "image_uri": "public.ecr.aws/truefoundrycloud/jupyter:0.4.6-cu129-py3.11.14-sudo"
      },
      "resources": {
        "cpu_request": 4,
        "cpu_limit": 8,
        "memory_request": 16000,
        "memory_limit": 32000,
        "ephemeral_storage_request": 10000,
        "ephemeral_storage_limit": 20000,
        "storage": 50000,
        "devices": [
          {"type": "nvidia_gpu", "name": "T4", "count": 1}
        ]
      },
      "auto_shutdown": {
        "wait_time": 60
      }
    }
  }
}'
```

## Available Base Images

| Image | Python | CUDA | Size |
|-------|--------|------|------|
| `public.ecr.aws/truefoundrycloud/jupyter:0.4.6-py3.12.12-sudo` | 3.12 | No | ~0.9 GB |
| `public.ecr.aws/truefoundrycloud/jupyter:0.4.6-py3.11.14-sudo` | 3.11 | No | ~0.9 GB |
| `public.ecr.aws/truefoundrycloud/jupyter:0.4.6-py3.10.19-sudo` | 3.10 | No | ~0.9 GB |
| `public.ecr.aws/truefoundrycloud/jupyter:0.4.6-cu129-py3.12.12-sudo` | 3.12 | 12.9 | ~7 GB |
| `public.ecr.aws/truefoundrycloud/jupyter:0.4.6-cu129-py3.11.14-sudo` | 3.11 | 12.9 | ~7 GB |
| `public.ecr.aws/truefoundrycloud/jupyter:0.4.6-cu129-py3.10.19-sudo` | 3.10 | 12.9 | ~7 GB |

**Full image registry**: https://gallery.ecr.aws/truefoundrycloud/jupyter

### Choosing an Image

- **No GPU needed**: Use the minimal image (`py3.11.14-sudo`)
- **GPU workloads**: Use CUDA image (`cu129-py3.11.14-sudo`)
- **Custom packages**: Build a custom image (see below)

## Auto-Shutdown (Scale-to-Zero)

Notebooks auto-stop after inactivity to save costs. Default: 30 minutes.

Configure `wait_time` in minutes in the `auto_shutdown` section.

**What counts as activity**: Active Jupyter sessions, running cells, terminal sessions.
**What doesn't count**: Background processes, idle kernels.

## Persistent Storage

- **Home directory** (`/home/jovyan/`) persists across restarts
- **APT packages** installed via `apt` do NOT persist — use Build Scripts
- **Pip packages** installed in home directory persist
- **Conda environments** persist

### Recommended Storage by Use Case

| Use Case | Storage (MB) | Notes |
|----------|-------------|-------|
| Light exploration | 10000 | Basic data analysis |
| ML development | 20000-50000 | Models + datasets |
| Large datasets | 50000-100000 | Attach volumes for more |
| LLM experimentation | 100000+ | Use volumes for model weights |

## Custom Images

Extend TrueFoundry base images to pre-install packages:

```dockerfile
FROM public.ecr.aws/truefoundrycloud/jupyter:0.4.6-py3.11.14-sudo

USER root
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends ffmpeg
USER jovyan

RUN python3 -m pip install --use-pep517 --no-cache-dir torch torchvision pandas scikit-learn
```

**Critical**: Do NOT modify ENTRYPOINT or CMD — TrueFoundry requires them.

## Build Scripts (Persistent APT Packages)

Instead of custom images, add a build script during deployment to install system packages on every start:

```bash
sudo apt update
sudo apt install -y ffmpeg libsm6 libxext6
```

## Cloud Storage Access

### Via Environment Variables

Set during deployment:
- **AWS S3**: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- **GCS**: `GOOGLE_APPLICATION_CREDENTIALS`

### Via IAM Service Account

Attach cloud-native IAM roles through service account integration for secure, credential-free access.

### Via Volumes

Mount TrueFoundry persistent volumes for direct data access. See `volumes` skill.

## Git Integration

JupyterLab includes a built-in Git extension. Configure:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

Use Personal Access Tokens or SSH keys for authentication.

## Python Environment Management

Default: Python 3.11. Create additional environments:

```bash
conda create -y -n py39 python=3.9
```

Wait ~2 minutes for kernel sync, then hard-refresh JupyterLab.

## Presenting Notebooks

Show as a table:

```
Notebooks:
| Name          | Status  | Image         | GPU  | Storage |
|---------------|---------|---------------|------|---------|
| dev-notebook  | Running | py3.11 + CUDA | T4   | 50 GB   |
| data-analysis | Stopped | py3.11        | None | 20 GB   |
```

</instructions>

<success_criteria>

## Success Criteria

- The notebook is launched and accessible via its URL in the TrueFoundry dashboard
- GPU resources are allocated as requested and visible inside the notebook (e.g., `nvidia-smi` works)
- Persistent storage is configured so the user's files survive restarts
- Auto-shutdown is enabled to prevent unnecessary cost from idle notebooks
- The user can install packages and access their data (cloud storage, volumes, or local upload)

</success_criteria>

<references>

## Composability

- **Need workspace**: Use `workspaces` skill to find target workspace
- **Save workspace for next time**: Use `preferences` skill to remember default workspace
- **Need GPU info**: Use `workspaces` skill to check available GPU types on cluster
- **Need volumes**: Use `volumes` skill to create persistent storage, then mount
- **Deploy model after prototyping**: Use `deploy` or `llm-deploy` skill
- **Check status**: Use `applications` skill to see notebook status

</references>

<troubleshooting>

## Error Handling

### Notebook Not Starting
```
Notebook stuck in pending. Check:
- Requested GPU type may not be available on cluster
- Insufficient cluster resources (CPU/memory)
- Image pull errors (check container registry access)
```

### GPU Not Detected
```
GPU not visible in notebook. Verify:
- Used CUDA image (cu129-* variant)
- Requested GPU type is available (check workspaces skill)
- CUDA toolkit version matches your framework requirements
```

### Storage Full
```
Notebook storage full. Options:
- Clean up unused files in /home/jovyan/
- Increase storage allocation
- Mount an external volume for large datasets
```

</troubleshooting>
