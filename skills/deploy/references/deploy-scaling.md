# Autoscaling & Rollout Strategy

## Autoscaling

TrueFoundry supports horizontal pod autoscaling (HPA) based on CPU, memory, or custom metrics.

### Replica Configuration

**REST API manifest:**
```json
{
  "replicas": {
    "min": 2,
    "max": 10
  }
}
```

**SDK:**
```python
from truefoundry.deploy import Replicas

service = Service(
    # ...
    replicas=Replicas(min=2, max=10),
)
```

### Scaling Guidelines

| Environment | Min | Max | Notes |
|-------------|-----|-----|-------|
| Dev/testing | 1 | 1 | No autoscaling needed |
| Staging | 1 | 3 | Test scaling behavior |
| Production | 2 | 10 | Min 2 for high availability |
| High-traffic | 3 | 20+ | Based on load testing |

**Key considerations:**
- `min: 1` means no high availability — if the pod dies, there's downtime
- `min: 2` ensures at least one pod is always available during rolling updates
- `max` should be set based on cluster capacity and expected peak traffic
- TrueFoundry auto-scales based on CPU utilization by default
- Scale-to-zero is available for async services (see `async-service` skill)

See: [Autoscaling](https://truefoundry.com/docs/autoscaling-overview)

## Rollout Strategy

Control how new versions are deployed to minimize downtime and risk.

### Rolling Update (Default, Recommended)

**REST API manifest:**
```json
{
  "rollout_strategy": {
    "type": "rolling_update",
    "max_surge_percentage": 25,
    "max_unavailable_percentage": 0
  }
}
```

**SDK:**
```python
from truefoundry.deploy import RolloutStrategy, RollingUpdate

service = Service(
    # ...
    rollout_strategy=RolloutStrategy(
        type=RollingUpdate(
            max_surge_percentage=25,
            max_unavailable_percentage=0,
        )
    ),
)
```

### Strategy Options

| Setting | Value | Effect |
|---------|-------|--------|
| `max_surge: 25%, max_unavailable: 0%` | Zero-downtime | New pods start before old ones stop. Uses more resources temporarily. |
| `max_surge: 0%, max_unavailable: 25%` | Resource-efficient | Some pods go down before new ones start. Brief capacity reduction. |
| `max_surge: 50%, max_unavailable: 50%` | Fast rollout | Aggressive replacement. Brief instability possible. |

**Recommendation:** Use `max_surge: 25%, max_unavailable: 0%` for production (zero-downtime deploys).

See: [Rollout Strategy](https://truefoundry.com/docs/rollout-strategy)
