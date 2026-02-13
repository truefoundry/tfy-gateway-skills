---
name: llm-deploy
description: This skill should be used when the user asks "deploy a model", "deploy LLM", "serve a model", "deploy hugging face model", "deploy vLLM", "deploy TGI", "deploy NIM", "NVIDIA NIM", "inference server", or wants to deploy any ML/LLM model on TrueFoundry.
allowed-tools: Bash(*/tfy-api.sh *)
---

# LLM / Model Deployment

Deploy large language models and ML inference servers to TrueFoundry. Supports vLLM, TGI, and custom model servers with proper GPU allocation, model caching, health probes, and production-ready defaults.

## When to Use

- User says "deploy a model", "deploy LLM", "serve Gemma/Llama/Mistral/..."
- User says "deploy vLLM", "deploy TGI", "inference server"
- User wants to deploy a HuggingFace model for inference
- User wants GPU-accelerated model serving
- User wants to deploy NVIDIA NIM (optimized inference containers)

## When NOT to Use

- User wants to deploy a regular web app or API → use `deploy` skill
- User wants to deploy a database or Helm chart → use `helm` skill
- User wants to check what's deployed → use `applications` skill

## Prerequisites

**Always verify before deploying:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` is **required**. Never auto-pick. Ask the user if missing.

```bash
# Check credentials
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
echo "TFY_WORKSPACE_FQN: ${TFY_WORKSPACE_FQN:-(not set)}"
```

**If TFY_WORKSPACE_FQN is not set, STOP. Ask the user.** Suggest they use the `workspaces` skill or check the TrueFoundry dashboard.

## Step 0: Discover Cluster Capabilities

**Before asking the user about GPU types or public URLs**, fetch the cluster's capabilities.

### Get Cluster ID

Extract from workspace FQN (part before the colon):
- Workspace FQN `tfy-ea-dev-eo-az:sai-ws` → Cluster ID `tfy-ea-dev-eo-az`
- Or use `TFY_CLUSTER_ID` from environment if set.

### Fetch Cluster Details

When using direct API, use the **full path** to this skill's `scripts/tfy-api.sh`. The path depends on which agent is installed (e.g. `~/.claude/skills/truefoundry-llm-deploy/scripts/tfy-api.sh` for Claude Code). In the examples below, replace `TFY_API_SH` with the full path.

```bash
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

### Extract

1. **Base domains** — for public URL host construction (see Public URL section)
2. **Available GPUs** — only present GPU types that the cluster actually supports

## Step 1: Gather Model Details

Ask the user these questions:

```
I'll help you deploy an LLM. Let me gather a few details:

1. Which model? (e.g., google/gemma-2-2b-it, meta-llama/Llama-3.2-1B-Instruct)
2. Serving framework?
   - vLLM (recommended — fast, OpenAI-compatible)
   - TGI (HuggingFace Text Generation Inference)
   - Custom image
3. Does the model require authentication? (e.g., gated HuggingFace models needing HF_TOKEN)
   - If yes: Do you have a TrueFoundry secret group with the token, or should we set one up?
4. Access: Public URL or internal-only?
5. Environment: Dev/testing or production?
```

## Step 2: Select GPU & Resources

Based on the model, suggest appropriate resources. **Always check available GPUs from Step 0 first.**

### Model Size → GPU Mapping

| Model Params | Min VRAM (FP16) | Recommended GPU | CPU | Memory | Shared Memory |
|-------------|-----------------|-----------------|-----|--------|---------------|
| < 1B | ~2 GB | T4 (16 GB) | 4 | 16 GB | 15 GB |
| 1B–3B | ~4–6 GB | T4 (16 GB) or A10_8GB | 4–8 | 32 GB | 30 GB |
| 3B–7B | ~6–14 GB | T4 (16 GB) or A10_24GB | 8–10 | 64 GB | 60 GB |
| 7B–13B | ~14–26 GB | A10_24GB or A100_40GB | 10–12 | 90 GB | 88 GB |
| 13B–30B | ~26–60 GB | A100_40GB or A100_80GB | 12–16 | 128 GB | 120 GB |
| 30B–70B | ~60–140 GB | A100_80GB or H100 (multi-GPU) | 16+ | 200 GB+ | 190 GB+ |

**Present a resource suggestion table:**

```
Based on your model (gemma-2-2b-it, ~2B params):

| Resource           | Suggested     | Notes                                    |
|--------------------|---------------|------------------------------------------|
| GPU                | T4 (16 GB)    | 2B params @ FP16 ≈ 4 GB VRAM            |
| GPU count          | 1             | Single GPU sufficient for 2B model       |
| CPU request/limit  | 4 / 4 cores   | For tokenization + request handling      |
| Memory req/limit   | 32 / 40 GB    | Model loading + KV cache + overhead      |
| Shared memory      | 30 GB         | vLLM tensor operations need large /dev/shm |
| Ephemeral storage  | 50 / 50 GB    | Model download cache                     |
| Max model length   | 4096          | Context window (increase if needed)      |

Available GPUs on your cluster: [T4, A10_4GB, A10_8GB, A10_12GB, A10_24GB, H100_94GB]

Do you want to use these values, or adjust anything?
```

### Important: Shared Memory

**vLLM and TGI require large shared memory (`/dev/shm`).** Without it, the model server will crash or perform poorly. Set `shared_memory_size` to roughly 90–95% of `memory_request`.

### Important: Memory vs VRAM

System memory (RAM) must be **much larger** than GPU VRAM because:
- Model weights load into CPU RAM first before transferring to GPU
- KV cache and request batching use CPU memory
- The OS and Python runtime need memory too
- Rule of thumb: RAM should be 2–4x the model's VRAM footprint

## Step 3: Build the Manifest

### vLLM Manifest Template

This is the production-ready template based on TrueFoundry's proven defaults:

```yaml
type: service
name: {MODEL_NAME}
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/vllm/vllm-openai:v0.13.0
  command: >-
    python3 -u -m vllm.entrypoints.openai.api_server
    --host 0.0.0.0 --port 8000
    --download-dir /data/
    --tokenizer-mode auto
    --model '$(MODEL_ID)'
    --tokenizer '$(MODEL_ID)'
    --trust-remote-code
    --dtype '$(DTYPE)'
    --tensor-parallel-size '$(GPU_COUNT)'
    --gpu-memory-utilization '$(GPU_MEMORY_UTILIZATION)'
    --served-model-name '$(MODEL_NAME)'
    --root-path '$(TFY_SERVICE_ROOT_PATH)'
    --max-model-len '$(MAX_MODEL_LENGTH)'
    --async-scheduling
    --enable-prefix-caching
ports:
  - port: 8000
    expose: {EXPOSE}
    protocol: TCP
    app_protocol: http
    host: {HOST_IF_PUBLIC}
    path: {PATH_IF_PUBLIC}
env:
  DTYPE: {DTYPE}
  GPU_COUNT: '{GPU_COUNT}'
  MAX_MODEL_LENGTH: '{MAX_MODEL_LENGTH}'
  VLLM_NO_USAGE_STATS: '1'
  NVIDIA_REQUIRE_CUDA: 'cuda>=12.1'
  GPU_MEMORY_UTILIZATION: '0.90'
  MODEL_NAME: {MODEL_NAME}
  VLLM_CACHE_ROOT: /opt/truefoundry/.cache/vllm
  # Add HF_TOKEN if model is gated:
  # HF_TOKEN: tfy-secret://{TFY_BASE_DOMAIN}:{SECRET_GROUP}:{SECRET_KEY}
  # HUGGING_FACE_HUB_TOKEN: tfy-secret://{TFY_BASE_DOMAIN}:{SECRET_GROUP}:{SECRET_KEY}
workspace_fqn: {WORKSPACE_FQN}
artifacts_download:
  artifacts:
    - type: huggingface-hub
      model_id: {HF_MODEL_ID}
      revision: {REVISION_OR_MAIN}
      ignore_patterns:
        - '*.h5'
        - '*.ot'
        - '*.tflite'
        - '*.msgpack'
        - 'pytorch_model*.bin'
        - 'consolidated*.pth'
        - 'consolidated.*.pth'
        - 'consolidated.safetensors'
        - 'metal/*'
        - 'original/*'
      download_path_env_variable: MODEL_ID
  cache_volume:
    cache_size: {CACHE_SIZE_GB}
    storage_class: {STORAGE_CLASS}
replicas: {REPLICAS}
rollout_strategy:
  type: rolling_update
  max_surge_percentage: 0
  max_unavailable_percentage: 25
startup_probe:
  config:
    type: http
    path: /health
    port: 8000
  failure_threshold: 35
  initial_delay_seconds: 10
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 2
readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  failure_threshold: 5
  initial_delay_seconds: 3
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 2
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  failure_threshold: 10
  initial_delay_seconds: 3
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 2
labels:
  tfy_model_server: vLLM
  tfy_openapi_path: openapi.json
  tfy_sticky_session_header_name: x-truefoundry-sticky-session-id
  huggingface_model_task: text-generation
allow_interception: false
resources:
  devices:
    - type: nvidia_gpu
      count: {GPU_COUNT}
      name: {GPU_TYPE}
  cpu_request: {CPU_REQUEST}
  cpu_limit: {CPU_LIMIT}
  memory_request: {MEMORY_REQUEST_MB}
  memory_limit: {MEMORY_LIMIT_MB}
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: {EPHEMERAL_LIMIT_MB}
  shared_memory_size: {SHARED_MEMORY_MB}
```

### TGI Manifest Template

For HuggingFace Text Generation Inference:

```yaml
type: service
name: {MODEL_NAME}
image:
  type: image
  image_uri: ghcr.io/huggingface/text-generation-inference:2.4.1
  command: >-
    text-generation-launcher
    --model-id '$(MODEL_ID)'
    --port 8000
    --hostname 0.0.0.0
    --dtype '$(DTYPE)'
    --max-input-length '$(MAX_INPUT_LENGTH)'
    --max-total-tokens '$(MAX_TOTAL_TOKENS)'
    --num-shard '$(GPU_COUNT)'
ports:
  - port: 8000
    expose: {EXPOSE}
    protocol: TCP
    app_protocol: http
    host: {HOST_IF_PUBLIC}
env:
  DTYPE: float16
  GPU_COUNT: '{GPU_COUNT}'
  MAX_INPUT_LENGTH: '4096'
  MAX_TOTAL_TOKENS: '8192'
  # HF_TOKEN if gated model:
  # HUGGING_FACE_HUB_TOKEN: tfy-secret://{TFY_BASE_DOMAIN}:{SECRET_GROUP}:{SECRET_KEY}
workspace_fqn: {WORKSPACE_FQN}
artifacts_download:
  artifacts:
    - type: huggingface-hub
      model_id: {HF_MODEL_ID}
      revision: {REVISION_OR_MAIN}
      ignore_patterns:
        - '*.h5'
        - '*.ot'
        - '*.tflite'
        - '*.msgpack'
        - 'pytorch_model*.bin'
      download_path_env_variable: MODEL_ID
  cache_volume:
    cache_size: {CACHE_SIZE_GB}
    storage_class: {STORAGE_CLASS}
replicas: {REPLICAS}
startup_probe:
  config:
    type: http
    path: /health
    port: 8000
  failure_threshold: 40
  initial_delay_seconds: 15
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 2
readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  failure_threshold: 5
  initial_delay_seconds: 3
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 2
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  failure_threshold: 10
  initial_delay_seconds: 3
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 2
labels:
  tfy_model_server: TGI
  huggingface_model_task: text-generation
allow_interception: false
resources:
  devices:
    - type: nvidia_gpu
      count: {GPU_COUNT}
      name: {GPU_TYPE}
  cpu_request: {CPU_REQUEST}
  cpu_limit: {CPU_LIMIT}
  memory_request: {MEMORY_REQUEST_MB}
  memory_limit: {MEMORY_LIMIT_MB}
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: {EPHEMERAL_LIMIT_MB}
  shared_memory_size: {SHARED_MEMORY_MB}
```

## NVIDIA NIM Manifest Template

NVIDIA NIM (NVIDIA Inference Microservices) provides optimized containers for model inference with TensorRT-LLM acceleration.

### When to Use NIM

- User wants maximum inference performance with NVIDIA TensorRT-LLM optimization
- User has access to NVIDIA NGC registry
- Model is available as a NIM container (check NVIDIA NGC catalog)

### NIM Deployment

NIM models are deployed as pre-built container images from NVIDIA's NGC registry. The deployment is similar to vLLM but uses NVIDIA's optimized containers.

```yaml
type: service
name: {MODEL_NAME}-nim
image:
  type: image
  image_uri: nvcr.io/nim/{MODEL_PATH}:{VERSION}
ports:
  - port: 8000
    expose: {EXPOSE}
    protocol: TCP
    app_protocol: http
    host: {HOST_IF_PUBLIC}
env:
  NGC_API_KEY: tfy-secret://{TFY_BASE_DOMAIN}:{SECRET_GROUP}:{NGC_KEY}
  NIM_SERVED_MODEL_NAME: {MODEL_NAME}
workspace_fqn: {WORKSPACE_FQN}
replicas: {REPLICAS}
startup_probe:
  config:
    type: http
    path: /v1/health/ready
    port: 8000
  failure_threshold: 60
  initial_delay_seconds: 30
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 5
readiness_probe:
  config:
    type: http
    path: /v1/health/ready
    port: 8000
  failure_threshold: 5
  initial_delay_seconds: 10
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 5
liveness_probe:
  config:
    type: http
    path: /v1/health/live
    port: 8000
  failure_threshold: 10
  initial_delay_seconds: 10
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 5
labels:
  tfy_model_server: NIM
allow_interception: false
resources:
  devices:
    - type: nvidia_gpu
      count: {GPU_COUNT}
      name: {GPU_TYPE}
  cpu_request: {CPU_REQUEST}
  cpu_limit: {CPU_LIMIT}
  memory_request: {MEMORY_REQUEST_MB}
  memory_limit: {MEMORY_LIMIT_MB}
  ephemeral_storage_request: 50000
  ephemeral_storage_limit: {EPHEMERAL_LIMIT_MB}
  shared_memory_size: {SHARED_MEMORY_MB}
```

### NIM Prerequisites

1. **NGC API Key** — Required to pull NIM containers. Store in TrueFoundry secrets.
2. **Container registry access** — The cluster must have access to `nvcr.io` (NVIDIA's container registry).
3. **Compatible GPU** — NIM requires NVIDIA GPUs. A100 or H100 recommended for best performance.

### NIM Health Endpoints

NIM uses different health endpoints than vLLM:
- **Readiness**: `/v1/health/ready`
- **Liveness**: `/v1/health/live`
- **OpenAI-compatible API**: `/v1/chat/completions`, `/v1/completions`

### Common NIM Models

| Model | NGC Image | Min GPU |
|-------|-----------|---------|
| Llama 3.1 8B | `nvcr.io/nim/meta/llama-3.1-8b-instruct` | 1x A10G/A100 |
| Llama 3.1 70B | `nvcr.io/nim/meta/llama-3.1-70b-instruct` | 4x A100/2x H100 |
| Mistral 7B | `nvcr.io/nim/mistralai/mistral-7b-instruct-v0.3` | 1x A10G/A100 |

**Check NVIDIA NGC catalog** (https://catalog.ngc.nvidia.com) for the latest available NIM containers and versions.

## Template Variables Reference

Fill these based on user input and cluster capabilities:

| Variable | Description | Example |
|----------|-------------|---------|
| `{MODEL_NAME}` | Service name (lowercase, hyphens) | `gemma-2b-vllm` |
| `{HF_MODEL_ID}` | HuggingFace model ID | `google/gemma-2-2b-it` |
| `{REVISION_OR_MAIN}` | Model revision hash or `main` | `main` |
| `{WORKSPACE_FQN}` | TrueFoundry workspace FQN | `tfy-ea-dev-eo-az:sai-ws` |
| `{GPU_TYPE}` | GPU name from cluster (Step 0) | `T4`, `A10_24GB`, `H100_94GB` |
| `{GPU_COUNT}` | Number of GPUs | `1` |
| `{DTYPE}` | Data type for inference | `bfloat16` (A100/H100), `float16` (T4/A10) |
| `{MAX_MODEL_LENGTH}` | Context window length | `4096`, `8192`, `32768` |
| `{CPU_REQUEST}` / `{CPU_LIMIT}` | CPU cores | `4` / `4` to `12` / `12` |
| `{MEMORY_REQUEST_MB}` / `{MEMORY_LIMIT_MB}` | RAM in MB | `32768` / `40960` |
| `{SHARED_MEMORY_MB}` | Shared memory (`/dev/shm`) in MB | `30000` (≈90% of memory_request) |
| `{EPHEMERAL_LIMIT_MB}` | Ephemeral storage in MB | `50000` to `105000` |
| `{CACHE_SIZE_GB}` | Model cache volume size in GB | `22` (2x model size) |
| `{STORAGE_CLASS}` | Kubernetes storage class | Cluster-dependent (ask or omit for default) |
| `{REPLICAS}` | Number of replicas | `1` (dev), `2+` (prod) |
| `{EXPOSE}` | Public or internal | `true` or `false` |
| `{HOST_IF_PUBLIC}` | Public hostname | `gemma-2b-sai-ws.ml.tfy-eo.truefoundry.cloud` |
| `{PATH_IF_PUBLIC}` | Path prefix (optional, for path-based routing) | `/gemma-2b-sai-ws-8000-abc123/` |

### DTYPE Selection

| GPU Family | Recommended DTYPE | Notes |
|------------|------------------|-------|
| T4 | `float16` | No bfloat16 support on T4 |
| A10, A10G | `float16` | bfloat16 works but float16 is safer |
| A100, H100, H200 | `bfloat16` | Native bfloat16 support, better precision |
| L4, L40S | `bfloat16` | Ada Lovelace architecture supports bfloat16 |

## Step 4: Deploy

### Via Direct API

```bash
# Convert the YAML manifest to JSON and deploy
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": { ... JSON version of the manifest above ... },
  "workspaceId": "WORKSPACE_ID_HERE"
}'
```

**Note:** You need the workspace's internal ID (not FQN). Get it from:
```bash
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"
# → use the "id" field from the response
```

### Via MCP

```
tfy_applications_create_deployment(
    manifest={ ... manifest dict ... },
    options={"workspace_id": "ws-internal-id", "force_deploy": false}
)
```

## Step 5: Verify Deployment

After submitting, monitor the deployment:

1. **Check application status:**
   ```bash
   $TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=MODEL_NAME'
   ```

2. **LLM deployments take time** — GPU node provisioning (5–15 min if scaling up), model download (depends on model size), and model loading into GPU memory all happen before the service is ready. The startup probe allows up to 350 seconds (35 retries x 10s).

3. **Test the endpoint** (once healthy):
   ```bash
   # Health check
   curl https://{HOST}/health

   # OpenAI-compatible completion (vLLM)
   curl https://{HOST}/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "{MODEL_NAME}",
       "messages": [{"role": "user", "content": "Hello!"}],
       "max_tokens": 100
     }'
   ```

## Public URL

Same as the `deploy` skill — look up cluster base domains and construct the host.

1. Fetch cluster base domains: `$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID`
2. Pick wildcard domain, strip `*.` → base domain
3. Construct host: `{model-name}-{workspace-name}.{base_domain}`
4. **Alternative: path-based routing** — Use the cluster's base domain directly as `host` and set a unique `path` prefix. This avoids creating a new DNS entry per model.

## Artifacts Download (Model Caching)

**Always use `artifacts_download`** instead of downloading models at runtime via HF_TOKEN. This provides:

- **Cached downloads** — Model is downloaded once and cached on a persistent volume
- **Faster restarts** — Pod restarts don't re-download the model
- **Revision pinning** — Lock to a specific model commit for reproducibility
- **Ignore patterns** — Skip unnecessary file formats (PyTorch .bin, TensorFlow .h5, etc.)

### How It Works

```yaml
artifacts_download:
  artifacts:
    - type: huggingface-hub
      model_id: google/gemma-2-2b-it        # HuggingFace model repo
      revision: main                          # or specific commit hash
      ignore_patterns:                        # skip unused formats
        - '*.h5'
        - '*.ot'
        - '*.tflite'
        - '*.msgpack'
        - 'pytorch_model*.bin'
        - 'consolidated*.pth'
        - 'consolidated.*.pth'
        - 'consolidated.safetensors'
        - 'metal/*'
        - 'original/*'
      download_path_env_variable: MODEL_ID   # sets MODEL_ID env var to download path
  cache_volume:
    cache_size: 22                           # GB — should be ~2x model size
    storage_class: azureblob-nfs-premium     # cluster-dependent, omit for default
```

### Cache Size Guidelines

| Model Size | Recommended Cache |
|-----------|-------------------|
| < 2B params | 10–15 GB |
| 2B–7B params | 15–30 GB |
| 7B–13B params | 30–50 GB |
| 13B–30B params | 50–80 GB |
| 30B–70B params | 150–300 GB |

### Gated Models (Requiring HF Token)

For gated models (Llama, Gemma, etc.), set `HF_TOKEN` as an env var using a TrueFoundry secret:

```yaml
env:
  HF_TOKEN: tfy-secret://{tfy-base-domain}:{secret-group}:{secret-key}
  HUGGING_FACE_HUB_TOKEN: tfy-secret://{tfy-base-domain}:{secret-group}:{secret-key}
```

Both env vars are needed — `HF_TOKEN` for the HuggingFace SDK and `HUGGING_FACE_HUB_TOKEN` for the artifacts downloader.

Use the `secrets` skill to find or create the secret group.

## Health Probes

**Always include health probes for model deployments.** Without them, Kubernetes has no way to know when the model is ready and may kill pods prematurely or route traffic to unready pods.

### Why Each Probe Matters

| Probe | Purpose | LLM Considerations |
|-------|---------|---------------------|
| **Startup** | Wait for initial readiness | Models take minutes to load. 35 retries x 10s = 350s tolerance. |
| **Readiness** | Can this pod receive traffic? | Prevents routing to pods still loading the model. |
| **Liveness** | Is this pod alive? | Detects hung processes (OOM, GPU errors). |

### Default Probe Config

```yaml
startup_probe:
  config:
    type: http
    path: /health
    port: 8000
  failure_threshold: 35          # 35 x 10s = 350s max startup time
  initial_delay_seconds: 10      # wait 10s before first check
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 2

readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  failure_threshold: 5
  initial_delay_seconds: 3
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 2

liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  failure_threshold: 10
  initial_delay_seconds: 3
  period_seconds: 10
  success_threshold: 1
  timeout_seconds: 2
```

For very large models (30B+), increase startup `failure_threshold` to 60+ (600s+).

## Common vLLM Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--dtype` | `auto` | `float16` for T4/A10, `bfloat16` for A100/H100 |
| `--max-model-len` | Model default | Max context length. Reduce to save GPU memory. |
| `--gpu-memory-utilization` | `0.90` | Fraction of GPU memory to use (0.0–1.0) |
| `--tensor-parallel-size` | `1` | Number of GPUs for tensor parallelism. Must match `GPU_COUNT`. |
| `--trust-remote-code` | off | Required for some models (e.g., custom architectures) |
| `--served-model-name` | model path | Name exposed in OpenAI API. Set to a clean name. |
| `--root-path` | none | Use `$(TFY_SERVICE_ROOT_PATH)` for path-based routing |
| `--async-scheduling` | off | Better throughput for concurrent requests |
| `--enable-prefix-caching` | off | Reuse KV cache for common prompt prefixes |
| `--quantization` | none | `awq`, `gptq`, `squeezellm` for quantized models |
| `--download-dir` | default | Set to `/data/` to use the cache volume |
| `--tokenizer-mode` | `auto` | Usually leave as auto |

## User Confirmation Checklist

**Before deploying, confirm these with the user:**

- [ ] **Model** — HuggingFace model ID and revision
- [ ] **Framework** — vLLM, TGI, or NVIDIA NIM
- [ ] **GPU type & count** — from available cluster GPUs (Step 0)
- [ ] **Resources** — CPU, memory, shared memory (show suggestion table from Step 2)
- [ ] **DTYPE** — float16 or bfloat16 (based on GPU)
- [ ] **Max model length** — context window size
- [ ] **Access** — public URL or internal-only
- [ ] **Authentication** — HF token for gated models (from TrueFoundry secrets)
- [ ] **Environment** — dev (1 replica) or production (2+ replicas)
- [ ] **Service name** — what to call the deployment

## Connecting to AI Gateway

After deploying a model, you can connect it to TrueFoundry's AI Gateway for unified API access, rate limiting, cost tracking, and routing across multiple models.

### How It Works

1. **Deploy your model** using this skill → it gets an internal endpoint (e.g., `http://gemma-2b-vllm.namespace.svc.cluster.local:8000`)
2. **Add as "Self Hosted" provider** in the AI Gateway UI (TrueFoundry dashboard → AI Gateway → Models → Add Provider)
3. **Configure routing** — weight-based, latency-based, or priority-based with fallbacks to other providers
4. **Access via unified endpoint** — all models (self-hosted + cloud) accessible at `https://<gateway-url>/api/llm` using OpenAI-compatible API

### Benefits

- **Unified API** — Switch between self-hosted and cloud models (OpenAI, Anthropic, etc.) without code changes
- **Rate limiting** — Per user, team, or application
- **Budget controls** — Enforce cost limits
- **Fallback routing** — Auto-failover to cloud models if self-hosted is down
- **Observability** — Request logging, analytics, cost tracking

### Client Example

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

### Gateway Config via GitOps

Gateway routing configs can be managed as YAML and applied via `tfy apply` (see `tfy-apply` and `gitops` skills):

```bash
tfy apply -f gateway-config.yaml
```

**Note:** Provider and routing configuration is primarily done through the TrueFoundry dashboard UI. Programmatic management is available via `tfy apply` with YAML configs.

## Composability

- **Find workspace first**: Use `workspaces` skill to get workspace FQN
- **Check cluster GPUs**: Use `workspaces` skill for GPU type reference
- **Manage secrets**: Use `secrets` skill to create/find HF token secret groups
- **Check deployment status**: Use `applications` skill after deploying
- **View logs**: Use `logs` skill to debug startup issues
- **Deploy database alongside**: Use `helm` skill for vector DBs, caches, etc.
- **Connect to AI Gateway**: Add deployed model as a provider in the gateway (see above)
- **Benchmark performance**: Use `llm-benchmarking` skill to test throughput/latency
- **Fine-tune first**: Use `llm-finetuning` skill to customize a model before deploying

## Error Handling

### GPU Node Not Available
```
Deployment stuck in Pending — GPU node scaling up.
This can take 5–15 minutes if a new GPU node needs to be provisioned.
Check the TrueFoundry dashboard for pod events.
If it stays Pending for 15+ minutes, the cluster may not have the requested GPU type available.
```

### Out of Memory (OOM)
```
Pod killed with OOMKilled.
The model needs more memory than allocated.
Fix: Increase memory_request and memory_limit.
For vLLM: also increase shared_memory_size and try reducing --max-model-len or --gpu-memory-utilization.
```

### Model Download Failed
```
Model download failed during startup.
Check:
- HF_TOKEN is set correctly for gated models
- Model ID is correct (case-sensitive)
- Network access to huggingface.co from the cluster
```

### CUDA Out of Memory
```
CUDA out of memory on GPU.
The model is too large for the selected GPU.
Fix:
- Use a GPU with more VRAM
- Reduce --max-model-len
- Use quantization (--quantization awq/gptq)
- Reduce --gpu-memory-utilization (e.g., 0.85)
```

### Startup Probe Failed
```
Pod killed by startup probe (exceeded failure_threshold).
The model took too long to load.
Fix: Increase startup_probe.failure_threshold (e.g., 50 or 60).
Large models (13B+) may need 600s+ to load.
```

### Invalid GPU Type
```
"None of the nodepools support {GPU_TYPE}"
The error message lists valid devices. Use one of those instead.
Always check available GPUs from the cluster API before deploying.
```

### Host Not Configured
```
"Provided host is not configured in cluster"
The host domain doesn't match cluster base_domains.
Fix: Look up base domains via GET /api/svc/v1/clusters/CLUSTER_ID
Use the wildcard domain (e.g., *.ml.tfy-eo.truefoundry.cloud)
```
