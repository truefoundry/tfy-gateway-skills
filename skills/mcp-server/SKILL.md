---
name: mcp-server
description: This skill should be used when the user asks "deploy MCP server", "host MCP server", "MCP deployment", "deploy tool server", "model context protocol", or wants to deploy an MCP server on TrueFoundry as a hosted HTTP service.
allowed-tools: Bash(*/tfy-api.sh *), Bash(python*), Bash(pip*)
---

# MCP Server Deployment

Deploy MCP (Model Context Protocol) servers on TrueFoundry. Convert stdio-based MCP servers (npm/uvx packages) into hosted HTTP services using mcp-proxy.

## When to Use

- User asks "deploy MCP server", "host my MCP server"
- User wants to make a local MCP server available over HTTP
- User has an npx/uvx MCP server they want to deploy to the cloud
- User asks about MCP gateway integration

## When NOT to Use

- User wants to deploy a regular service → use `deploy` skill
- User wants to deploy an LLM → use `llm-deploy` skill
- User wants to configure MCP client/tools locally → this is not for local MCP setup

## How It Works

MCP servers typically communicate over stdio (standard input/output). TrueFoundry uses **mcp-proxy** to wrap these into HTTP-accessible services:

```
[MCP Client] → HTTP → [mcp-proxy :8000] → stdio → [MCP Server (npx/uvx)]
```

## Deploy npm-based MCP Server (npx)

For MCP servers distributed as npm packages.

### Via API

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

```bash
TFY_API_SH=~/.claude/skills/truefoundry-mcp-server/scripts/tfy-api.sh

$TFY_API_SH POST /api/svc/v1/applications -d '{
  "name": "my-mcp-server",
  "type": "service",
  "workspace_fqn": "WORKSPACE_FQN",
  "manifest": {
    "name": "my-mcp-server",
    "components": {
      "image": {
        "type": "image",
        "image_uri": "node:24",
        "command": "npx -y mcp-proxy --port 8000 --host 0.0.0.0 --server stream npx -y @your-org/your-mcp-server"
      },
      "ports": [
        {"port": 8000, "protocol": "TCP", "app_protocol": "http"}
      ],
      "resources": {
        "cpu_request": 0.5,
        "cpu_limit": 1,
        "memory_request": 512,
        "memory_limit": 1024,
        "ephemeral_storage_request": 2000,
        "ephemeral_storage_limit": 4000
      }
    }
  }
}'
```

### Via Python SDK

```python
from truefoundry.deploy import Service, Image, Port, Resources

service = Service(
    name="my-mcp-server",
    image=Image(
        image_uri="node:24",
        command="npx -y mcp-proxy --port 8000 --host 0.0.0.0 --server stream npx -y @your-org/your-mcp-server",
    ),
    ports=[Port(port=8000, protocol="TCP", app_protocol="http")],
    resources=Resources(
        cpu_request=0.5, cpu_limit=1,
        memory_request=512, memory_limit=1024,
        ephemeral_storage_request=2000, ephemeral_storage_limit=4000,
    ),
    env={
        # Add any required env vars for the MCP server
        # "API_KEY": "tfy-secret://secret-group:secret-name",
    },
)

service.deploy(workspace_fqn="your-workspace-fqn")
```

## Deploy Python-based MCP Server (uvx)

For MCP servers distributed as Python packages.

### Via API

```bash
$TFY_API_SH POST /api/svc/v1/applications -d '{
  "name": "my-python-mcp",
  "type": "service",
  "workspace_fqn": "WORKSPACE_FQN",
  "manifest": {
    "name": "my-python-mcp",
    "components": {
      "image": {
        "type": "image",
        "image_uri": "public.ecr.aws/docker/library/python:3.11-slim",
        "command": "sh -c \"pip install uv mcp-proxy && mcp-proxy --host=0.0.0.0 --port=8000 --server stream uvx your-mcp-package\""
      },
      "ports": [
        {"port": 8000, "protocol": "TCP", "app_protocol": "http"}
      ],
      "resources": {
        "cpu_request": 0.5,
        "cpu_limit": 1,
        "memory_request": 512,
        "memory_limit": 1024,
        "ephemeral_storage_request": 2000,
        "ephemeral_storage_limit": 4000
      }
    }
  }
}'
```

### Via Python SDK

```python
from truefoundry.deploy import Service, Image, Port, Resources

service = Service(
    name="my-python-mcp",
    image=Image(
        image_uri="public.ecr.aws/docker/library/python:3.11-slim",
        command='sh -c "pip install uv mcp-proxy && mcp-proxy --host=0.0.0.0 --port=8000 --server stream uvx your-mcp-package"',
    ),
    ports=[Port(port=8000, protocol="TCP", app_protocol="http")],
    resources=Resources(
        cpu_request=0.5, cpu_limit=1,
        memory_request=512, memory_limit=1024,
        ephemeral_storage_request=2000, ephemeral_storage_limit=4000,
    ),
)

service.deploy(workspace_fqn="your-workspace-fqn")
```

## Deploy Custom MCP Server

For custom MCP servers you've built yourself:

### Using Dockerfile

```python
from truefoundry.deploy import Service, Build, DockerFileBuild, LocalSource, Port, Resources

service = Service(
    name="custom-mcp-server",
    image=Build(
        build_source=LocalSource(local_build=False),
        build_spec=DockerFileBuild(
            dockerfile_path="Dockerfile",
        ),
    ),
    ports=[Port(port=8000, protocol="TCP", app_protocol="http")],
    resources=Resources(
        cpu_request=0.5, cpu_limit=1,
        memory_request=512, memory_limit=1024,
    ),
)

service.deploy(workspace_fqn="your-workspace-fqn")
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

## Composability

- **Need workspace**: Use `workspaces` skill to find target workspace
- **Need secrets**: Use `secrets` skill to create API key secrets before deploying
- **Check status**: Use `applications` skill to see MCP server status
- **View logs**: Use `logs` skill if MCP server isn't responding
- **Public URL**: Configure host in ports using cluster base domain (see `workspaces` skill)
