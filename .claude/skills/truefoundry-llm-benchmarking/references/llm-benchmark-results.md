# Results Interpretation & Optimization

## Table of Contents

- [What Good Results Look Like](#what-good-results-look-like)
- [Reading the Results Table](#reading-the-results-table)
- [Common Patterns](#common-patterns)
- [Optimization Actions Based on Results](#optimization-actions-based-on-results)
- [Best Practices](#best-practices)

## What Good Results Look Like

| Metric | Excellent | Good | Needs Attention |
|--------|-----------|------|-----------------|
| **TTFT** | < 100ms | 100-500ms | > 1000ms |
| **TPS** (per request) | > 50 | 20-50 | < 20 |
| **ITL** | < 20ms | 20-50ms | > 100ms |
| **Response Time** (256 tokens) | < 3s | 3-10s | > 10s |
| **Error Rate** | 0% | < 1% | > 5% |

## Reading the Results Table

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

## Common Patterns

**Healthy scaling** — TPS increases linearly with concurrency, TTFT stays flat, no errors.

**GPU saturation** — TPS plateaus despite increasing concurrency, TTFT spikes, errors appear. Action: Add replicas or use a larger GPU.

**Memory pressure** — OOM errors at higher concurrency, TTFT spikes erratically. Action: Increase GPU memory limit, reduce max_model_len, or use more VRAM.

**Network bottleneck** — High TTFT even at low concurrency, consistent across levels. Action: Check network path, co-locate client and model.

## Optimization Actions Based on Results

| Issue | Solution |
|-------|----------|
| High TTFT at low concurrency | Prompt is too long; reduce input size or use prefix caching |
| TPS plateaus early | GPU is undersized; upgrade GPU or add replicas |
| Errors at high concurrency | Increase replicas (horizontal scaling) or upgrade GPU (vertical) |
| High ITL | GPU decode is slow; try bfloat16, enable async scheduling, or upgrade GPU |
| P99 latency much higher than P50 | Request queuing; add replicas to distribute load |

## Best Practices

1. **Use representative prompts** — Match production workload in length and complexity
2. **Test incrementally** — Start at concurrency 1, increase gradually to find saturation
3. **Run enough requests** — At least 10-50 per concurrency level for stable measurements
4. **Warm up first** — Send a few requests before benchmarking to warm caches
5. **Compare configurations** — Test different GPU types, quantization levels, and vLLM flags
6. **Monitor GPU utilization** — Check GPU memory and compute usage alongside metrics
7. **Re-benchmark after changes** — Re-run whenever you change model, GPU, or config
8. **Record results** — Save outputs for historical comparison
