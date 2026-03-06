# Async Service Deployment

Deploy an Async Service to TrueFoundry — a queue-based processing service that consumes messages from SQS, NATS, Kafka, or AMQP via `worker_config`. Supports scale-to-zero when queues are empty.

## Async Service vs Regular Service

| Aspect | Regular Service | Async Service |
|--------|----------------|---------------|
| **Communication** | Synchronous HTTP | Queue-based, asynchronous |
| **Latency** | Sub-second expected | Seconds to minutes acceptable |
| **Payload size** | Limited by HTTP timeout | Large payloads via queue + S3 |
| **Traffic spikes** | Can cause 5XX errors | Queue buffers absorb spikes |
| **Scale-to-zero** | Not supported | Supported |
| **Message durability** | Lost if pod crashes | Messages persist in queue, redelivered on failure |
| **Use case** | REST APIs, web apps | Background processing, ML inference, ETL |

**Rule of thumb:** If the caller does not need an immediate response, use an Async Service.

## Prerequisites

Same as other deploy workflows, plus:
- **Queue infrastructure** — A message queue must be provisioned and accessible. Use the `helm` skill to deploy NATS, Kafka, or RabbitMQ, or use a managed service (AWS SQS, etc.).

## Architecture

```
[Input Queue] -> [worker_config.input_config] -> [Your Service]
```

### Supported Queue Types

| Queue | `input_config.type` | Key Fields |
|-------|---------------------|------------|
| **SQS** | `sqs` | `queue_url`, `region_name`, `wait_time_seconds`, `visibility_timeout` |
| **NATS** | `nats` | `nats_url`, `stream_name`, `root_subject`, `consumer_name`, `nats_metrics_url`, `wait_time_seconds` |
| **Kafka** | `kafka` | `bootstrap_servers`, `topic_name`, `consumer_group`, `tls`, `wait_time_seconds` |
| **AMQP** | `amqp` | `url`, `queue_name`, `wait_time_seconds` |

## User Confirmation Checklist

- [ ] **Queue type** — SQS, NATS, Kafka, or AMQP?
- [ ] **Queue details** — Queue URL/topic name, credentials
- [ ] **Service name** — What to call this deployment
- [ ] **Port** — What port the service listens on
- [ ] **Concurrent workers** — `num_concurrent_workers` (default: 1)
- [ ] **Resources** — CPU, memory (defaults: cpu_request=0.2, cpu_limit=0.5, memory_request=200, memory_limit=500)
- [ ] **Autoscaling** — Min/max replicas, scale-to-zero?
- [ ] **Environment** — Dev, staging, or production?
- [ ] **Environment variables** — Queue credentials, app-specific config
- [ ] **Secrets** — Whether to mount TrueFoundry secret groups
- [ ] **Auto-shutdown** — Auto-stop after inactivity? (useful for dev/staging)

## Queue Configuration

For queue-specific connection configs, message-sending examples, and Helm deploy snippets for self-hosted queues, see `async-queue-configs.md`.

## Deploying an Async Service

### Step 1: Prepare Your Service

Your service needs an HTTP endpoint to process messages:

```python
# server.py
from fastapi import FastAPI, Request

app = FastAPI()

@app.post("/process")
async def process(request: Request):
    payload = await request.json()
    result = {"status": "processed", "input": payload}
    return result

@app.get("/health")
async def health():
    return {"status": "ok"}
```

### Step 2: Generate YAML Manifest

```yaml
type: async-service
name: my-async-worker
image:
  type: build
  build_source:
    type: git
    repo_url: https://github.com/user/repo
    ref: main
  build_spec:
    type: dockerfile
    dockerfile_path: ./Dockerfile
    build_context_path: ./
    command: uvicorn server:app --host 0.0.0.0 --port 8000
  docker_registry: my-registry
ports:
  - expose: true
    port: 8000
    protocol: TCP
    app_protocol: http
resources:
  node:
    type: node_selector
  cpu_request: 0.2
  cpu_limit: 0.5
  memory_request: 200
  memory_limit: 500
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
worker_config:
  input_config:
    type: sqs
    queue_url: https://sqs.us-east-1.amazonaws.com/123456789/my-input-queue
    region_name: us-east-1
    wait_time_seconds: 19
    visibility_timeout: 1
  num_concurrent_workers: 1
workspace_fqn: cluster-id:workspace-name
replicas: 1
env: {}
```

**For pre-built images**, replace the `image` section:
```yaml
image:
  type: image
  image_uri: my-registry/my-async-worker:latest
```

### Queue Type Examples

**SQS:**
```yaml
worker_config:
  input_config:
    type: sqs
    queue_url: https://sqs.us-east-1.amazonaws.com/123456789/my-queue
    region_name: us-east-1
    wait_time_seconds: 19
    visibility_timeout: 1
  num_concurrent_workers: 1
```

**NATS:**
```yaml
worker_config:
  input_config:
    type: nats
    nats_url: nats://nats.namespace.svc.cluster.local:4222
    stream_name: my-stream
    root_subject: my-subject
    consumer_name: my-consumer
    nats_metrics_url: http://nats-metrics:7777
    wait_time_seconds: 10
  num_concurrent_workers: 1
```

**Kafka:**
```yaml
worker_config:
  input_config:
    type: kafka
    bootstrap_servers: kafka.namespace.svc.cluster.local:9092
    topic_name: my-topic
    consumer_group: my-group
    tls: false
    wait_time_seconds: 10
  num_concurrent_workers: 1
```

**AMQP:**
```yaml
worker_config:
  input_config:
    type: amqp
    url: amqp://user:AMQP_PASSWORD@rabbitmq.namespace.svc.cluster.local:5672
    queue_name: my-queue
    wait_time_seconds: 10
  num_concurrent_workers: 1
```

### Step 3: Write and Apply Manifest

```bash
# Preview
tfy apply -f tfy-manifest.yaml --dry-run --show-diff

# Apply after user confirms
tfy apply -f tfy-manifest.yaml
```

### Fallback: REST API

If `tfy` CLI is not available, convert the YAML manifest to JSON and deploy via REST API. See `cli-fallback.md`.

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh

# Get workspace ID from FQN
bash $TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"

# Deploy via REST API
bash $TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-async-worker",
    "type": "async-service",
    ...
  },
  "workspaceId": "WORKSPACE_ID_HERE"
}'
```

## Autoscaling and Scale-to-Zero

```yaml
replicas:
  min: 0    # scale-to-zero when queue is empty
  max: 10   # max replicas under load
```

### Scaling Guidelines

| Environment | Min | Max | Notes |
|-------------|-----|-----|-------|
| Dev/testing | 0 | 2 | Scale-to-zero saves resources |
| Staging | 0 | 5 | Test scaling behavior |
| Production (latency-tolerant) | 0 | 10 | OK if cold start is acceptable |
| Production (low-latency) | 1 | 10 | Keep min=1 to avoid cold start |
| High-throughput | 2 | 20+ | Always-on for sustained load |

**Key considerations:**

- `min: 0` enables scale-to-zero — pods terminated when queue is empty. Cold start latency applies.
- `min: 1` keeps at least one pod warm — no cold start but consumes resources when idle.
- Autoscaling triggers based on queue depth.
- Message acknowledgment happens only after processing completes — messages not lost during scale-down.

## Deploying Queue Infrastructure

If the user does not have a queue provisioned, use the `helm` skill to deploy one. See `async-queue-configs.md` for Helm chart references and provisioning workflow.

## After Deploy

```
Async Service deployed successfully!

Next steps:
1. Send test messages to the input queue to verify processing
2. Check deployment status: Use applications skill
3. View processing logs: Use logs skill
4. Monitor queue depth in your queue provider dashboard
5. Adjust autoscaling based on observed throughput
```

## Error Handling

For troubleshooting queue connection failures, worker_config issues, message processing problems, and scale-to-zero issues, see `async-errors.md`.
