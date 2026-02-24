---
name: ai-gateway
description: Configures TrueFoundry AI Gateway for unified OpenAI-compatible LLM access. Covers auth (PAT/VAT), model routing, rate limiting, and budget controls. NOT for deploying models (use llm-deploy).
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *) Bash(curl*) Bash(python*)
---

<objective>

# AI Gateway

Use TrueFoundry's AI Gateway to access 1000+ LLMs through a unified OpenAI-compatible API with rate limiting, budget controls, load balancing, routing, and observability.

## When to Use

Access LLMs through TrueFoundry's unified OpenAI-compatible gateway, configure auth tokens (PAT/VAT), set up rate limiting, budget controls, or load balancing across providers.

## When NOT to Use

- User wants to deploy a self-hosted model → use `llm-deploy` skill (then connect to gateway)
- User wants to deploy MCP servers → use `mcp-server` skill
- User wants to manage TrueFoundry platform credentials → use `status` skill

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

## Adding Models & Providers

Currently done through the TrueFoundry dashboard UI:

1. Go to **AI Gateway → Models**
2. Click **Add Provider Account**
3. Select provider (OpenAI, Anthropic, etc.)
4. Enter API credentials
5. Select models to enable

### Adding Self-Hosted Models

After deploying a model with the `llm-deploy` skill:

1. Go to **AI Gateway → Models → Add Provider Account**
2. Select **"Self Hosted"** as the provider type
3. Enter the internal endpoint: `http://{model-name}.{namespace}.svc.cluster.local:8000`
4. The model becomes accessible through the gateway alongside cloud models

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

See `tfy-apply` and `gitops` skills for CI/CD integration.

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

The gateway supports content filtering via integrated guardrail providers:

- Azure PII / Content Safety
- Enkrypt AI
- Palo Alto Prisma
- Custom guardrail implementations

Configure via TrueFoundry dashboard → AI Gateway → Guardrails.

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

</success_criteria>

<references>

## Composability

- **Deploy model first**: Use `llm-deploy` skill to deploy a self-hosted model, then add to gateway
- **Need API key**: Create PAT/VAT in TrueFoundry dashboard → Access
- **Rate limiting**: Configure in dashboard → AI Gateway → Rate Limiting
- **Routing config**: Use `tfy-apply` skill to apply routing YAML via GitOps
- **MCP servers**: Use `mcp-server` skill to deploy tool servers, register in gateway
- **Check deployed models**: Use `applications` skill to see running model services
- **Benchmark through gateway**: Use `llm-benchmarking` skill to test gateway performance

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
