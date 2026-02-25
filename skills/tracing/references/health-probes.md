# Health Probes

## Probe Types

| Probe | Purpose | When to Use |
|-------|---------|-------------|
| **Startup** | Wait for app to initialize | Apps with slow startup (model loading, DB migrations) |
| **Readiness** | Can this pod receive traffic? | Always — prevents routing to unready pods |
| **Liveness** | Is this pod alive? | Always — restarts hung processes |

## Probe Check Types

HTTP, TCP, exec, gRPC

## SDK Format

```python
from truefoundry.deploy import HttpProbe, HealthProbe

service = Service(
    # ...
    liveness_probe=HealthProbe(
        config=HttpProbe(path="/health", port=8000),
        initial_delay_seconds=5,
        period_seconds=10,
        timeout_seconds=2,
        failure_threshold=3,
    ),
    readiness_probe=HealthProbe(
        config=HttpProbe(path="/health", port=8000),
        initial_delay_seconds=5,
        period_seconds=10,
        timeout_seconds=2,
        failure_threshold=3,
    ),
)
```

## YAML Manifest Format

```yaml
startup_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 10
  period_seconds: 10
  failure_threshold: 30
  timeout_seconds: 2
  success_threshold: 1
readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 10
  failure_threshold: 3
  timeout_seconds: 2
  success_threshold: 1
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 10
  failure_threshold: 5
  timeout_seconds: 2
  success_threshold: 1
```

## Default Tuning

### Standard Services

- **Fast APIs (< 5s startup):** initial_delay: 3s, failure_threshold: 5
- **Standard services:** initial_delay: 5s, period: 10s
- **Slow apps (DB migrations, cache warming):** initial_delay: 15s, failure_threshold: 30

### LLM-Specific Tuning

- Model loading can take 2-10+ minutes depending on model size
- Startup probe: initial_delay: 10-30s, failure_threshold: 35-60, period: 10s
- Total startup budget should be: `initial_delay + (failure_threshold x period) >= max model load time`
- vLLM/TGI health endpoint: `/health`
- NVIDIA NIM health endpoints: `/v1/health/ready` (readiness), `/v1/health/live` (liveness)

## Tuning Formula

`failure_threshold x period_seconds` >= max expected startup time
