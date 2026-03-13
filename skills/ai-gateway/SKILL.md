---
name: ai-gateway
description: Configures TrueFoundry AI Gateway for unified OpenAI-compatible LLM access. Covers auth (PAT/VAT), model routing, rate limiting, and budget controls.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *) Bash(curl*) Bash(python*)
---

> Routing note: For ambiguous user intents, use the shared clarification templates in [references/intent-clarification.md](references/intent-clarification.md).

<objective>

# AI Gateway

Use TrueFoundry's AI Gateway to access 1000+ LLMs through a unified OpenAI-compatible API with rate limiting, budget controls, load balancing, routing, and observability.

## When to Use

Access LLMs through TrueFoundry's unified OpenAI-compatible gateway, configure auth tokens (PAT/VAT), set up rate limiting, budget controls, or load balancing across providers. **Attach a model to the user's gateway:** when the user wants to add a provider or model (e.g. "add OpenAI to my gateway", "attach this URL to the gateway", "connect my Anthropic API key") — collect provider/URL and credentials, generate the provider-account manifest, and apply with `tfy apply -f <file>`.

## When NOT to Use

- User wants to deploy a self-hosted model → prefer `llm-deploy` skill; ask if the user wants another valid path (then connect to gateway)
- User wants to deploy tool servers → prefer `deploy` skill; ask if the user wants another valid path (service with tool-proxy)
- User wants to manage TrueFoundry platform credentials → prefer `status` skill; ask if the user wants another valid path

</objective>

<context>

## Overview

The AI Gateway sits between your application and LLM providers:

```
Your App → AI Gateway → OpenAI / Anthropic / Azure / Self-hosted vLLM / etc.
                ↑
         Unified API + Auth + Rate Limiting + Routing + Logging
```

**Key benefits:**
- **Single endpoint** for all models (cloud + self-hosted)
- **One API key** (PAT or VAT) instead of managing per-provider keys
- **OpenAI-compatible** — works with any OpenAI SDK client
- **Rate limiting** per user, team, or application
- **Budget controls** to enforce cost limits
- **Load balancing** across model instances with fallback
- **Observability** — request logging, cost tracking, analytics

## Getting started (new users)

Prefer this order for zero-to-gateway onboarding:

1. **Register:** Run `tfy register`. It prompts for company name, email, and use case (AI Gateway / LLMOps), asks you to accept T&C, then sends a 6-digit verification code to your email. After entering the code you are logged in — no separate `tfy login` needed.
2. **Optional — install agent skills:** `tfy register` asks "Install TrueFoundry agent skills now?" at the end. Say yes, or run later: `npx skills add truefoundry/tfy-agent-skills`.
3. **First gateway request:** Use the session token from `tfy register` (stored in `~/.truefoundry/credentials`), or create a PAT from the dashboard (**Access** → **Personal Access Tokens**). For production apps, create a VAT instead.
4. **Set up models and providers** via the dashboard or YAML manifests.

## Gateway Endpoint

The gateway base URL is your TrueFoundry platform URL + `/api/llm`:

```
{TFY_BASE_URL}/api/llm
```

Example: `https://your-org.truefoundry.cloud/api/llm`

## Authentication

### Personal Access Token (PAT)

For development and individual use:

1. Go to TrueFoundry dashboard → **Access** → **Personal Access Tokens**
2. Click **New Personal Access Token**
3. Copy the token

### Virtual Access Token (VAT)

For production applications (recommended):

1. Go to TrueFoundry dashboard → **Access** → **Virtual Account Tokens**
2. Click **New Virtual Account** (requires admin privileges)
3. Name it and **select which models** it can access
4. Copy the token

**VATs are recommended for production** because:
- Not tied to a specific user (survives team changes)
- Support granular model access control
- Better for tracking per-application usage

</context>

<instructions>

## Calling Models

### Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    api_key="<your-PAT-or-VAT>",
    base_url="https://<your-truefoundry-url>/api/llm",
)

# Chat completion
response = client.chat.completions.create(
    model="openai/gpt-4o",  # or any configured model name
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello!"},
    ],
    max_tokens=200,
)
print(response.choices[0].message.content)
```

### Python (Streaming)

```python
stream = client.chat.completions.create(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Write a haiku about AI"}],
    stream=True,
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

### cURL

```bash
curl "${TFY_BASE_URL}/api/llm/chat/completions" \
  -H "Authorization: Bearer ${TFY_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "openai/gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 200
  }'
```

### JavaScript / Node.js

```javascript
import OpenAI from "openai";

const client = new OpenAI({
  apiKey: "<your-PAT-or-VAT>",
  baseURL: "https://<your-truefoundry-url>/api/llm",
});

const response = await client.chat.completions.create({
  model: "openai/gpt-4o",
  messages: [{ role: "user", content: "Hello!" }],
});
```

### Environment Variables

Set these to use with any OpenAI-compatible library:

```bash
export OPENAI_BASE_URL="${TFY_BASE_URL}/api/llm"
export OPENAI_API_KEY="<your-PAT-or-VAT>"
```

Then any code using `openai.OpenAI()` without explicit parameters will use the gateway automatically.

## Supported APIs

| API | Endpoint | Description |
|-----|----------|-------------|
| **Chat Completions** | `/chat/completions` | Chat with any model (streaming + non-streaming) |
| **Completions** | `/completions` | Legacy text completions |
| **Embeddings** | `/embeddings` | Text embeddings (text + list inputs) |
| **Image Generation** | `/images/generations` | Generate images |
| **Image Editing** | `/images/edits` | Edit images |
| **Audio Transcription** | `/audio/transcriptions` | Speech-to-text |
| **Audio Translation** | `/audio/translations` | Translate audio |
| **Text-to-Speech** | `/audio/speech` | Generate speech |
| **Reranking** | `/rerank` | Rerank documents |
| **Batch Processing** | `/batches` | Batch predictions |
| **Moderations** | `/moderations` | Content safety |

## Supported Providers

The gateway supports 25+ providers including:

| Provider | Example Model Names |
|----------|-------------------|
| OpenAI | `openai/gpt-4o`, `openai/gpt-4o-mini` |
| Anthropic | `anthropic/claude-sonnet-4-5-20250929` |
| Google Vertex | `google/gemini-2.0-flash` |
| AWS Bedrock | `bedrock/anthropic.claude-3-5-sonnet` |
| Azure OpenAI | `azure/gpt-4o` |
| Mistral | `mistral/mistral-large-latest` |
| Groq | `groq/llama-3.1-70b-versatile` |
| Cohere | `cohere/command-r-plus` |
| Together AI | `together/meta-llama/Meta-Llama-3.1-70B` |
| Self-hosted (vLLM/TGI) | `my-custom-model-name` |

**Model names depend on how they're configured in your gateway.** Check the TrueFoundry dashboard → AI Gateway → Models for exact names.

## Attach model to gateway

When the user wants to **add a model to their gateway** (e.g. "attach this model to my gateway", "add OpenAI to my gateway", "attach llama to gateway", "connect this URL to the gateway"):

**Ask for clarity; do not assume.** If the user’s request is vague (e.g. "attach llama to gateway", "add this model"), ask for the missing details before generating a manifest. Do not guess provider, URL, model id, or credentials. For example: "Attach llama to gateway" could mean a self-hosted Llama URL, or Llama on Together AI, or another provider — ask which one and for the URL or API key and model id as needed. Only after you have provider/URL, credentials (or secret FQN), and model identifier(s) should you generate and apply the manifest.

1. **Collect details** from the user:
   - **Cloud provider** (OpenAI, Anthropic, Azure OpenAI, AWS Bedrock, Google Vertex/Gemini, Cohere, Groq, Mistral, etc.): provider name, API key (or secret FQN), and model id(s) to enable.
   - **External URL** (OpenAI-compatible endpoint): URL, optional auth (bearer or basic), hosted model name, model types (e.g. chat).
   - **Cluster-internal self-hosted**: after a model is deployed with `llm-deploy`, internal URL `http://<svc>.<namespace>.svc.cluster.local:8000` and model name.
2. **Generate** a provider-account manifest (YAML) matching the provider type. Use the structures below; for any provider not explicitly shown, use the same pattern: `type: provider-account/<provider>`, `name`, `auth_data` (if required), `integrations` with `type: integration/model/<provider>`, `model_id` (or `url`/`hosted_model_name` for self-hosted).
3. **Write** the manifest to a file (e.g. `gateway.yaml`) and run:
   ```bash
   tfy apply -f gateway.yaml --dry-run --show-diff   # optional preview
   tfy apply -f gateway.yaml
   ```
4. **Tell the user** the model will be available as `{provider-account-name}/{integration-name}` (e.g. `openai-prod/gpt-4o`) and how to call it (gateway endpoint + PAT/VAT).

All providers shown in the dashboard (AI Gateway → Models → Add Provider Account) can be attached this way via manifest; the schema for each is in `servicefoundry-server/src/autogen/models.ts`.

### Deploy and attach (single flow)

When the user says **"deploy and attach to gateway"** (or "deploy this and attach it to the gateway"):

1. **Deploy first:** Use the right skill for what they’re deploying — `deploy` for an MCP/service, `llm-deploy` for a self-hosted LLM. Get the deployment to a healthy state and note the **endpoint URL** (and transport/auth for MCP).
2. **Attach next:** Using that URL (and any other details from step 1), attach to the gateway — for **models**: generate a `provider-account/self-hosted-model` manifest with the internal/public URL and apply with `tfy apply`; for **MCP**: use the `mcp-servers` skill (or `provider-account/mcp-server-group` manifest) to register the endpoint. No need to ask again for URL if it came from the deploy; if anything is missing (e.g. transport for MCP), ask only for that.

So yes — **deploy and attach in one go** is supported: do deploy, then attach using the resulting endpoint.

## Adding Models & Providers

You can add models by **generating a provider-account manifest and applying it** with `tfy apply -f gateway.yaml`. This works for every provider shown in the dashboard (OpenAI, Anthropic, AWS Bedrock, Google Vertex/Gemini, Azure OpenAI, Cohere, Groq, Mistral, Perplexity, Together, xAI, OpenRouter, AI21, etc.) as well as self-hosted and external URLs. Alternatively, users can add providers via the TrueFoundry dashboard (AI Gateway → Models → Add Provider Account).

### Cloud providers (OpenAI, Anthropic, etc.)

Generate a manifest with `type: provider-account/<provider>`, `name`, `auth_data` (API key or `tfy-secret://` FQN), and `integrations` (each with `type: integration/model/<provider>`, `name`, `model_id`, `model_types`). Example — **OpenAI**:

```yaml
# openai-gateway.yaml — attach OpenAI to gateway
name: openai-prod
type: provider-account/openai
auth_data:
  type: api-key
  api_key: "tfy-secret://<tenant>:<secret-group>:<key>"   # or user's API key
integrations:
  - name: gpt-4o
    type: integration/model/openai
    model_id: gpt-4o
    model_types: ["chat"]
  - name: gpt-4o-mini
    type: integration/model/openai
    model_id: gpt-4o-mini
    model_types: ["chat"]
```

Example — **Anthropic**:

```yaml
# anthropic-gateway.yaml — attach Anthropic to gateway
name: anthropic-prod
type: provider-account/anthropic
auth_data:
  type: api-key
  api_key: "tfy-secret://<tenant>:<secret-group>:<key>"
integrations:
  - name: claude-sonnet
    type: integration/model/anthropic
    model_id: claude-3-5-sonnet-20241022
    model_types: ["chat"]
```

Apply with `tfy apply -f openai-gateway.yaml` (or the chosen file). The model is then callable as `openai-prod/gpt-4o`, `anthropic-prod/claude-sonnet`, etc.

**Provider reference (cloud):** Use the same pattern for other cloud providers. Key fields:

| Provider (type) | Integration type | Auth | Model identifier |
|-----------------|------------------|------|-------------------|
| provider-account/openai | integration/model/openai | auth_data.type: api-key, api_key | model_id |
| provider-account/anthropic | integration/model/anthropic | auth_data.type: api-key, api_key | model_id |
| provider-account/google-vertex | integration/model/google-vertex | (see schema) | model_id |
| provider-account/google-gemini | integration/model/google-gemini | (see schema) | model_id |
| provider-account/azure-openai | integration/model/azure-openai | (see schema) | model_id |
| provider-account/aws-bedrock | integration/model/aws-bedrock | (see schema) | model_id |
| provider-account/cohere | integration/model/cohere | auth_data | model_id |
| provider-account/groq | integration/model/groq | auth_data | model_id |
| provider-account/mistral-ai | integration/model/mistral-ai | auth_data | model_id |
| provider-account/openrouter | integration/model/openrouter | auth_data | model_id |
| … (others) | integration/model/<provider> | per schema | model_id |

For exact fields (auth_data shape, optional base_url, etc.) consult `servicefoundry-server/src/autogen/models.ts`. Store API keys in TrueFoundry secrets and reference as `tfy-secret://<tenant>:<group>:<key>` where supported.

### Self-hosted (cluster-internal)

After deploying a model with the `llm-deploy` skill, attach it to the gateway via manifest or UI:

**Option A — Manifest:** Use `provider-account/self-hosted-model` with internal URL:

```yaml
# self-hosted-internal.yaml
name: my-llama
type: provider-account/self-hosted-model
integrations:
  - name: llama-3
    type: integration/model/self-hosted-model
    hosted_model_name: meta-llama/Llama-3.2-3B
    url: "http://my-llama-service.my-namespace.svc.cluster.local:8000"
    model_server: "openai-compatible"
    model_types: ["chat"]
```

Then `tfy apply -f self-hosted-internal.yaml`. Call as `my-llama/llama-3`.

**Option B — Dashboard:** AI Gateway → Models → Add Provider Account → Self-Hosted → enter the same internal URL.

### External OpenAI-compatible APIs (NVIDIA, custom endpoints)

For externally hosted OpenAI-compatible APIs (e.g. NVIDIA Cloud, custom inference URL), use `provider-account/self-hosted-model` with `url` and optional `auth_data`:

```yaml
# gateway.yaml — external hosted API (e.g. NVIDIA Cloud)
name: nvidia-external
type: provider-account/self-hosted-model
integrations:
  - name: nemotron-nano
    type: integration/model/self-hosted-model
    hosted_model_name: nvidia/nemotron-3-nano-30b-a3b
    url: "https://integrate.api.nvidia.com/v1"
    model_server: "openai-compatible"
    model_types: ["chat"]
    auth_data:
      type: bearer-auth
      bearer_token: "tfy-secret://<tenant>:<group>:<key>"
```

Reference in routing as `"nvidia-external/nemotron-nano"`. Apply with `tfy apply -f gateway.yaml`.

> **WARNING:** `provider-account/nvidia-nim` does **not** exist. Use `provider-account/self-hosted-model` with `auth_data` for all external OpenAI-compatible APIs.

> **Security:** Only register endpoints you control. Prefer internal cluster DNS (`svc.cluster.local`) for self-hosted. Store credentials in TrueFoundry secrets; use `tfy-secret://` in manifests.

> **Schema source of truth:** Authoritative field names and types: `servicefoundry-server/src/autogen/models.ts`. Do not guess field names from documentation alone.

## Applying Gateway Config

Gateway YAML is applied directly with `tfy apply` — no service build or Docker image involved:

```bash
# Preview changes
tfy apply -f gateway.yaml --dry-run --show-diff

# Apply
tfy apply -f gateway.yaml
```

**Do NOT delegate gateway applies to the `deploy` skill** (which is for service/application deployments). Gateway configs (`type: gateway-*`, `type: provider-account/*`) are applied inline with `tfy apply`.

**Test after apply:** Use the model name `{provider-account-name}/{integration-name}` (e.g. `openai-prod/gpt-4o`, `nvidia-external/nemotron-nano`):

```bash
curl "${TFY_BASE_URL}/api/llm/chat/completions" \
  -H "Authorization: Bearer ${TFY_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model": "<account>/<integration>", "messages": [{"role": "user", "content": "Hello!"}], "max_tokens": 50}'
```

Or via Python:
```python
from openai import OpenAI
client = OpenAI(api_key="<PAT-or-VAT>", base_url=f"{TFY_BASE_URL}/api/llm")
resp = client.chat.completions.create(model="<account>/<integration>", messages=[{"role": "user", "content": "Hello!"}])
print(resp.choices[0].message.content)
```

> **Note:** The `deploy` skill reference in the Routing Config section below is only for CI/CD GitOps pipelines — not for one-off gateway config applies.

## Load Balancing & Routing

The gateway supports intelligent request routing across multiple model instances.

### Weight-Based Routing

Distribute requests proportionally:
- 90% to Azure GPT-4o (primary)
- 10% to OpenAI GPT-4o (overflow)

### Latency-Based Routing

Automatically route to the lowest-latency model:
- Measures time per output token over last 20 minutes
- Models within 1.2x of fastest are treated equally
- Models with < 3 recent requests get preferential routing for data collection

### Priority-Based Routing

Route to highest-priority healthy model with SLA cutoff:
- Monitors average Time Per Output Token over 3-minute windows
- Auto-marks models unhealthy when TPOT exceeds threshold
- Automatic recovery when metrics improve

### Fallback Configuration

- **Default retry codes**: 429, 500, 502, 503
- **Default fallback codes**: 401, 403, 404, 429, 500, 502, 503
- Per-target retry attempts and delay intervals
- Auto-failover to backup models when primary is down

### Routing Config via GitOps

Routing configurations can be managed as YAML and applied via `tfy apply`:

```bash
# Store routing config in git, apply via CLI
tfy apply -f gateway-routing-config.yaml
```

See `deploy` skill (declarative apply workflow) and `gitops` skill for CI/CD integration.

## Rate Limiting

Control model usage per user, team, or application:

- **Requests per minute (RPM)** limits
- **Tokens per minute (TPM)** limits
- Per-model or global limits
- Configure via TrueFoundry dashboard → AI Gateway → Rate Limiting

## Budget Controls

Enforce cost limits:

- Per-user spending caps
- Per-team budgets
- Per-model cost limits
- Automatic blocking when budget exceeded
- Configure via TrueFoundry dashboard → AI Gateway → Budget Limiting

## Observability

### Request Logging

All gateway requests are logged with:
- Input/output tokens
- Latency (TTFT, total)
- Cost
- Model and provider
- User identity
- Custom metadata

### Custom Metadata

Tag requests with custom metadata for tracking:

```python
response = client.chat.completions.create(
    model="openai/gpt-4o",
    messages=[{"role": "user", "content": "Hello"}],
    extra_headers={
        "X-TFY-LOGGING-CONFIG": '{"project": "my-app", "environment": "production"}'
    },
)
```

### Analytics

View usage analytics in TrueFoundry dashboard:
- Requests/minute per model
- Tokens/minute per model
- Failures/minute per model
- Cost breakdown by model, user, team

### OpenTelemetry Integration

Export traces to your observability stack:
- Prometheus + Grafana
- Datadog
- Custom OTEL collectors

## Guardrails

For content filtering, PII detection, prompt injection prevention, and custom safety rules, use the `guardrails` skill. It configures guardrail providers and rules that apply to this gateway's traffic.

## MCP server attachment to gateway

Attaching MCP servers to the AI gateway is supported. The same gateway that serves LLM models also exposes MCP servers (e.g. for tool use).

**Ask for clarity; do not assume.** If the user says "attach this MCP to gateway" or "attach MCP to gateway" without details, ask for: **MCP endpoint URL** (or which existing deployment to use), **transport** (streamable-http or sse), **auth** (if any; use secret references). Do not invent URLs or assume a deployment. The gateway is the user’s tenant gateway (from session); if the user has multiple gateways or contexts, confirm which one. Only after you have URL, transport, and auth (if needed) should you generate the manifest and apply or register.

Two options:

**Option A — mcp-servers skill (recommended for single remote/virtual servers):** Register the endpoint with a manifest (`mcp-server/remote`, `mcp-server/virtual`, or `mcp-server/openapi`) and use the MCP API. See the `mcp-servers` skill. Flow: verify deployment/endpoint → register via mcp-servers skill → confirm ID/name and policy reference.

**Option B — Provider-account manifest (same apply path as model providers):** Use `type: provider-account/mcp-server-group` with `name`, `collaborators`, and `integrations` (each `integration/mcp-server/remote` or `integration/mcp-server/virtual` with `name`, `description`, `url`, `transport`, optional `auth_data`). Apply with `tfy apply -f <file>`. Schema: `servicefoundry-server/src/autogen/models.ts` (MCPServerProviderAccount, MCPServerIntegration, VirtualMCPServerIntegration).

## Framework Integration

The gateway works with popular AI frameworks:

### LangChain

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model="openai/gpt-4o",
    api_key="<your-PAT-or-VAT>",
    base_url="https://<your-truefoundry-url>/api/llm",
)
```

### LlamaIndex

```python
from llama_index.llms.openai import OpenAI

llm = OpenAI(
    model="openai/gpt-4o",
    api_key="<your-PAT-or-VAT>",
    api_base="https://<your-truefoundry-url>/api/llm",
)
```

### Cursor / Claude Code / Cline

Configure the gateway as a custom API endpoint in your coding assistant settings:
- Base URL: `{TFY_BASE_URL}/api/llm`
- API Key: Your PAT or VAT

## Presenting Gateway Info

When the user asks about gateway configuration:

```
AI Gateway:
  Endpoint: https://your-org.truefoundry.cloud/api/llm
  Auth:     Personal Access Token (PAT) or Virtual Access Token (VAT)

Available Models (check dashboard for current list):
| Model Name        | Provider     | Type        |
|-------------------|-------------|-------------|
| openai/gpt-4o     | OpenAI      | Cloud       |
| my-gemma-2b       | Self-hosted | vLLM (T4)   |
| anthropic/claude   | Anthropic   | Cloud       |

Usage:
  export OPENAI_BASE_URL="https://your-org.truefoundry.cloud/api/llm"
  export OPENAI_API_KEY="your-token"
  # Then use any OpenAI-compatible SDK
```

</instructions>

<success_criteria>

## Success Criteria

- The user can call LLMs through the gateway endpoint using an OpenAI-compatible SDK or cURL
- The user has a valid authentication token (PAT or VAT) configured for gateway access
- The agent has confirmed the target model name is available in the user's gateway configuration
- The user can verify successful responses from the gateway with correct model output
- The agent has provided working code snippets tailored to the user's language and framework
- Rate limiting, budget controls, or routing are configured if the user requested them
- **Attach model:** When the user asked to add a model/provider, a valid provider-account manifest was generated and applied with `tfy apply`; the model is available as `{account-name}/{integration-name}` and the user knows how to call it

</success_criteria>

<references>

## Composability

- **Attach model to gateway**: Generate provider-account manifest from user's provider/URL and credentials, then `tfy apply -f <file>` (covers all dashboard providers and self-hosted).
- **Deploy model first**: Use `llm-deploy` skill to deploy a self-hosted model, then attach to gateway via manifest or dashboard.
- **Need API key**: Create PAT/VAT in TrueFoundry dashboard → Access; store provider API keys in secrets and use `tfy-secret://` in manifests.
- **Rate limiting**: Configure in dashboard → AI Gateway → Rate Limiting
- **Routing config**: Use `deploy` skill (declarative apply workflow) to apply routing YAML via GitOps
- **tool servers / MCP**: Use `deploy` skill to deploy tool servers; attach to gateway via `mcp-servers` skill or `provider-account/mcp-server-group` manifest + `tfy apply`
- **Check deployed models**: Use `applications` skill to see running model services
- **Benchmark through gateway**: Use your preferred load-testing tool against gateway endpoints

</references>

<troubleshooting>

## Error Handling

### 401 Unauthorized
```
Gateway authentication failed. Check:
- API key (PAT or VAT) is valid and not expired
- Using correct header: Authorization: Bearer <token>
```

### 403 Forbidden
```
Model access denied. Your token may not have access to this model.
- PATs inherit user permissions
- VATs only have access to explicitly selected models
- Check with your admin to grant model access
```

### 429 Rate Limited
```
Rate limit exceeded. Options:
- Wait and retry (check Retry-After header)
- Request higher limits from admin
- Use load balancing to distribute across providers
```

### 502/503 Provider Error
```
Upstream provider error. The gateway will automatically:
- Retry on configured status codes
- Fallback to alternate models if routing is configured
If persistent, check provider status page or self-hosted model health.
```

### Model Not Found
```
Model name not found in gateway. Check:
- Exact model name in TrueFoundry dashboard → AI Gateway → Models
- Provider account is active and model is enabled
- Your token has access to this model
```

</troubleshooting>
