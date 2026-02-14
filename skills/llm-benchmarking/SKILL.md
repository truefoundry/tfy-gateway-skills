---
name: llm-benchmarking
description: This skill should be used when the user asks "benchmark model", "test LLM performance", "load test model", "inference benchmark", "measure latency", "test throughput", "benchmark deployed model", "stress test LLM", or wants to evaluate the performance of a deployed LLM on TrueFoundry.
allowed-tools: Bash(python*), Bash(pip*), Bash(*/tfy-api.sh *)
---

# LLM Benchmarking on TrueFoundry

Benchmark deployed LLMs on TrueFoundry to measure latency, throughput, time to first token (TTFT), and other performance metrics. Uses TrueFoundry's LLM Benchmarking Tool deployed via the Application Catalog.

## When to Use

- User says "benchmark model", "test LLM performance", "load test model"
- User says "inference benchmark", "measure latency", "test throughput"
- User wants to evaluate how a deployed LLM performs under load
- User wants to compare performance across different model configurations
- User wants to find the right GPU/replica count for their use case
- User wants to measure TTFT, tokens per second, or inter-token latency

## When NOT to Use

- User wants to deploy an LLM → use `llm-deploy` skill
- User wants to deploy a regular web app → use `deploy` skill
- User wants to check deployment status → use `applications` skill
- User wants to fine-tune or train a model → not covered by this skill
- User wants to evaluate model quality (accuracy, BLEU, etc.) → not covered; this skill measures inference performance only

## Prerequisites

**Before benchmarking:**

1. **Deployed LLM** — The model must already be deployed and healthy on TrueFoundry. Use the `llm-deploy` skill to deploy one if needed.
2. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
3. **Model endpoint** — The deployed model's host URL (OpenAI-compatible `v1/chat/completions` endpoint)

For credential check commands and .env setup, see `references/prerequisites.md`. Use the `status` skill to verify connection. Use the `applications` skill to find the deployed model's endpoint URL.

## Key Metrics

The benchmarking tool measures these performance indicators:

| Metric | Description | Why It Matters |
|--------|-------------|----------------|
| **Requests per Second** | Number of API calls handled per second | Overall API throughput capacity |
| **Tokens per Second (TPS)** | Token generation rate across all concurrent requests | Model's raw generation throughput |
| **Time to First Token (TTFT)** | Time from request to first generated token (ms) | User-perceived responsiveness; critical for streaming |
| **Inter-Token Latency (ITL)** | Average delay between consecutive tokens (ms) | Smoothness of streaming output |
| **Response Time** | End-to-end request latency (seconds) | Total time to get a complete response |
| **Active Users** | Number of concurrent users during test | Load level at measurement point |

### Metric Relationships

- **TTFT** is dominated by prompt processing (prefill) time — longer prompts = higher TTFT
- **ITL** reflects decode speed — depends on GPU, model size, and batching
- **TPS** = total tokens generated per second across all concurrent requests
- **Response Time** ~ TTFT + (output_tokens x ITL)

## Benchmark Methodology

TrueFoundry's benchmarking tool uses a load-testing approach:

1. **Ramp-up** — Gradually increases concurrent users from 1 to peak concurrency
2. **Sustained load** — Holds peak concurrency to measure steady-state performance
3. **Metrics collection** — Records latency, throughput, and token-level timings per request
4. **Real-time dashboard** — Visualizes metrics as the test runs

This approach reveals how performance degrades under increasing load, helping you find the optimal concurrency level.

## Running Benchmarks

### Option 1: Deploy via TrueFoundry Application Catalog (Recommended)

The TrueFoundry Application Catalog provides a pre-built benchmarking tool that deploys as a web application with a dashboard.

1. **Navigate to the Application Catalog** in the TrueFoundry dashboard
2. **Select "Benchmark LLM performance"**
3. **Configure the deployment:**
   - **Name**: A name for the benchmarking tool instance (e.g., `llm-bench-gemma`)
   - **Host**: The endpoint URL for the benchmark dashboard

4. **Configure the benchmark parameters** (see Configuration section below)
5. **Launch and monitor** via the benchmark dashboard

### Option 2: Direct API Benchmark Script

For quick benchmarks without deploying the full tool, use a Python script that calls the model's OpenAI-compatible API:

```python
"""
Simple LLM benchmark script for TrueFoundry-deployed models.
Measures TTFT, TPS, and response time at varying concurrency levels.
"""

import asyncio
import time
import json
import statistics
from dataclasses import dataclass, field

import aiohttp


@dataclass
class BenchmarkResult:
    """Results from a single request."""
    ttft_ms: float = 0.0
    total_time_s: float = 0.0
    output_tokens: int = 0
    error: str = ""


@dataclass
class BenchmarkSummary:
    """Aggregated results for a concurrency level."""
    concurrency: int = 0
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    avg_ttft_ms: float = 0.0
    p50_ttft_ms: float = 0.0
    p99_ttft_ms: float = 0.0
    avg_response_time_s: float = 0.0
    tokens_per_second: float = 0.0
    requests_per_second: float = 0.0


# --- Configuration ---
MODEL_HOST = "https://your-model-host.truefoundry.cloud"  # Model endpoint URL
MODEL_NAME = "your-model-name"                             # Served model name
API_KEY = ""                                               # API key if required
PROMPT = "Write a detailed explanation of how neural networks learn through backpropagation."
MAX_OUTPUT_TOKENS = 256
CONCURRENCY_LEVELS = [1, 2, 4, 8, 16]                     # Test these concurrency levels
REQUESTS_PER_LEVEL = 10                                    # Requests per concurrency level


async def send_request(session: aiohttp.ClientSession, url: str, payload: dict,
                       headers: dict) -> BenchmarkResult:
    """Send a single chat completion request and measure timings."""
    result = BenchmarkResult()
    start = time.perf_counter()
    first_token_time = None

    try:
        async with session.post(url, json=payload, headers=headers) as resp:
            if resp.status != 200:
                result.error = f"HTTP {resp.status}"
                return result

            token_count = 0
            async for line in resp.content:
                decoded = line.decode("utf-8").strip()
                if not decoded.startswith("data: "):
                    continue
                data_str = decoded[6:]
                if data_str == "[DONE]":
                    break
                try:
                    data = json.loads(data_str)
                    delta = data.get("choices", [{}])[0].get("delta", {})
                    if delta.get("content"):
                        if first_token_time is None:
                            first_token_time = time.perf_counter()
                        token_count += 1
                except json.JSONDecodeError:
                    continue

            end = time.perf_counter()
            result.total_time_s = end - start
            result.output_tokens = token_count
            if first_token_time is not None:
                result.ttft_ms = (first_token_time - start) * 1000

    except Exception as e:
        result.error = str(e)

    return result


async def run_benchmark_at_concurrency(concurrency: int) -> BenchmarkSummary:
    """Run benchmark at a specific concurrency level."""
    url = f"{MODEL_HOST}/v1/chat/completions"
    headers = {"Content-Type": "application/json"}
    if API_KEY:
        headers["Authorization"] = f"Bearer {API_KEY}"

    payload = {
        "model": MODEL_NAME,
        "messages": [{"role": "user", "content": PROMPT}],
        "max_tokens": MAX_OUTPUT_TOKENS,
        "stream": True,
    }

    async with aiohttp.ClientSession() as session:
        semaphore = asyncio.Semaphore(concurrency)

        async def limited_request():
            async with semaphore:
                return await send_request(session, url, payload, headers)

        start = time.perf_counter()
        tasks = [limited_request() for _ in range(REQUESTS_PER_LEVEL)]
        results = await asyncio.gather(*tasks)
        wall_time = time.perf_counter() - start

    successful = [r for r in results if not r.error]
    failed = [r for r in results if r.error]

    summary = BenchmarkSummary(
        concurrency=concurrency,
        total_requests=len(results),
        successful_requests=len(successful),
        failed_requests=len(failed),
    )

    if successful:
        ttfts = [r.ttft_ms for r in successful if r.ttft_ms > 0]
        if ttfts:
            ttfts.sort()
            summary.avg_ttft_ms = statistics.mean(ttfts)
            summary.p50_ttft_ms = ttfts[len(ttfts) // 2]
            summary.p99_ttft_ms = ttfts[int(len(ttfts) * 0.99)]

        summary.avg_response_time_s = statistics.mean(r.total_time_s for r in successful)
        total_tokens = sum(r.output_tokens for r in successful)
        summary.tokens_per_second = total_tokens / wall_time if wall_time > 0 else 0
        summary.requests_per_second = len(successful) / wall_time if wall_time > 0 else 0

    return summary


async def main():
    print(f"Benchmarking: {MODEL_HOST}")
    print(f"Model: {MODEL_NAME}")
    print(f"Max output tokens: {MAX_OUTPUT_TOKENS}")
    print(f"Requests per level: {REQUESTS_PER_LEVEL}")
    print()

    header = (
        f"{'Concurrency':>12} | {'RPS':>8} | {'TPS':>8} | "
        f"{'Avg TTFT':>10} | {'P50 TTFT':>10} | {'P99 TTFT':>10} | "
        f"{'Avg Resp':>10} | {'OK':>4} | {'Fail':>4}"
    )
    print(header)
    print("-" * len(header))

    for level in CONCURRENCY_LEVELS:
        summary = await run_benchmark_at_concurrency(level)
        print(
            f"{summary.concurrency:>12} | "
            f"{summary.requests_per_second:>8.2f} | "
            f"{summary.tokens_per_second:>8.1f} | "
            f"{summary.avg_ttft_ms:>8.1f}ms | "
            f"{summary.p50_ttft_ms:>8.1f}ms | "
            f"{summary.p99_ttft_ms:>8.1f}ms | "
            f"{summary.avg_response_time_s:>8.2f}s | "
            f"{summary.successful_requests:>4} | "
            f"{summary.failed_requests:>4}"
        )


if __name__ == "__main__":
    asyncio.run(main())
```

**Usage:**

```bash
pip install aiohttp

# Edit the configuration variables at the top of the script, then run:
python benchmark_llm.py
```

## Configuration Parameters

When configuring the benchmarking tool (either via the Application Catalog or a custom script), set these parameters:

### Load Testing Parameters

| Parameter | Description | Recommended Starting Value |
|-----------|-------------|---------------------------|
| **Peak Concurrency** | Maximum number of concurrent users | Start with 1, then 2, 4, 8, 16 |
| **Ramp-up Rate** | Rate at which new users are added | 1 user per second |
| **Host URL** | Model endpoint (must support `v1/chat/completions`) | From deployed model's port config |
| **Total Requests** | Number of requests per concurrency level | 10-50 for quick tests, 100+ for accurate results |

### Model Settings

| Parameter | Description | How to Find |
|-----------|-------------|-------------|
| **Model Name** | The `served-model-name` from the deployment | Check deployment spec `env.MODEL_NAME` or vLLM `--served-model-name` flag |
| **Tokenizer** | HuggingFace tokenizer ID for token counting | Same as the HuggingFace model ID (e.g., `google/gemma-2-2b-it`) |
| **API Key** | Authentication token if endpoint requires it | From TrueFoundry secrets or AI Gateway config |

### Prompt Configuration

| Parameter | Description | Guidance |
|-----------|-------------|----------|
| **Max Output Tokens** | Maximum tokens to generate per response | 128-512 for typical tests; match production usage |
| **Prompt** | Input prompt for benchmark requests | Use representative prompts matching your production workload |
| **Prompt Token Range** | Min/max input token counts (for random prompts) | Vary to test different input lengths |

### Finding Model Configuration from Deployment Spec

For models deployed on TrueFoundry, extract configuration from the deployment:

```bash
# Get the deployment spec
# Via MCP:
# tfy_applications_list(workspace_fqn="WORKSPACE_FQN", application_name="MODEL_NAME")

# Via Direct API:
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=MODEL_NAME'
```

From the response, extract:
- **Model name**: `env.MODEL_NAME` or `env.VLLM_MODEL_NAME`
- **Host URL**: `ports[0].host` (the public URL)
- **Tokenizer**: `artifacts_download.artifacts[0].model_id` (the HuggingFace model ID)

### For AI Gateway Models

If benchmarking a model served through TrueFoundry's AI Gateway:
- Find the host URL and model identifier via the "</> Code" button in the AI Gateway section
- Use the workspace API key for authentication

### For External Models (OpenAI, Anthropic, etc.)

| Provider | Model Name | Host URL | Tokenizer |
|----------|-----------|----------|-----------|
| OpenAI | `gpt-4o` | `https://api.openai.com` | `Xenova/gpt-4o` (or equivalent) |
| Anthropic | `claude-3-5-sonnet-20241022` | `https://api.anthropic.com` | N/A (use approximate) |

## Interpreting Results

### What Good Results Look Like

| Metric | Excellent | Good | Needs Attention |
|--------|-----------|------|-----------------|
| **TTFT** | < 100ms | 100-500ms | > 1000ms |
| **TPS** (per request) | > 50 | 20-50 | < 20 |
| **ITL** | < 20ms | 20-50ms | > 100ms |
| **Response Time** (256 tokens) | < 3s | 3-10s | > 10s |
| **Error Rate** | 0% | < 1% | > 5% |

### Reading the Results Table

```
 Concurrency |      RPS |      TPS |   Avg TTFT |   P50 TTFT |   P99 TTFT |   Avg Resp |   OK | Fail
           1 |     0.95 |     48.5 |     85.2ms |     83.0ms |    102.3ms |      1.05s |   10 |    0
           2 |     1.82 |     93.1 |     92.4ms |     89.5ms |    118.7ms |      1.10s |   10 |    0
           4 |     3.41 |    174.2 |    125.6ms |    121.0ms |    198.4ms |      1.17s |   10 |    0
           8 |     5.89 |    301.0 |    245.3ms |    232.1ms |    412.8ms |      1.36s |   10 |    0
          16 |     7.12 |    363.8 |    580.1ms |    542.0ms |   1102.5ms |      2.25s |    9 |    1
```

**How to read this:**
- **Concurrency 1-4**: Linear TPS scaling, low TTFT — model is not saturated
- **Concurrency 8**: TPS still growing but TTFT increasing — approaching saturation
- **Concurrency 16**: TPS growth flattened, TTFT spiked, errors appeared — GPU is saturated

### Common Patterns

**Pattern: Healthy scaling**
- TPS increases linearly with concurrency
- TTFT stays relatively flat
- No errors

**Pattern: GPU saturation**
- TPS plateaus despite increasing concurrency
- TTFT and response time increase sharply
- Errors may start appearing (timeouts, OOM)
- Action: Add more replicas or use a larger GPU

**Pattern: Memory pressure**
- OOM errors or request failures at higher concurrency
- TTFT spikes erratically
- Action: Increase GPU memory utilization limit, reduce max_model_len, or use a GPU with more VRAM

**Pattern: Network bottleneck**
- High TTFT even at low concurrency
- Consistent across concurrency levels
- Action: Check network path, consider co-locating client and model

### Optimization Actions Based on Results

| Issue | Solution |
|-------|----------|
| High TTFT at low concurrency | Prompt is too long; reduce input size or use prefix caching |
| TPS plateaus early | GPU is undersized; upgrade GPU or add replicas |
| Errors at high concurrency | Increase replicas (horizontal scaling) or upgrade GPU (vertical) |
| High ITL | GPU decode is slow; try bfloat16, enable async scheduling, or upgrade GPU |
| P99 latency much higher than P50 | Request queuing; add replicas to distribute load |

## Best Practices

1. **Use representative prompts** — Benchmark with prompts that match your production workload in length and complexity
2. **Test incrementally** — Start at concurrency 1 and increase gradually to find the saturation point
3. **Run enough requests** — Use at least 10-50 requests per concurrency level for stable measurements
4. **Warm up the model** — Send a few requests before the benchmark to warm caches and JIT compilation
5. **Test different configurations** — Compare GPU types, model quantization levels, and vLLM flags
6. **Monitor GPU utilization** — Check GPU memory and compute usage alongside benchmark metrics
7. **Benchmark after changes** — Re-run benchmarks whenever you change the model, GPU, or vLLM configuration
8. **Record results** — Save benchmark outputs for historical comparison

## Composability

- **Deploy a model first**: Use `llm-deploy` skill to deploy the LLM you want to benchmark
- **Find the model endpoint**: Use `applications` skill to get the deployed model's host URL
- **Check deployment health**: Use `applications` skill to verify the model is running before benchmarking
- **View model logs**: Use `logs` skill to check for errors during benchmark
- **Verify connection**: Use `status` skill to confirm TrueFoundry credentials

## Error Handling

### Model Endpoint Not Responding

```
Cannot connect to the model endpoint.
Check:
- The model is deployed and healthy (use applications skill)
- The host URL is correct (include https://)
- The endpoint supports v1/chat/completions (OpenAI-compatible)
- If internal-only, benchmark from within the cluster
```

### 401 Unauthorized on Model Endpoint

```
Authentication failed when calling the model.
Check:
- API key is correct (if the endpoint requires one)
- For AI Gateway models, use the workspace API key
- For direct model endpoints, check if auth is configured
```

### Timeouts at High Concurrency

```
Requests timing out under load.
This means the model is saturated at this concurrency level.
Solutions:
- Reduce concurrency to the last stable level
- Add more replicas for horizontal scaling
- Upgrade to a larger GPU
- Reduce max_model_len to free GPU memory for batching
```

### CUDA Out of Memory During Benchmark

```
Model returned OOM errors under load.
The KV cache is exhausted at this concurrency + sequence length.
Solutions:
- Reduce max_model_len (e.g., from 8192 to 4096)
- Reduce gpu-memory-utilization (e.g., from 0.90 to 0.85)
- Use a GPU with more VRAM
- Reduce max_output_tokens in the benchmark
```

### Inconsistent Results

```
Benchmark results vary significantly between runs.
Common causes:
- Other workloads sharing the GPU node
- Cold start on first run (model not warmed up)
- Network variability
Fix:
- Run a warm-up pass before the benchmark
- Run 3+ benchmark passes and average the results
- Use dedicated GPU nodes if available
```
