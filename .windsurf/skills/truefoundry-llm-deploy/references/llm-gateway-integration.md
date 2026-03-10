# AI Gateway Integration

After deploying a model, you can connect it to TrueFoundry's AI Gateway for unified API access, rate limiting, cost tracking, and routing across multiple models.

## How It Works

1. **Deploy your model** using this skill — it gets an internal endpoint (e.g., `http://gemma-2b-vllm.namespace.svc.cluster.local:8000`)
2. **Add as "Self Hosted" provider** in the AI Gateway UI (TrueFoundry dashboard — AI Gateway — Models — Add Provider)
3. **Configure routing** — weight-based, latency-based, or priority-based with fallbacks to other providers
4. **Access via unified endpoint** — all models (self-hosted + cloud) accessible at `https://<gateway-url>/api/llm` using OpenAI-compatible API

## Benefits

- **Unified API** — Switch between self-hosted and cloud models (OpenAI, Anthropic, etc.) without code changes
- **Rate limiting** — Per user, team, or application
- **Budget controls** — Enforce cost limits
- **Fallback routing** — Auto-failover to cloud models if self-hosted is down
- **Observability** — Request logging, analytics, cost tracking

## Client Example

```python
from openai import OpenAI

client = OpenAI(
    api_key="<TrueFoundry API Key or Virtual Access Token>",
    base_url="https://<truefoundry-gateway-url>/api/llm",
)

response = client.chat.completions.create(
    model="your-self-hosted-model-name",
    messages=[{"role": "user", "content": "Hello!"}],
)
```

## Gateway Config via GitOps

Gateway routing configs can be managed as YAML and applied via `tfy apply` (see `tfy-apply` and `gitops` skills):

```bash
tfy apply -f gateway-config.yaml
```

**Note:** Provider and routing configuration is primarily done through the TrueFoundry dashboard UI. Programmatic management is available via `tfy apply` with YAML configs.
