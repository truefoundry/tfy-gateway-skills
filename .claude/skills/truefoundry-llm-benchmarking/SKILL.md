---
name: llm-benchmarking
description: Benchmarks deployed LLM performance on TrueFoundry. Measures latency, throughput, TTFT, and tokens/sec under configurable concurrency. NOT for deploying models (use llm-deploy skill).
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(python*) Bash(pip*) Bash(*/tfy-api.sh *)
---

<objective>

# LLM Benchmarking on TrueFoundry

Benchmark deployed LLMs on TrueFoundry to measure latency, throughput, time to first token (TTFT), and other performance metrics. Uses TrueFoundry's LLM Benchmarking Tool deployed via the Application Catalog.

## Scope

Benchmark deployed LLMs to measure inference performance (latency, throughput, TTFT, TPS) under load. Helps find optimal concurrency, GPU, and replica settings.

## When NOT to Use

- User wants to deploy an LLM → use `llm-deploy` skill
- User wants to deploy a regular web app → use `deploy` skill
- User wants to check deployment status → use `applications` skill
- User wants to fine-tune or train a model → not covered by this skill
- User wants to evaluate model quality (accuracy, BLEU, etc.) → not covered; this skill measures inference performance only

</objective>

<context>

## Prerequisites

**Before benchmarking:**

1. **Deployed LLM** — The model must already be deployed and healthy on TrueFoundry. Use the `llm-deploy` skill to deploy one if needed.
2. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
3. **Model endpoint** — The deployed model's host URL (OpenAI-compatible `v1/chat/completions` endpoint)

For credential check commands and .env setup, see `references/prerequisites.md`. Use the `status` skill to verify connection. Use the `applications` skill to find the deployed model's endpoint URL.

</context>

<instructions>

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

For quick benchmarks without deploying the full tool, use the Python script in [references/llm-benchmark-script.md](references/llm-benchmark-script.md). It calls the model's OpenAI-compatible streaming API and measures TTFT, TPS, and response time at varying concurrency levels.

## Configuration Parameters

For load testing parameters, model settings, prompt configuration, and how to find model config from deployment specs, see [references/llm-benchmark-config.md](references/llm-benchmark-config.md).

## Interpreting Results & Best Practices

For result quality thresholds, how to read the results table, common performance patterns (GPU saturation, memory pressure, network bottleneck), optimization actions, and benchmarking best practices, see [references/llm-benchmark-results.md](references/llm-benchmark-results.md).

</instructions>

<success_criteria>

## Success Criteria

- The benchmark has completed successfully across multiple concurrency levels
- The agent has presented a results table showing RPS, TPS, TTFT, and response time at each concurrency level
- The user can identify the saturation point where performance degrades
- The agent has provided actionable optimization recommendations based on the results
- The user knows whether to scale horizontally (more replicas) or vertically (larger GPU) based on the benchmark data

</success_criteria>

<references>

## Composability

- **Deploy a model first**: Use `llm-deploy` skill to deploy the LLM you want to benchmark
- **Find the model endpoint**: Use `applications` skill to get the deployed model's host URL
- **Check deployment health**: Use `applications` skill to verify the model is running before benchmarking
- **View model logs**: Use `logs` skill to check for errors during benchmark
- **Verify connection**: Use `status` skill to confirm TrueFoundry credentials

</references>

<troubleshooting>

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

</troubleshooting>
