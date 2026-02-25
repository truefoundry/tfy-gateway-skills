# Benchmark Configuration Parameters

Configuration reference for TrueFoundry LLM benchmarking (Application Catalog or custom script).

## Load Testing Parameters

| Parameter | Description | Recommended Starting Value |
|-----------|-------------|---------------------------|
| **Peak Concurrency** | Maximum number of concurrent users | Start with 1, then 2, 4, 8, 16 |
| **Ramp-up Rate** | Rate at which new users are added | 1 user per second |
| **Host URL** | Model endpoint (must support `v1/chat/completions`) | From deployed model's port config |
| **Total Requests** | Number of requests per concurrency level | 10-50 for quick tests, 100+ for accurate results |

## Model Settings

| Parameter | Description | How to Find |
|-----------|-------------|-------------|
| **Model Name** | The `served-model-name` from the deployment | Check deployment spec `env.MODEL_NAME` or vLLM `--served-model-name` flag |
| **Tokenizer** | HuggingFace tokenizer ID for token counting | Same as the HuggingFace model ID (e.g., `google/gemma-2-2b-it`) |
| **API Key** | Authentication token if endpoint requires it | From TrueFoundry secrets or AI Gateway config |

## Prompt Configuration

| Parameter | Description | Guidance |
|-----------|-------------|----------|
| **Max Output Tokens** | Maximum tokens to generate per response | 128-512 for typical tests; match production usage |
| **Prompt** | Input prompt for benchmark requests | Use representative prompts matching your production workload |
| **Prompt Token Range** | Min/max input token counts (for random prompts) | Vary to test different input lengths |

## Finding Model Configuration from Deployment Spec

For models deployed on TrueFoundry, extract configuration from the deployment:

```bash
# Get the deployment spec
# Via Tool Call:
# tfy_applications_list(workspace_fqn="WORKSPACE_FQN", application_name="MODEL_NAME")

# Via Direct API:
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=MODEL_NAME'
```

From the response, extract:
- **Model name**: `env.MODEL_NAME` or `env.VLLM_MODEL_NAME`
- **Host URL**: `ports[0].host` (the public URL)
- **Tokenizer**: `artifacts_download.artifacts[0].model_id` (the HuggingFace model ID)

## For AI Gateway Models

If benchmarking a model served through TrueFoundry's AI Gateway:
- Find the host URL and model identifier via the "</> Code" button in the AI Gateway section
- Use the workspace API key for authentication

## For External Models (OpenAI, Anthropic, etc.)

| Provider | Model Name | Host URL | Tokenizer |
|----------|-----------|----------|-----------|
| OpenAI | `gpt-4o` | `https://api.openai.com` | `Xenova/gpt-4o` (or equivalent) |
| Anthropic | `claude-3-5-sonnet-20241022` | `https://api.anthropic.com` | N/A (use approximate) |
