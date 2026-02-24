---
name: ssh-server
description: Launches SSH servers on TrueFoundry for remote development. Supports VS Code Remote-SSH, GPU access, persistent storage, and auto-shutdown. NOT for notebooks or production services.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# SSH Server

Launch an SSH server on TrueFoundry for remote development. Connect with VS Code Remote-SSH or any SSH client, with full GPU access and persistent storage.

## When to Use

Launch, configure, or connect to SSH-based remote development environments on TrueFoundry, including VS Code Remote-SSH and GPU dev boxes.

## When NOT to Use

- User wants Jupyter notebooks → use `notebooks` skill
- User wants to deploy a service → use `deploy` skill
- User wants to deploy a model → use `llm-deploy` skill

</objective>

<context>

## Launch SSH Server via UI

1. Go to **Deployments → New Deployment → SSH Server**
2. Add your SSH public key
3. Select workspace and configure resources
4. Click Deploy

</context>

<instructions>

## User Confirmation Checklist

**Before launching an SSH server, ALWAYS confirm these with the user:**

### Basic Configuration
- [ ] **Server name** — What to call this SSH server
- [ ] **SSH public key** — User's SSH public key (required for access)
- [ ] **Environment** — Dev, prototyping, or long-running?

### Resources
- [ ] **Device type** — CPU only, or GPU? If GPU, which type?
- [ ] **CPU** — Request and limit
- [ ] **Memory** — Request and limit in MB
- [ ] **Storage** — Ephemeral storage request and limit in MB

### Storage & Lifecycle
- [ ] **Home directory size** — Persistent storage in MB for /home/jovyan/
- [ ] **Auto-shutdown timeout** — Seconds of inactivity before auto-stop (e.g., 3600 = 1 hour)

### Image
- [ ] **Custom image** — Need pre-installed packages? (custom Dockerfile or build script)

### Environment & Secrets
- [ ] **Environment variables** — Cloud credentials, API keys, etc. (optional)
- [ ] **Volume mounts** — Persistent volumes to attach (optional)

**Do NOT launch with hardcoded defaults without asking. Every `<PLACEHOLDER>` in the templates below MUST be replaced with a value confirmed by the user. If unsure about any field, ask — never assume.**

## Launch SSH Server via API

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

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

### GPU SSH Server

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
- Increase wait_time for longer sessions
- Resource limits exceeded (increase memory/CPU)
```

</troubleshooting>
