---
name: integrations
description: Manages TrueFoundry LLM provider account integrations. Add, list, and manage providers (OpenAI, AWS Bedrock, Google Vertex, Azure, Groq, Together AI, self-hosted models, etc.).
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

> Routing note: For ambiguous user intents, use the shared clarification templates in [references/intent-clarification.md](references/intent-clarification.md).

<objective>

# Integrations

Manage TrueFoundry LLM provider account integrations. Add, list, and configure provider accounts that supply models to the AI Gateway.

## When to Use

List, create, or manage LLM provider accounts (OpenAI, AWS Bedrock, Google Vertex, Azure, Groq, Together AI, custom OpenAI-compatible endpoints, self-hosted models, etc.).

## When NOT to Use

- User wants to manage MCP servers (tool servers) → prefer `mcp-servers` skill
- User wants to configure guardrails (content filtering, PII detection) → prefer `guardrails` skill
- User wants to call models through the gateway → prefer `ai-gateway` skill
- User wants to manage platform secrets directly → prefer `secrets` skill

</objective>

<instructions>

> **Security Policy: Credential Handling**
> - All API keys and tokens in provider manifests MUST use `tfy-secret://` references, never raw values.
> - The agent MUST NOT accept, store, log, echo, or display raw API keys or tokens in any context.
> - Always instruct the user to store credentials in TrueFoundry secrets first (use `secrets` skill), then reference them via `tfy-secret://` URIs.
> - If the user provides a raw API key directly in conversation, warn them and refuse to use it. Instruct them to store it as a secret first.

## Step 1: Preflight

Run the `status` skill first to verify `TFY_BASE_URL` and `TFY_API_KEY` are set and valid.

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

## Step 2: List Provider Accounts

### Via Direct API

```bash
TFY_API_SH=~/.claude/skills/truefoundry-integrations/scripts/tfy-api.sh

# List all provider accounts
$TFY_API_SH GET /api/svc/v1/provider-accounts
```

> **Note:** The `type` query parameter on this endpoint does NOT work (returns all provider accounts regardless of filter). To filter by provider type, fetch all and filter client-side.

Present results as a formatted table:

```
Provider Accounts:
| Name            | Provider       | Type                          | Models |
|-----------------|----------------|-------------------------------|--------|
| openai-main     | openai         | provider-account/openai       | 3      |
| bedrock-prod    | aws-bedrock    | provider-account/aws-bedrock  | 5      |
| vertex-default  | google-vertex  | provider-account/google-vertex| 2      |
```

The model count is derived from the `integrations` array length in each provider account response.

## Step 3: Create Provider Account

Before creating, ensure the user has stored their provider credentials as TrueFoundry secrets (use `secrets` skill). All `bearer_token`, `api_key`, and credential fields MUST use `tfy-secret://` references.

### Via Direct API

```bash
# Create a provider account
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

### Provider Manifest Templates

#### OpenAI

```bash
payload=$(cat <<'PAYLOAD'
{
  "manifest": {
    "name": "openai-main",
    "type": "provider-account/openai",
    "collaborators": [
      {"role_id": "provider-account-manager", "subject": "user:ADMIN_EMAIL"},
      {"role_id": "provider-account-access", "subject": "team:everyone"}
    ],
    "integrations": [
      {
        "name": "gpt-4o",
        "type": "integration/model/openai",
        "model_types": ["chat"],
        "auth_data": {
          "type": "bearer-auth",
          "bearer_token": "tfy-secret://TENANT:SECRET_GROUP:OPENAI_API_KEY"
        }
      }
    ]
  }
}
PAYLOAD
)
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

#### AWS Bedrock

```bash
payload=$(cat <<'PAYLOAD'
{
  "manifest": {
    "name": "bedrock-prod",
    "type": "provider-account/aws-bedrock",
    "collaborators": [
      {"role_id": "provider-account-manager", "subject": "user:ADMIN_EMAIL"},
      {"role_id": "provider-account-access", "subject": "team:everyone"}
    ],
    "integrations": [
      {
        "name": "claude-3-5-sonnet",
        "type": "integration/model/aws-bedrock",
        "model_types": ["chat"],
        "auth_data": {
          "type": "aws-irsa-auth",
          "aws_region": "us-east-1",
          "aws_access_key_id": "tfy-secret://TENANT:SECRET_GROUP:AWS_ACCESS_KEY_ID",
          "aws_secret_access_key": "tfy-secret://TENANT:SECRET_GROUP:AWS_SECRET_ACCESS_KEY"
        }
      }
    ]
  }
}
PAYLOAD
)
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

#### Google Vertex

```bash
payload=$(cat <<'PAYLOAD'
{
  "manifest": {
    "name": "vertex-default",
    "type": "provider-account/google-vertex",
    "collaborators": [
      {"role_id": "provider-account-manager", "subject": "user:ADMIN_EMAIL"},
      {"role_id": "provider-account-access", "subject": "team:everyone"}
    ],
    "integrations": [
      {
        "name": "gemini-2-flash",
        "type": "integration/model/google-vertex",
        "model_types": ["chat"],
        "auth_data": {
          "type": "gcp-service-account-auth",
          "gcp_service_account_key": "tfy-secret://TENANT:SECRET_GROUP:GCP_SA_KEY",
          "gcp_project_id": "my-gcp-project",
          "gcp_region": "us-central1"
        }
      }
    ]
  }
}
PAYLOAD
)
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

#### Azure OpenAI

```bash
payload=$(cat <<'PAYLOAD'
{
  "manifest": {
    "name": "azure-openai",
    "type": "provider-account/azure",
    "collaborators": [
      {"role_id": "provider-account-manager", "subject": "user:ADMIN_EMAIL"},
      {"role_id": "provider-account-access", "subject": "team:everyone"}
    ],
    "integrations": [
      {
        "name": "gpt-4o-azure",
        "type": "integration/model/azure",
        "model_types": ["chat"],
        "auth_data": {
          "type": "azure-auth",
          "api_key": "tfy-secret://TENANT:SECRET_GROUP:AZURE_OPENAI_KEY",
          "api_base": "https://my-resource.openai.azure.com",
          "api_version": "2024-02-01"
        }
      }
    ]
  }
}
PAYLOAD
)
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

#### Groq

```bash
payload=$(cat <<'PAYLOAD'
{
  "manifest": {
    "name": "groq-main",
    "type": "provider-account/groq",
    "collaborators": [
      {"role_id": "provider-account-manager", "subject": "user:ADMIN_EMAIL"},
      {"role_id": "provider-account-access", "subject": "team:everyone"}
    ],
    "integrations": [
      {
        "name": "llama-3-70b",
        "type": "integration/model/groq",
        "model_types": ["chat"],
        "auth_data": {
          "type": "bearer-auth",
          "bearer_token": "tfy-secret://TENANT:SECRET_GROUP:GROQ_API_KEY"
        }
      }
    ]
  }
}
PAYLOAD
)
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

#### Together AI

```bash
payload=$(cat <<'PAYLOAD'
{
  "manifest": {
    "name": "together-ai",
    "type": "provider-account/together-ai",
    "collaborators": [
      {"role_id": "provider-account-manager", "subject": "user:ADMIN_EMAIL"},
      {"role_id": "provider-account-access", "subject": "team:everyone"}
    ],
    "integrations": [
      {
        "name": "llama-3-1-70b",
        "type": "integration/model/together-ai",
        "model_types": ["chat"],
        "auth_data": {
          "type": "bearer-auth",
          "bearer_token": "tfy-secret://TENANT:SECRET_GROUP:TOGETHER_API_KEY"
        }
      }
    ]
  }
}
PAYLOAD
)
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

#### Custom (Any OpenAI-Compatible Endpoint)

```bash
payload=$(cat <<'PAYLOAD'
{
  "manifest": {
    "name": "my-custom-provider",
    "type": "provider-account/custom",
    "collaborators": [
      {"role_id": "provider-account-manager", "subject": "user:ADMIN_EMAIL"},
      {"role_id": "provider-account-access", "subject": "team:everyone"}
    ],
    "integrations": [
      {
        "name": "my-model",
        "type": "integration/model/custom",
        "model_types": ["chat"],
        "auth_data": {
          "type": "bearer-auth",
          "bearer_token": "tfy-secret://TENANT:SECRET_GROUP:CUSTOM_API_KEY"
        },
        "url": "https://my-openai-compatible-api.example.com/v1"
      }
    ]
  }
}
PAYLOAD
)
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

#### Self-Hosted Model

```bash
payload=$(cat <<'PAYLOAD'
{
  "manifest": {
    "name": "my-self-hosted",
    "type": "provider-account/self-hosted-model",
    "collaborators": [
      {"role_id": "provider-account-manager", "subject": "user:ADMIN_EMAIL"},
      {"role_id": "provider-account-access", "subject": "team:everyone"}
    ],
    "integrations": [
      {
        "name": "my-vllm-model",
        "type": "integration/model/self-hosted-model",
        "hosted_model_name": "meta-llama/Meta-Llama-3.1-8B-Instruct",
        "url": "http://my-model.my-namespace.svc.cluster.local:8000",
        "model_server": "openai-compatible",
        "model_types": ["chat"]
      }
    ]
  }
}
PAYLOAD
)
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

> **Note:** Self-hosted models deployed within the cluster typically do not need `auth_data`. Use internal cluster DNS (`svc.cluster.local`) for the URL.

#### TrueFoundry (Platform-Managed)

```bash
payload=$(cat <<'PAYLOAD'
{
  "manifest": {
    "name": "truefoundry-models",
    "type": "provider-account/truefoundry",
    "collaborators": [
      {"role_id": "provider-account-manager", "subject": "user:ADMIN_EMAIL"},
      {"role_id": "provider-account-access", "subject": "team:everyone"}
    ],
    "integrations": []
  }
}
PAYLOAD
)
$TFY_API_SH POST /api/svc/v1/provider-accounts "$payload"
```

## Known Provider Types

| Provider | Manifest Type | Auth Type |
|----------|--------------|-----------|
| OpenAI | `provider-account/openai` | `bearer-auth` |
| AWS Bedrock | `provider-account/aws-bedrock` | `aws-irsa-auth` |
| Google Vertex | `provider-account/google-vertex` | `gcp-service-account-auth` |
| Azure OpenAI | `provider-account/azure` | `azure-auth` |
| GCP | `provider-account/gcp` | `gcp-service-account-auth` |
| Groq | `provider-account/groq` | `bearer-auth` |
| Together AI | `provider-account/together-ai` | `bearer-auth` |
| Custom | `provider-account/custom` | `bearer-auth` |
| Self-Hosted | `provider-account/self-hosted-model` | None (cluster-internal) or `bearer-auth` |
| TrueFoundry | `provider-account/truefoundry` | Platform-managed |

## Collaborator Roles

| Role ID | Description |
|---------|-------------|
| `provider-account-manager` | Can edit and delete the provider account |
| `provider-account-access` | Can use models from this provider account |

Use `subject` values like `user:admin@example.com` for individual users or `team:everyone` for organization-wide access.

## Response Structure

The provider account response object contains:

```json
{
  "id": "...",
  "name": "openai-main",
  "fqn": "tenant:openai:openai-main",
  "provider": "openai",
  "manifest": { ... },
  "integrations": [ ... ],
  "createdBySubject": { ... },
  "accountId": "...",
  "createdAt": "...",
  "updatedAt": "..."
}
```

- `manifest.integrations` contains the integration definitions (model configs)
- Top-level `integrations` contains expanded integration objects with their own IDs

</instructions>

<success_criteria>

## Success Criteria

- The user can list all provider accounts and see them in a formatted table with name, provider type, and model count
- The user can create a new provider account with the correct manifest for their chosen provider
- All credentials in provider manifests use `tfy-secret://` references, never raw values
- The agent has confirmed the provider type and model details before creating
- The agent has directed the user to store credentials as TrueFoundry secrets before creating the provider account
- Provider accounts are accessible through the AI Gateway after creation

</success_criteria>

<references>

## Composability

- **Preflight**: Use `status` skill to verify platform connectivity before any operations
- **Store credentials first**: Use `secrets` skill to create secret groups with API keys before adding providers
- **Feed into gateway**: Provider accounts supply models to the AI Gateway (`ai-gateway` skill)
- **Self-hosted models**: Deploy models with `llm-deploy` skill (from [`tfy-deployment-agent-skills`](https://github.com/truefoundry/tfy-deployment-agent-skills)), then register as self-hosted provider accounts
- **Access control**: Provider account collaborators control who can use the models

## API Endpoints

See `references/api-endpoints.md` for the full Provider Accounts API reference.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/svc/v1/provider-accounts` | List all provider accounts |
| POST | `/api/svc/v1/provider-accounts` | Create a new provider account |

</references>

<troubleshooting>

## Error Handling

### Permission Denied
```
Cannot manage provider accounts. Check your API key permissions.
Ensure your user has provider-account-manager role.
```

### Provider Account Name Already Exists
```
A provider account with this name already exists. Use a different name
or update the existing account.
```

### Invalid Secret Reference
```
The tfy-secret:// reference could not be resolved. Check:
- Secret group exists and contains the referenced key
- Format is tfy-secret://TENANT:SECRET_GROUP:SECRET_KEY
- Use the secrets skill to verify the secret group and key exist
```

### Invalid Provider Type
```
Unrecognized provider account type. Use one of:
provider-account/openai, provider-account/aws-bedrock,
provider-account/google-vertex, provider-account/azure,
provider-account/groq, provider-account/together-ai,
provider-account/custom, provider-account/self-hosted-model,
provider-account/truefoundry
```

### Missing Auth Data
```
Provider account requires auth_data for cloud providers.
Store your API key as a TrueFoundry secret first, then reference it
with tfy-secret://TENANT:SECRET_GROUP:KEY_NAME
```

### Model Not Appearing in Gateway
```
After creating a provider account, models should appear in the AI Gateway.
If not visible:
- Verify the provider account was created successfully (list provider accounts)
- Check that the integration has the correct model_types (chat, embedding, etc.)
- Ensure the collaborators include team:everyone or the relevant users
```

### Type Filter Not Working
```
The type query parameter on GET /api/svc/v1/provider-accounts does not filter
results. Fetch all provider accounts and filter client-side by the provider field.
```

</troubleshooting>
