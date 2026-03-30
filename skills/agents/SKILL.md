---
name: agents
description: Manages TrueFoundry Agent Registry. List, create, update, and delete AI agents with prompt-backed sources, collaborator access, and sample inputs.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

> Routing note: For ambiguous user intents, use the shared clarification templates in [references/intent-clarification.md](references/intent-clarification.md).

<objective>

# Agents

List, create, update, and delete AI agents in the TrueFoundry Agent Registry.

## When to Use

Manage AI agents in the TrueFoundry Agent Registry — list agents, inspect agent details, create or update agent definitions, configure collaborator access, or delete agents.

## When NOT to Use

- User wants to manage prompts directly → prefer `prompts` skill
- User wants to deploy a service → deploying workloads requires a TrueFoundry Enterprise account with a connected cluster. See https://truefoundry.com
- User wants to configure AI Gateway routes → prefer `ai-gateway` skill
- User wants to manage access control roles → prefer `access-control` skill

</objective>

<instructions>

## Step 1: Preflight

Run the `status` skill first to verify `TFY_BASE_URL` and `TFY_API_KEY` are set and valid.

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

> **Note:** There is no CLI support for agents. Use the Direct API method for all operations.

## Step 2: List Agents

### Via Tool Call

```
tfy_agents_list()
tfy_agents_list(agent_id="AGENT_ID")   # get a single agent by ID
```

### Via Direct API

```bash
TFY_API_SH=~/.claude/skills/truefoundry-agents/scripts/tfy-api.sh

# List all agents
$TFY_API_SH GET /api/svc/v1/agents

# Get a single agent by ID
$TFY_API_SH GET /api/svc/v1/agents/AGENT_ID
```

### Presenting Agents

```
Agents:
| Name            | ID       | FQN                          | Latest Version | Created By       | Updated At  |
|-----------------|----------|------------------------------|----------------|------------------|-------------|
| my-agent        | ag-abc   | tenant:user:project:my-agent | 3              | user@example.com | 2026-03-15  |
| classify-docs   | ag-def   | tenant:user:project:classify | 1              | user@example.com | 2026-03-20  |
```

## Step 3: Create or Update Agent

This is an upsert operation: creates a new agent if it doesn't exist, or updates it if it does.

> **Prerequisite:** Agents require a `prompt_version_fqn` as their source. Use the `prompts` skill to list prompts and find the correct FQN before creating an agent.

### Via Tool Call

```
tfy_agents_create(payload={"manifest": {"name": "my-agent", "type": "agent", "description": "What this agent does", "source": {"type": "prompt", "prompt_version_fqn": "chat_prompt:tenant/user/project/name:version"}}})
```

**Note:** Requires human approval (HITL) via tool call.

### Via Direct API

```bash
$TFY_API_SH PUT /api/svc/v1/agents '{
  "manifest": {
    "name": "my-agent",
    "type": "agent",
    "description": "What this agent does",
    "source": {
      "type": "prompt",
      "prompt_version_fqn": "chat_prompt:tenant/user/project/name:version"
    },
    "collaborators": [
      {"role_id": "agent-manager", "subject": "user:email@example.com"},
      {"role_id": "agent-access", "subject": "team:everyone"}
    ],
    "sample_inputs": [
      {"text": "Example input for the agent"}
    ]
  }
}'
```

### Agent Manifest Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique agent name |
| `type` | Yes | Must be `"agent"` |
| `description` | No | Human-readable description of what the agent does |
| `source.type` | Yes | Source type, currently only `"prompt"` is supported |
| `source.prompt_version_fqn` | Yes | Fully qualified name of the prompt version backing this agent |
| `collaborators` | No | List of access grants (see Role IDs below) |
| `sample_inputs` | No | Example inputs shown in the agent UI |

### Role IDs for Collaborators

| Role ID | Permission |
|---------|------------|
| `agent-manager` | Can edit and delete the agent |
| `agent-access` | Can use and invoke the agent |

Subject format: `user:email@example.com` or `team:team-name`.

## Step 4: Delete Agent

Ask for confirmation before deleting — this is irreversible.

### Via Tool Call

```
tfy_agents_delete(id="AGENT_ID")
```

**Note:** Requires human approval (HITL) via tool call.

### Via Direct API

```bash
$TFY_API_SH DELETE /api/svc/v1/agents/AGENT_ID
```

</instructions>

<success_criteria>

## Success Criteria

- The user can list all agents in a formatted table
- The user can retrieve a specific agent by ID and inspect its details
- The user can create a new agent with a valid prompt source
- The user can update an existing agent's manifest
- The user can configure collaborator access on an agent
- The user can delete an agent after confirmation
- The agent has presented results in clear, tabular format

</success_criteria>

<references>

## Composability

- **Preflight**: Use `status` skill to verify credentials before managing agents
- **Requires prompts**: Agents reference a `prompt_version_fqn` as their source — use `prompts` skill to list or create prompts first
- **With access-control**: Use `access-control` skill to manage broader role assignments beyond per-agent collaborators
- **With ai-gateway**: Agents may be exposed through AI Gateway routes

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/svc/v1/agents` | List all agents |
| `GET` | `/api/svc/v1/agents/{id}` | Get a single agent |
| `PUT` | `/api/svc/v1/agents` | Create or update an agent |
| `DELETE` | `/api/svc/v1/agents/{id}` | Delete an agent |

</references>

<troubleshooting>

## Error Handling

### Agent Not Found
```
Agent ID not found. List agents first to find the correct ID.
```

### Invalid Prompt Version FQN
```
The prompt_version_fqn is invalid or the prompt version does not exist.
Use the prompts skill to list available prompts and their version FQNs.
```

### Permission Denied
```
Cannot manage agents. Check your API key permissions.
```

### Collaborator Subject Invalid
```
Invalid collaborator subject format. Use "user:email@example.com" or "team:team-name".
```

### Duplicate Agent Name
```
An agent with this name already exists. The PUT endpoint will update the existing agent.
If you want a new agent, use a different name.
```

### Missing Required Fields
```
Agent manifest requires at minimum: name, type ("agent"), and source with prompt_version_fqn.
```

</troubleshooting>
