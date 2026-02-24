---
name: secrets
description: This skill should be used when the user asks "list secrets", "show secret groups", "create a secret", "add secret", "what secrets do I have", "manage secrets", "delete secret group", "view secret value", "secret group details", "set up secrets for deployment", "configure environment variables", or wants to manage TrueFoundry secret groups and individual secrets.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Secrets

Manage TrueFoundry secret groups and secrets. Secret groups organize secrets; individual secrets hold key-value pairs.

## When to Use

- User asks "list secrets", "show secret groups"
- User wants to create a secret group
- User asks "what secrets are in this group"
- User wants to get a specific secret value
- Setting up secrets before a deploy

</objective>

<instructions>

## List Secret Groups

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

### Via MCP

```
tfy_secrets_list()
tfy_secrets_list(secret_group_id="group-id")  # get group + secrets
tfy_secrets_list(secret_id="secret-id")        # get one secret
```

### Via Direct API

```bash
# Set the path to tfy-api.sh for your agent (example for Claude Code):
TFY_API_SH=~/.claude/skills/truefoundry-secrets/scripts/tfy-api.sh

# List all secret groups
$TFY_API_SH GET /api/svc/v1/secret-groups

# Get a specific group
$TFY_API_SH GET /api/svc/v1/secret-groups/GROUP_ID

# List secrets in a group
$TFY_API_SH POST /api/svc/v1/secrets '{"secretGroupId":"GROUP_ID","limit":100,"offset":0}'

# Get a specific secret
$TFY_API_SH GET /api/svc/v1/secrets/SECRET_ID
```

## Presenting Secrets

```
Secret Groups:
| Name          | ID       | Secrets |
|---------------|----------|---------|
| prod-secrets  | sg-abc   | 5       |
| dev-secrets   | sg-def   | 3       |
```

**Security:** Never display secret values in full. Show only the first few characters or indicate "(set)".

## Create Secret Group

### Via MCP

```
tfy_secret_groups_create(payload={"name": "my-secrets", ...})
```

**Note:** Requires human approval (HITL) via MCP.

### Via Direct API

```bash
$TFY_API_SH POST /api/svc/v1/secret-groups '{"name":"my-secrets"}'
```

</instructions>

<success_criteria>

## Success Criteria

- The user can list all secret groups and see their contents in a formatted table
- The user can create a new secret group with a specified name
- The agent has never displayed full secret values — only masked or "(set)" indicators
- The user can inspect individual secrets within a group by ID
- The agent has confirmed any create/delete operations before executing

</success_criteria>

<references>

## Composability

- **Before deploy**: Create secret groups, then reference in deployment config
- **After listing**: Get individual secrets by ID for inspection
- **With applications**: Reference secret groups in application env vars

</references>

<troubleshooting>

## Error Handling

### Secret Group Not Found
```
Secret group ID not found. List groups first to find the correct ID.
```

### Permission Denied
```
Cannot access secrets. Check your API key permissions.
```

### Secret Already Exists
```
Secret group with this name already exists. Use a different name.
```

</troubleshooting>
