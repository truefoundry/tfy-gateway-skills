---
name: access-tokens
description: This skill should be used when the user asks "list access tokens", "create API key", "generate access token", "show my tokens", "personal access token", "create PAT", "delete token", "manage API keys", "revoke token", "new API key", "truefoundry token", "CI/CD token", "generate TFY key", or wants to manage TrueFoundry personal access tokens.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Access Tokens

Manage TrueFoundry personal access tokens (PATs). List, create, and delete tokens used for API authentication, CI/CD pipelines, and AI Gateway access.

## When to Use

- User asks "list my access tokens", "show my API keys"
- User wants to create a new API key for CI/CD
- User asks "generate a token for the gateway"
- User wants to revoke or delete a token
- User needs a PAT for automated deployments or gitops

</objective>

<instructions>

## Step 1: Preflight

Run the `status` skill first to verify `TFY_BASE_URL` and `TFY_API_KEY` are set and valid.

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

## Step 2: List Access Tokens

### Via MCP
```
tfy_access_tokens_list()
```

### Via Direct API
```bash
TFY_API_SH=~/.claude/skills/truefoundry-access-tokens/scripts/tfy-api.sh

# List all personal access tokens
$TFY_API_SH GET /api/svc/v1/personal-access-tokens
```

Present results:
```
Personal Access Tokens:
| Name          | ID       | Created At  | Expires At  |
|---------------|----------|-------------|-------------|
| ci-pipeline   | pat-abc  | 2025-01-15  | 2025-07-15  |
| dev-local     | pat-def  | 2025-03-01  | Never       |
```

**Security:** Never display token values. They are only shown once at creation time.

## Step 3: Create Access Token

Ask the user for a token name before creating.

### Via MCP
```
tfy_access_tokens_create(payload={"name": "my-token"})
```

**Note:** Requires human approval (HITL) via MCP.

### Via Direct API
```bash
# Create a new personal access token
$TFY_API_SH POST /api/svc/v1/personal-access-tokens '{"name":"my-token"}'
```

**IMPORTANT:** The token value is returned ONLY in the creation response. Instruct the user to save it immediately — it cannot be retrieved later.

Present the result:
```
Token created successfully!
Name: my-token
Token: tfy-XXXXXXXXXXXXXXXXXXXXXXXX

⚠️  Save this token now — it will not be shown again.
```

## Step 4: Delete Access Token

Ask for confirmation before deleting — this is irreversible and will break any integrations using the token.

### Via MCP
```
tfy_access_tokens_delete(id="TOKEN_ID")
```

**Note:** Requires human approval (HITL) via MCP.

### Via Direct API
```bash
# Delete a personal access token
$TFY_API_SH DELETE /api/svc/v1/personal-access-tokens/TOKEN_ID
```

</instructions>

<success_criteria>

## Success Criteria

- The user can list all personal access tokens in a formatted table
- The user can create a new token and receives the token value
- The user has been warned to save the token value immediately
- The user can delete a token after confirmation
- The agent has never displayed existing token values — only new tokens at creation time

</success_criteria>

<references>

## Composability

- **AI Gateway**: PATs are used to authenticate AI Gateway requests (`ai-gateway` skill)
- **GitOps / CI/CD**: PATs are needed for automated deployments (`gitops` skill, `tfy-apply` skill)
- **Status**: Use `status` skill to verify a PAT is working
- **Secrets**: Store PATs as secrets for deployments (`secrets` skill)

## API Endpoints

See `references/api-endpoints.md` for the full Personal Access Tokens API reference.

</references>

<troubleshooting>

## Error Handling

### Permission Denied
```
Cannot manage access tokens. Check your API key permissions.
```

### Token Not Found
```
Token ID not found. List tokens first to find the correct ID.
```

### Token Name Already Exists
```
A token with this name already exists. Use a different name.
```

### Deleted Token Still In Use
```
If services fail after token deletion, they were using the deleted token.
Create a new token and update the affected services/pipelines.
```

### Cannot Retrieve Token Value
```
Token values are only shown at creation time. If lost, delete the old token
and create a new one, then update all services that used the old token.
```

</troubleshooting>
