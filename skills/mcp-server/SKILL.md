---
name: mcp-server
description: Deploys MCP (Model Context Protocol) servers on TrueFoundry. Converts stdio-based MCP servers (npm/uvx) into hosted HTTP services via mcp-proxy. NOT for regular services (use deploy skill).
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *) Bash(python*) Bash(pip*)
---

<objective>

# MCP Server Deployment

Deploy MCP (Model Context Protocol) servers on TrueFoundry. Convert stdio-based MCP servers (npm/uvx packages) into hosted HTTP services using mcp-proxy.

## Scope

Deploy stdio-based MCP servers (npm/uvx packages or custom) as hosted HTTP services on TrueFoundry using mcp-proxy.

## When NOT to Use

- User wants to deploy a regular service → use `deploy` skill
- User wants to deploy an LLM → use `llm-deploy` skill
- User wants to configure MCP client/tools locally → this is not for local MCP setup

## How It Works

MCP servers typically communicate over stdio (standard input/output). TrueFoundry uses **mcp-proxy** to wrap these into HTTP-accessible services:

```
[MCP Client] → HTTP → [mcp-proxy :8000] → stdio → [MCP Server (npx/uvx)]
```

</objective>

<instructions>

## User Confirmation Checklist

**Confirm these with the user before deploying. Auto-detect where possible, show defaults, let user adjust.**

- [ ] **Workspace** — `TFY_WORKSPACE_FQN`. Never auto-pick. Ask the user if missing.
- [ ] **MCP package** — Which MCP server to deploy? (npm package name, Python/uvx package name, or custom). Package type (npm vs Python) is auto-detected from the package name or registry.
- [ ] **Server name** — Suggest based on package name (e.g., `notion-mcp`, `github-mcp`).
- [ ] **Environment variables & secrets** — Ask what API keys/config the MCP server needs. Reference the MCP server's docs for required env vars (e.g., `NOTION_API_KEY`, `GITHUB_TOKEN`). Always use TrueFoundry secrets for sensitive values.

### Defaults Applied Silently (do not ask unless user raises)

These use sensible defaults. Only surface if the user asks or the situation requires it:

| Field | Default | When to Ask |
|-------|---------|-------------|
| Port | 8000 | Never — mcp-proxy always uses 8000 |
| CPU request/limit | 0.5 / 1.0 cores | Only ask if user mentions performance issues |
| Memory request/limit | 512 / 1024 MB | Only ask if user mentions large payloads or OOM |
| Ephemeral storage | 2 GB | Only ask if package has large dependencies |
| Expose | false (internal) | Only ask if user mentions public access |
| Base image | `node:24` (npm) or `python:3.11-slim` (uvx) | Auto-selected based on package type |
| Arguments | None | Only ask if user mentions specific args to pass |

## Deploy npm-based MCP Server (npx)

For MCP servers distributed as npm packages.

### Via API

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

```bash
TFY_API_SH=~/.claude/skills/truefoundry-mcp-server/scripts/tfy-api.sh

$TFY_API_SH POST /api/svc/v1/applications -d '{
  "name": "<SERVER_NAME>",
  "type": "service",
  "workspace_fqn": "WORKSPACE_FQN",
  "manifest": {
    "name": "<SERVER_NAME>",
    "components": {
      "image": {
        "type": "image",
        "image_uri": "node:24",
        "command": "npx -y mcp-proxy --port 8000 --host 0.0.0.0 --server stream npx -y <MCP_PACKAGE>"
      },
      "ports": [
        {"port": 8000, "protocol": "TCP", "app_protocol": "http"}
      ],
      "resources": {
        "cpu_request": <CPU_REQUEST>,
        "cpu_limit": <CPU_LIMIT>,
        "memory_request": <MEMORY_REQUEST>,
        "memory_limit": <MEMORY_LIMIT>,
        "ephemeral_storage_request": <STORAGE_REQUEST>,
        "ephemeral_storage_limit": <STORAGE_LIMIT>
      }
    }
  }
}'
```

### Via Python SDK

```python
from truefoundry.deploy import Service, Image, Port, Resources

service = Service(
    name="<SERVER_NAME>",
    image=Image(
        image_uri="node:24",
        command="npx -y mcp-proxy --port 8000 --host 0.0.0.0 --server stream npx -y <MCP_PACKAGE>",
    ),
    ports=[Port(port=8000, protocol="TCP", app_protocol="http")],
    resources=Resources(
        cpu_request=<CPU_REQUEST>, cpu_limit=<CPU_LIMIT>,
        memory_request=<MEMORY_REQUEST>, memory_limit=<MEMORY_LIMIT>,
        ephemeral_storage_request=<STORAGE_REQUEST>, ephemeral_storage_limit=<STORAGE_LIMIT>,
    ),
    env={
        # Add any required env vars for the MCP server
        # "API_KEY": "tfy-secret://secret-group:secret-name",
    },
)

service.deploy(workspace_fqn="<WORKSPACE_FQN>")
```

## Deploy Python-based MCP Server (uvx)

For MCP servers distributed as Python packages.

### Via API

```bash
$TFY_API_SH POST /api/svc/v1/applications -d '{
  "name": "<SERVER_NAME>",
  "type": "service",
  "workspace_fqn": "WORKSPACE_FQN",
  "manifest": {
    "name": "<SERVER_NAME>",
    "components": {
      "image": {
        "type": "image",
        "image_uri": "public.ecr.aws/docker/library/python:3.11-slim",
        "command": "sh -c \"pip install uv mcp-proxy && mcp-proxy --host=0.0.0.0 --port=8000 --server stream uvx <MCP_PACKAGE>\""
      },
      "ports": [
        {"port": 8000, "protocol": "TCP", "app_protocol": "http"}
      ],
      "resources": {
        "cpu_request": <CPU_REQUEST>,
        "cpu_limit": <CPU_LIMIT>,
        "memory_request": <MEMORY_REQUEST>,
        "memory_limit": <MEMORY_LIMIT>,
        "ephemeral_storage_request": <STORAGE_REQUEST>,
        "ephemeral_storage_limit": <STORAGE_LIMIT>
      }
    }
  }
}'
```

### Via Python SDK

```python
from truefoundry.deploy import Service, Image, Port, Resources

service = Service(
    name="<SERVER_NAME>",
    image=Image(
        image_uri="public.ecr.aws/docker/library/python:3.11-slim",
        command='sh -c "pip install uv mcp-proxy && mcp-proxy --host=0.0.0.0 --port=8000 --server stream uvx <MCP_PACKAGE>"',
    ),
    ports=[Port(port=8000, protocol="TCP", app_protocol="http")],
    resources=Resources(
        cpu_request=<CPU_REQUEST>, cpu_limit=<CPU_LIMIT>,
        memory_request=<MEMORY_REQUEST>, memory_limit=<MEMORY_LIMIT>,
        ephemeral_storage_request=<STORAGE_REQUEST>, ephemeral_storage_limit=<STORAGE_LIMIT>,
    ),
)

service.deploy(workspace_fqn="<WORKSPACE_FQN>")
```

## Deploy Custom MCP Server

For custom MCP servers you've built yourself:

### Using Dockerfile

```python
from truefoundry.deploy import Service, Build, DockerFileBuild, LocalSource, Port, Resources

service = Service(
    name="<SERVER_NAME>",
    image=Build(
        build_source=LocalSource(local_build=False),
        build_spec=DockerFileBuild(
            dockerfile_path="Dockerfile",
        ),
    ),
    ports=[Port(port=8000, protocol="TCP", app_protocol="http")],
    resources=Resources(
        cpu_request=<CPU_REQUEST>, cpu_limit=<CPU_LIMIT>,
        memory_request=<MEMORY_REQUEST>, memory_limit=<MEMORY_LIMIT>,
    ),
)

service.deploy(workspace_fqn="<WORKSPACE_FQN>")
```

Example Dockerfile for a custom MCP server:

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt mcp-proxy

COPY . .

CMD ["mcp-proxy", "--host=0.0.0.0", "--port=8000", "--server", "stream", "python", "my_mcp_server.py"]
```

## Common MCP Server Examples

### Notion MCP Server

```bash
# Command for npx deployment
npx -y mcp-proxy --port 8000 --host 0.0.0.0 --server stream npx -y @notionhq/notion-mcp-server
```

Environment variables: `NOTION_API_KEY`

### GitHub MCP Server

```bash
npx -y mcp-proxy --port 8000 --host 0.0.0.0 --server stream npx -y @modelcontextprotocol/server-github
```

Environment variables: `GITHUB_TOKEN`

### Filesystem MCP Server

```bash
sh -c "pip install mcp-proxy uv && mcp-proxy --port 8000 --host 0.0.0.0 --server stream uvx mcp-server-filesystem /data"
```

### Perplexity MCP Server

```bash
npx -y mcp-proxy --port 8000 --host 0.0.0.0 --server stream npx -y @anthropic/perplexity-mcp-server
```

Environment variables: `PERPLEXITY_API_KEY`

## Passing Arguments

Append arguments after the package name:

- **npm**: `npx -y mcp-proxy --port 8000 --host 0.0.0.0 --server stream npx -y package-name --arg1 value1`
- **Python**: `mcp-proxy --port 8000 --host 0.0.0.0 --server stream uvx package-name --arg1 value1`

## Environment Variables & Secrets

MCP servers often need API keys. **Always use TrueFoundry secrets** for sensitive values:

```python
env={
    "NOTION_API_KEY": "tfy-secret://my-secrets:notion-api-key",
    "GITHUB_TOKEN": "tfy-secret://my-secrets:github-token",
}
```

See `secrets` skill for creating secret groups and secrets.

## Verification

After deployment, test the endpoint:

```bash
curl http://your-service-endpoint-url
```

The endpoint should respond with MCP protocol messages over HTTP.

## MCP Gateway Registration

After deploying your MCP server, you can register it with TrueFoundry's MCP Gateway for centralized management:

1. Go to **AI Gateway → MCP Servers** in the TrueFoundry dashboard
2. Click **Add MCP Server**
3. Enter the deployed service endpoint URL
4. Configure authentication and access controls

The MCP Gateway provides:
- Centralized registry of all MCP servers
- Access control and approval workflows
- Environment isolation (dev/staging/prod)
- Discovery for AI agents

</instructions>

<success_criteria>

## Success Criteria

- The MCP server is deployed and running on TrueFoundry with a reachable HTTP endpoint
- The mcp-proxy wrapper correctly bridges stdio to HTTP on port 8000
- All required environment variables and API keys are configured via TrueFoundry secrets
- The agent has verified the endpoint responds to MCP protocol requests
- The user has the public URL or internal DNS address to connect MCP clients to the server

</success_criteria>

<troubleshooting>

## Troubleshooting

### Slow Startup

First run downloads npm/pip packages at runtime. For faster starts:
- Build a custom Docker image with packages pre-installed
- Increase ephemeral storage for package cache

### High Memory Usage

npm/pip installations can spike memory. Increase `memory_limit` to at least 1024 MB.

### Authentication Failures

Verify environment variables match the MCP server's documentation. Use `secrets` skill to securely manage API keys.

### Package Not Found

Confirm the package exists on npm (npmjs.com) or PyPI (pypi.org). Check exact package name spelling.

</troubleshooting>

<references>

## Composability

- **Need workspace**: Use `workspaces` skill to find target workspace
- **Need secrets**: Use `secrets` skill to create API key secrets before deploying
- **Check status**: Use `applications` skill to see MCP server status
- **View logs**: Use `logs` skill if MCP server isn't responding
- **Public URL**: Configure host in ports using cluster base domain (see `workspaces` skill)

</references>
