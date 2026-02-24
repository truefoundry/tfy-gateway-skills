# LLM Benchmark Script

Complete Python benchmark script for TrueFoundry-deployed models. Measures TTFT, TPS, and response time at varying concurrency levels using the OpenAI-compatible streaming API.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Script](#script)
- [Usage](#usage)

## Prerequisites

```bash
pip install aiohttp
```

## Script

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

## Usage

```bash
# Edit the configuration variables at the top of the script, then run:
python benchmark_llm.py
```
