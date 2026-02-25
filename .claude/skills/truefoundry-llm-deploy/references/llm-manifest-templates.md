# LLM Manifest Templates

Complete YAML manifest templates for deploying LLMs on TrueFoundry with vLLM, TGI, and NVIDIA NIM.

## vLLM Manifest Template

Production-ready template based on TrueFoundry's proven defaults:

```yaml
type: service
name: {MODEL_NAME}
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/vllm/vllm-openai:v0.13.0  # see references/container-versions.md
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

## TGI Manifest Template

For HuggingFace Text Generation Inference:

```yaml
type: service
name: {MODEL_NAME}
image:
  type: image
  image_uri: ghcr.io/huggingface/text-generation-inference:2.4.1  # see references/container-versions.md
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

### NIM Manifest

```yaml
type: service
name: {MODEL_NAME}-nim
image:
  type: image
  image_uri: nvcr.io/nim/{MODEL_PATH}:{VERSION}  # see references/container-versions.md
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

Check [NVIDIA NGC catalog](https://catalog.ngc.nvidia.com) for the latest available NIM containers and versions.

## Template Variables Reference

Fill these based on user input and cluster capabilities:

| Variable | Description | Example |
|----------|-------------|---------|
| `{MODEL_NAME}` | Service name (lowercase, hyphens) | `gemma-2b-vllm` |
| `{HF_MODEL_ID}` | HuggingFace model ID | `google/gemma-2-2b-it` |
| `{REVISION_OR_MAIN}` | Model revision hash or `main` | `main` |
| `{WORKSPACE_FQN}` | TrueFoundry workspace FQN | `my-cluster:my-workspace` |
| `{GPU_TYPE}` | GPU name from cluster (Step 0) | `T4`, `A10_24GB`, `H100_94GB` |
| `{GPU_COUNT}` | Number of GPUs | `1` |
| `{DTYPE}` | Data type for inference | `bfloat16` (A100/H100), `float16` (T4/A10) |
| `{MAX_MODEL_LENGTH}` | Context window length | `4096`, `8192`, `32768` |
| `{CPU_REQUEST}` / `{CPU_LIMIT}` | CPU cores | `4` / `4` to `12` / `12` |
| `{MEMORY_REQUEST_MB}` / `{MEMORY_LIMIT_MB}` | RAM in MB | `32768` / `40960` |
| `{SHARED_MEMORY_MB}` | Shared memory (`/dev/shm`) in MB | `30000` (approx 90% of memory_request) |
| `{EPHEMERAL_LIMIT_MB}` | Ephemeral storage in MB | `50000` to `105000` |
| `{CACHE_SIZE_GB}` | Model cache volume size in GB | `22` (2x model size) |
| `{STORAGE_CLASS}` | Kubernetes storage class | Cluster-dependent (ask or omit for default) |
| `{REPLICAS}` | Number of replicas | `1` (dev), `2+` (prod) |
| `{EXPOSE}` | Public or internal | `true` or `false` |
| `{HOST_IF_PUBLIC}` | Public hostname | `gemma-2b-my-workspace.ml.your-org.truefoundry.cloud` |
| `{PATH_IF_PUBLIC}` | Path prefix (optional, for path-based routing) | `/gemma-2b-my-workspace-8000-abc123/` |

### DTYPE Selection

| GPU Family | Recommended DTYPE | Notes |
|------------|------------------|-------|
| T4 | `float16` | No bfloat16 support on T4 |
| A10, A10G | `float16` | bfloat16 works but float16 is safer |
| A100, H100, H200 | `bfloat16` | Native bfloat16 support, better precision |
| L4, L40S | `bfloat16` | Ada Lovelace architecture supports bfloat16 |

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
| < 2B params | 10-15 GB |
| 2B-7B params | 15-30 GB |
| 7B-13B params | 30-50 GB |
| 13B-30B params | 50-80 GB |
| 30B-70B params | 150-300 GB |

### Gated Models (Requiring HF Token)

For gated models (Llama, Gemma, etc.), set `HF_TOKEN` as an env var using a TrueFoundry secret:

```yaml
env:
  HF_TOKEN: tfy-secret://{tfy-base-domain}:{secret-group}:{secret-key}
  HUGGING_FACE_HUB_TOKEN: tfy-secret://{tfy-base-domain}:{secret-group}:{secret-key}
```

Both env vars are needed -- `HF_TOKEN` for the HuggingFace SDK and `HUGGING_FACE_HUB_TOKEN` for the artifacts downloader.

Use the `secrets` skill to find or create the secret group.

## Common vLLM Flags

| Flag | Default | Description |
|------|---------|-------------|
| `--dtype` | `auto` | `float16` for T4/A10, `bfloat16` for A100/H100 |
| `--max-model-len` | Model default | Max context length. Reduce to save GPU memory. |
| `--gpu-memory-utilization` | `0.90` | Fraction of GPU memory to use (0.0-1.0) |
| `--tensor-parallel-size` | `1` | Number of GPUs for tensor parallelism. Must match `GPU_COUNT`. |
| `--trust-remote-code` | off | Required for some models (e.g., custom architectures) |
| `--served-model-name` | model path | Name exposed in OpenAI API. Set to a clean name. |
| `--root-path` | none | Use `$(TFY_SERVICE_ROOT_PATH)` for path-based routing |
| `--async-scheduling` | off | Better throughput for concurrent requests |
| `--enable-prefix-caching` | off | Reuse KV cache for common prompt prefixes |
| `--quantization` | none | `awq`, `gptq`, `squeezellm` for quantized models |
| `--download-dir` | default | Set to `/data/` to use the cache volume |
| `--tokenizer-mode` | `auto` | Usually leave as auto |
