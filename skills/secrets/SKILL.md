---
name: secrets
description: Manages TrueFoundry secret groups and secrets. Handles listing, creating, updating, and deleting secret groups and individual key-value secrets. NOT for managing environment variables directly.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Secrets

Manage TrueFoundry secret groups and secrets. Secret groups organize secrets; individual secrets hold key-value pairs.

## When to Use

List, create, update, or delete secret groups and individual secrets on TrueFoundry, including pre-deploy secret setup and value rotation.

</objective>

<instructions>

## List Secret Groups

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

### Via Tool Call

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

### Via Tool Call

```
tfy_secret_groups_create(payload={"name": "my-secrets", ...})
```

**Note:** Requires human approval (HITL) via tool call.

### Via Direct API

```bash
$TFY_API_SH POST /api/svc/v1/secret-groups '{"name":"my-secrets","integrationId":"INTEGRATION_ID","secrets":[{"key":"DB_PASSWORD","value":"s3cret"}]}'
```

## Update Secret Group

Updates secrets in a group. A new version is created for every secret with a modified value. Secrets omitted from the array are deleted. At least one secret is required.

### Via Tool Call

```
tfy_secret_groups_update(id="GROUP_ID", payload={"secrets": [{"key": "DB_PASSWORD", "value": "new-value"}, {"key": "API_KEY", "value": "new-key"}]})
```

**Note:** Requires human approval (HITL) via tool call.

### Via Direct API

```bash
$TFY_API_SH PUT /api/svc/v1/secret-groups/GROUP_ID '{"secrets":[{"key":"DB_PASSWORD","value":"new-value"},{"key":"API_KEY","value":"new-key"}]}'
```

## Delete Secret Group

### Via Tool Call

```
tfy_secret_groups_delete(id="GROUP_ID")
```

**Note:** Requires human approval (HITL) via tool call.

### Via Direct API

```bash
$TFY_API_SH DELETE /api/svc/v1/secret-groups/GROUP_ID
```

## Delete Individual Secret

### Via Tool Call

```
tfy_secrets_delete(id="SECRET_ID")
```

**Note:** Requires human approval (HITL) via tool call.

### Via Direct API

```bash
$TFY_API_SH DELETE /api/svc/v1/secrets/SECRET_ID
```

</instructions>

<success_criteria>

## Success Criteria

- The user can list all secret groups and see their contents in a formatted table
- The user can create a new secret group with a specified name
- The user can update secrets in a group (rotate values, add/remove keys)
- The user can delete a secret group or an individual secret
- The agent has never displayed full secret values — only masked or "(set)" indicators
- The user can inspect individual secrets within a group by ID
- The agent has confirmed any create/update/delete operations before executing

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

### At Least One Secret Required
```
Cannot update secret group with zero secrets. Include at least one secret in the payload.
```

### No Secret Store Configured
```
No secret store configured for this workspace. Contact your platform admin.
```

### Missing Required Fields
```
Unprocessable entity. Ensure all secrets have both "key" and "value" fields.
```

</troubleshooting>
