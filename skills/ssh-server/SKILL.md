---
name: ssh-server
description: Launches SSH servers on TrueFoundry for remote development. Supports VS Code Remote-SSH, GPU access, persistent storage, and auto-shutdown. NOT for notebooks or production services.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(tfy*) Bash(*/tfy-api.sh *)
---

<objective>

# SSH Server

Launch an SSH server on TrueFoundry for remote development. Write a YAML manifest and apply with `tfy apply`. REST API fallback when CLI unavailable. Connect with VS Code Remote-SSH or any SSH client, with full GPU access and persistent storage.

## When to Use

Launch, configure, or connect to SSH-based remote development environments on TrueFoundry, including VS Code Remote-SSH and GPU dev boxes.

## When NOT to Use

- User wants Jupyter notebooks → use `notebooks` skill
- User wants to deploy a service → use `deploy` skill
- User wants to deploy a model → use `llm-deploy` skill

</objective>

<context>

## Prerequisites

**Always verify before launching an SSH server:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**
3. **CLI** — Check `tfy --version`. Install if missing: `pip install truefoundry && tfy login --host "$TFY_BASE_URL"`

For credential check commands and .env setup, see `references/prerequisites.md`.

### CLI Detection

```bash
tfy --version
```

| CLI Output | Status | Action |
|-----------|--------|--------|
| `tfy version X.Y.Z` (>= 0.5.0) | Current | Use `tfy apply` as documented below. |
| `tfy version X.Y.Z` (0.3.x-0.4.x) | Outdated | Upgrade: `pip install -U truefoundry`. Core `tfy apply` should still work. |
| Command not found | Not installed | Install: `pip install truefoundry && tfy login --host "$TFY_BASE_URL"` |
| CLI unavailable (no pip/Python) | Fallback | Use REST API via `tfy-api.sh`. See `references/cli-fallback.md`. |

## Launch SSH Server via UI

1. Go to **Deployments → New Deployment → SSH Server**
2. Add your SSH public key
3. Select workspace and configure resources
4. Click Deploy

</context>

<instructions>

## Quick Deploy Flow

**For the fastest setup, present a single plan instead of asking questions one by one.**

### 1. Check Preferences

```bash
PREFS_FILE=~/.config/truefoundry/preferences.yml
if [ -f "$PREFS_FILE" ]; then
  cat "$PREFS_FILE"
fi
```

If preferences exist, pre-fill: workspace, environment, resources, GPU preferences.
If no preferences file, the only mandatory questions are **workspace** and **SSH key**.

### 2. Auto-Detect + Pre-fill

Combine preferences + local environment to fill every field:

| Field | Source (priority order) |
|-------|----------------------|
| Workspace | 1. Preferences 2. Ask user |
| Server name | Auto-suggest (e.g., `dev-server`) |
| SSH public key | Auto-detect from `~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub` |
| GPU needed | 1. Preferences 2. Default no |
| Resources | 1. Preferences 2. "Light Dev" profile default |
| Auto-shutdown | 1. Preferences 2. Default 1 hour |
| Home dir storage | 1. Preferences 2. Default 20 GB |

### 3. Present One Plan

Present ALL values in a single summary and ask for confirmation:

```
I'll launch an SSH server on TrueFoundry:

| Setting        | Value                          | Source      |
|----------------|--------------------------------|-------------|
| Workspace      | my-cluster:dev-ws              | saved pref  |
| Server name    | dev-server                     | auto        |
| SSH key        | ssh-ed25519 AAAA...            | auto (~/.ssh)|
| CPU            | 2 / 4 cores                    | dev default |
| Memory         | 4 / 8 GB                       | dev default |
| Home storage   | 20 GB                          | dev default |
| Auto-shutdown  | 1 hour                         | default     |
| GPU            | None                           | default     |

Launch with these settings? (say "yes" to launch, or tell me what to change)
```

### 4. Handle Response

- **"yes" / "looks good" / "launch"** → launch immediately using the steps below
- **"change X to Y"** → update that one field, re-confirm
- **"I want to customize"** → fall through to the full checklist flow below

### 5. After Launch — Offer to Save Preferences

If no preferences file exists or new values were used:

```
SSH server launched! Want me to save these settings as defaults?
- Workspace: my-cluster:dev-ws
- Resources: Light Dev profile
- Auto-shutdown: 1 hour

This saves to ~/.config/truefoundry/preferences.yml so future launches are even faster.
```

Use the `preferences` skill to save. If the user wants to edit preferences later, tell them to use the `preferences` skill directly.

---

## User Confirmation Checklist

**Confirm these with the user before launching. Show defaults, let user adjust.**

- [ ] **Workspace** — `TFY_WORKSPACE_FQN`. Never auto-pick. Ask the user if missing.
- [ ] **Server name** — Suggest a descriptive name (e.g., `dev-server`, `gpu-dev-box`).
- [ ] **SSH public key** — Required. Auto-detect from `~/.ssh/id_rsa.pub` or `~/.ssh/id_ed25519.pub`. If not found, guide user to generate one.
- [ ] **GPU needed?** — Ask if they need GPU access. If yes, discover available types from cluster and present options.
- [ ] **Resources** — Present a suggestion table based on use case (see below). Include CPU, memory, storage, home directory size, and auto-shutdown timeout. Let user adjust.

### Resource Suggestion Table

Present resources based on the use case:

```
| Resource         | Light Dev  | ML Dev     | Heavy Compute |
|------------------|------------|------------|---------------|
| CPU request      | 2 cores    | 4 cores    | 8 cores       |
| CPU limit        | 4 cores    | 8 cores    | 16 cores      |
| Memory request   | 4 GB       | 16 GB      | 32 GB         |
| Memory limit     | 8 GB       | 32 GB      | 64 GB         |
| Home dir storage | 20 GB      | 50 GB      | 100 GB        |
| Auto-shutdown    | 1 hour     | 2 hours    | 4 hours       |
| GPU              | None       | T4/A10     | A100/H100     |

Which profile fits your use case, or customize?
```

### Defaults Applied Silently (do not ask unless user raises)

These use sensible defaults. Only surface if the user asks or the situation requires it:

| Field | Default | When to Ask |
|-------|---------|-------------|
| Image | `public.ecr.aws/truefoundrycloud/ssh-server:latest` | Only ask if user needs custom pre-installed packages |
| Ephemeral storage | 5 GB | Only ask if user mentions large temporary files |
| Environment variables | None | Only ask if user mentions cloud credentials or API keys |
| Volume mounts | None | Only ask if user mentions shared data or persistent volumes |
| Custom image / build script | None | Only ask if user mentions pre-installed system packages (apt) |

## Launch SSH Server via API

### Configuration Questions

Before generating the manifest, ask the user:

1. **Name** — What to call the SSH server
2. **GPU needed?** — CPU server (default) or GPU server (for ML development). If GPU, use the CUDA image variant.
3. **Home directory size** — Persistent storage in GB (default: 20)
4. **Image variant** — CPU (`ssh-server:0.4.5-py3.12.12`) or CUDA (`ssh-server:0.4.5-cu129-py3.12.12`)

### CPU SSH Server

**1. Generate the manifest:**

```yaml
# tfy-manifest.yaml — SSH Server (CPU)
name: my-ssh-server
type: ssh-server
image:
  image_uri: public.ecr.aws/truefoundrycloud/ssh-server:0.4.5-py3.12.12
home_directory_size: 20
resources:
  node:
    type: node_selector
    capacity_type: on_demand
  cpu_request: 1
  cpu_limit: 3
  memory_request: 4000
  memory_limit: 6000
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
workspace_fqn: "YOUR_WORKSPACE_FQN"
```

**2. Preview:**

```bash
tfy apply -f tfy-manifest.yaml --dry-run --show-diff
```

**3. Apply:**

```bash
tfy apply -f tfy-manifest.yaml
```

### GPU SSH Server

```yaml
# tfy-manifest.yaml — GPU SSH Server (CUDA)
name: gpu-dev-server
type: ssh-server
image:
  image_uri: public.ecr.aws/truefoundrycloud/ssh-server:0.4.5-cu129-py3.12.12
home_directory_size: 20
resources:
  node:
    type: node_selector
    capacity_type: on_demand
  cpu_request: 4
  cpu_limit: 8
  memory_request: 16000
  memory_limit: 32000
  ephemeral_storage_request: 10000
  ephemeral_storage_limit: 20000
  devices:
    - type: nvidia_gpu
      name: A10_24GB
      count: 1
workspace_fqn: "YOUR_WORKSPACE_FQN"
```

## Launch SSH Server via REST API (Fallback)

When CLI is not available, use `tfy-api.sh`. Set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

### Create SSH Server

```bash
TFY_API_SH=~/.claude/skills/truefoundry-ssh-server/scripts/tfy-api.sh

$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "<SERVER_NAME>",
    "type": "ssh-server",
    "image": {
      "type": "image",
      "image_uri": "public.ecr.aws/truefoundrycloud/ssh-server:latest"
    },
    "resources": {
      "cpu_request": <CPU_REQUEST>,
      "cpu_limit": <CPU_LIMIT>,
      "memory_request": <MEMORY_REQUEST>,
      "memory_limit": <MEMORY_LIMIT>,
      "ephemeral_storage_request": <STORAGE_REQUEST>,
      "ephemeral_storage_limit": <STORAGE_LIMIT>
    },
    "ssh_public_key": "<SSH_PUBLIC_KEY>",
    "home_directory_size": <HOME_DIR_SIZE>,
    "cull_timeout": <CULL_TIMEOUT>,
    "workspace_fqn": "WORKSPACE_FQN"
  },
  "workspaceId": "WORKSPACE_ID_HERE"
}'
```

### GPU SSH Server (REST API)

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "<SERVER_NAME>",
    "type": "ssh-server",
    "image": {
      "type": "image",
      "image_uri": "public.ecr.aws/truefoundrycloud/ssh-server:latest"
    },
    "resources": {
      "cpu_request": <CPU_REQUEST>,
      "cpu_limit": <CPU_LIMIT>,
      "memory_request": <MEMORY_REQUEST>,
      "memory_limit": <MEMORY_LIMIT>,
      "ephemeral_storage_request": <STORAGE_REQUEST>,
      "ephemeral_storage_limit": <STORAGE_LIMIT>,
      "devices": [
        {"type": "nvidia_gpu", "name": "<GPU_TYPE>", "count": <GPU_COUNT>}
      ]
    },
    "ssh_public_key": "<SSH_PUBLIC_KEY>",
    "home_directory_size": <HOME_DIR_SIZE>,
    "cull_timeout": <CULL_TIMEOUT>,
    "workspace_fqn": "WORKSPACE_FQN"
  },
  "workspaceId": "WORKSPACE_ID_HERE"
}'
```

## SSH Key Setup

**Note:** The `ssh_public_key` field is required in the API manifest. The SSH server will not be accessible without it.

### Prerequisites

You need an SSH key pair. Check for existing keys:

```bash
# macOS/Linux
cat ~/.ssh/id_rsa.pub

# Windows PowerShell
type $home\.ssh\id_rsa.pub
```

### Generate a New Key (if needed)

```bash
ssh-keygen -t rsa
```

### Add Key to SSH Server

Add your public key during deployment configuration, or after deployment:

```bash
# Connect and add key
mkdir -p /home/jovyan/.ssh
echo "YOUR_PUBLIC_KEY_HERE" >> /home/jovyan/.ssh/authorized_keys
```

### Multi-User Access

Add multiple authorized keys:

```bash
echo "TEAMMATE_PUBLIC_KEY" >> /home/jovyan/.ssh/authorized_keys
```

## VS Code Remote-SSH Setup

1. Install **Remote-SSH** extension in VS Code
2. Open Command Palette → "Remote-SSH: Connect to Host"
3. Enter the SSH connection string from TrueFoundry dashboard
4. Authenticate with your SSH key

### ProxyTunnel Installation

Required for SSH tunneling through TrueFoundry:

| Platform | Command |
|----------|---------|
| macOS | `brew install proxytunnel` |
| Ubuntu | `sudo apt-get install proxy-tunnel` |
| Alternative | Use `nc` (netcat) for proxy without proxytunnel |

## File Transfer

### SCP (Secure Copy)

```bash
# Download from server
scp -r <deploymentName>:<remote-path> <local-path>

# Upload to server
scp -r <local-path> <deploymentName>:<remote-path>
```

### rsync (Incremental Sync)

```bash
# Upload
rsync -avz <local-path> <deploymentName>:<remote-path>

# Download
rsync -avz <deploymentName>:<remote-path> <local-path>
```

## Scale-to-Zero

SSH servers auto-stop after inactivity to save costs. Configure via `cull_timeout` in seconds (e.g., `3600` for 1 hour).

**Activity detection**: Active SSH connections and foreground applications.
**Not detected**: Background processes.

Requires SSH server image v0.3.10+.

## Persistent Storage

- **Home directory** (`/home/jovyan/`) persists across restarts
- **APT packages** do NOT persist — use Build Scripts
- **Pip packages** in home directory persist
- **Conda environments** persist

## Custom Images

Extend TrueFoundry's SSH server images:

```dockerfile
FROM public.ecr.aws/truefoundrycloud/ssh-server:latest

USER root
RUN DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    ffmpeg htop tmux
USER jovyan

RUN python3 -m pip install --no-cache-dir torch numpy pandas
```

**Critical**: Do NOT modify ENTRYPOINT or CMD.

## Build Scripts

Install system packages that persist across restarts:

```bash
sudo apt update
sudo apt install -y tmux htop neovim
```

## Python Environment Management

Create isolated environments:

```bash
conda create -y -n ml-env python=3.11
conda activate ml-env
pip install torch transformers
```

</instructions>

<success_criteria>

## Success Criteria

- The user can launch an SSH server on a specified TrueFoundry workspace
- The user can connect to the server via VS Code Remote-SSH or a standard SSH client
- The agent has configured SSH keys and verified connectivity
- The user can transfer files to and from the remote server
- The agent has set up auto-shutdown to avoid unnecessary costs
- The user can access GPU resources from the remote environment if requested

</success_criteria>

<references>

## Composability

- **Need workspace**: Use `workspaces` skill to find target workspace
- **Need GPU info**: Use `workspaces` skill to check available GPUs on cluster
- **Need persistent volumes**: Use `volumes` skill to create and mount storage
- **Deploy after development**: Use `deploy` or `llm-deploy` skill
- **Check status**: Use `applications` skill to see SSH server status

</references>

<troubleshooting>

## Error Handling

### CLI Errors

```
tfy: command not found
Install the TrueFoundry CLI:
  pip install truefoundry
  tfy login --host "$TFY_BASE_URL"
```

```
Manifest validation failed.
Check:
- YAML syntax is valid
- Required fields: name, type, workspace_fqn
- Image URI exists and is accessible
- Resource values use correct units (memory in MB)
```

### Cannot Connect

```
SSH connection failed. Check:
- SSH key is correctly configured
- ProxyTunnel is installed (macOS: brew install proxytunnel)
- SSH server is in Running state (check applications skill)
- Network/VPN connectivity
```

### GPU Not Available

```
GPU not accessible. Verify:
- Requested GPU type is available on cluster (check workspaces skill)
- Used the correct SSH server image with CUDA support
```

### Server Stopped Unexpectedly

```
SSH server stopped. Possible causes:
- Auto-shutdown triggered (no active SSH connections)
- Check if auto-shutdown is configured on the server
- Resource limits exceeded (increase memory/CPU)
```

### REST API Fallback Errors

```
401 Unauthorized — Check TFY_API_KEY is valid
404 Not Found — Check TFY_BASE_URL and API endpoint path
422 Validation Error — Check manifest fields match expected schema
```

</troubleshooting>
