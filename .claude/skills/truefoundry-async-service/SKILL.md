---
name: async-service
description: Deploys TrueFoundry Async Services that process messages from queues (SQS, Kafka, NATS) with scale-to-zero support. Uses YAML manifests with `tfy apply`. Use when deploying queue consumers, async workers, event-driven services, or background job processors. NOT for regular HTTP services — use deploy skill.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
metadata:
  disable-model-invocation: "true"
allowed-tools: Bash(tfy*) Bash(*/tfy-api.sh *)
---

<objective>

# Async Service Deployment

Deploy an Async Service to TrueFoundry -- a queue-based processing service that consumes messages from SQS, NATS, Kafka, or AMQP, processes them asynchronously via `worker_config`. Supports scale-to-zero when queues are empty.

Two paths:

1. **CLI** (`tfy apply`) -- Write a YAML manifest and apply it. Works everywhere.
2. **REST API** (fallback) -- When CLI unavailable, use `tfy-api.sh`.

## When to Use

- User wants to process messages from a queue (SQS, NATS, Kafka, AMQP)
- User says "deploy async service", "queue consumer", "async worker"
- User needs scale-to-zero capability (no traffic = no pods running)
- User has workloads with large payloads stored in S3/blob storage
- User has long-running processing tasks (seconds to minutes per request)
- User needs resilience against traffic surges (queue buffers prevent 5XX errors)
- User wants to decouple request receipt from processing
- User wants at-least-once message processing guarantees

## When NOT to Use

- User wants a synchronous HTTP API -> use `deploy` skill
- User wants request-response with low latency (< 1s) -> use `deploy` skill
- User wants to deploy an LLM -> use `llm-deploy` skill
- User wants to deploy infrastructure (database, queue broker) -> use `helm` skill
- User wants to run a one-off batch job -> use `jobs` skill

</objective>

<context>

## Async Service vs Regular Service

| Aspect | Regular Service (`deploy` skill) | Async Service |
|--------|----------------------------------|---------------|
| **Communication** | Synchronous HTTP request/response | Queue-based, asynchronous |
| **Latency** | Sub-second expected | Seconds to minutes acceptable |
| **Payload size** | Limited by HTTP timeout | Large payloads via queue + S3 |
| **Traffic spikes** | Can cause 5XX errors | Queue buffers absorb spikes |
| **Scale-to-zero** | Not supported | Supported -- no pods when queue is empty |
| **Message durability** | Lost if pod crashes mid-request | Messages persist in queue, redelivered on failure |
| **Use case** | REST APIs, web apps, dashboards | Background processing, ML inference, ETL pipelines |

**Rule of thumb:** If the caller does not need an immediate response, use an Async Service.

## Prerequisites

**Always verify before deploying:**

1. **Credentials** -- `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** -- `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**
3. **CLI** -- Check if `tfy` CLI is available: `tfy --version`. If not, `pip install truefoundry`.
4. **Queue infrastructure** -- A message queue must be provisioned and accessible. Use the `helm` skill to deploy NATS, Kafka, or RabbitMQ on the cluster, or use a managed service (AWS SQS, etc.).

For credential check commands and .env setup, see `references/prerequisites.md`.

## Architecture Overview

An Async Service has two components:

1. **Worker config** -- Defines the input queue connection via `worker_config.input_config` (SQS, NATS, Kafka, or AMQP)
2. **Processing service** -- Your application code that handles each message

The service connects directly to the queue through `worker_config.input_config`. TrueFoundry manages message consumption, acknowledgment, and autoscaling based on queue depth.

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

</context>

<instructions>

## User Confirmation Checklist

**Before deploying an Async Service, ALWAYS confirm these with the user:**

- [ ] **Queue type** -- SQS, NATS, Kafka, or AMQP?
- [ ] **Queue details** -- Queue URL/topic name, credentials
- [ ] **Service name** -- What to call this deployment
- [ ] **Port** -- What port the service listens on
- [ ] **Concurrent workers** -- `num_concurrent_workers` (default: 1)
- [ ] **Resources** -- CPU, memory (defaults: cpu_request=0.2, cpu_limit=0.5, memory_request=200, memory_limit=500)
- [ ] **Autoscaling** -- Min/max replicas, scale-to-zero?
- [ ] **Environment** -- Dev, staging, or production?
- [ ] **Environment variables** -- Queue credentials, app-specific config
- [ ] **Secrets** -- Whether to mount TrueFoundry secret groups
- [ ] **Auto-shutdown** -- Should the service auto-stop after inactivity? (useful for dev/staging to save costs)

**Do NOT deploy with hardcoded defaults without asking.**

## Queue Configuration

For queue-specific connection configs (SQS, NATS, Kafka, AMQP), message-sending examples, and Helm deploy snippets for self-hosted queues, see `references/async-queue-configs.md`.

## Deploying an Async Service

### Step 1: Prepare Your Service

Your service needs an HTTP endpoint to process messages. Example with FastAPI:

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

Create a manifest using `worker_config.input_config` for queue connection:

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

### Queue type examples

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
    url: amqp://user:pass@rabbitmq.namespace.svc.cluster.local:5672
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

If `tfy` CLI is not available, convert the YAML manifest to JSON and deploy via REST API. See `references/cli-fallback.md` for the conversion process.

#### Via MCP

```
tfy_applications_create_deployment(
    manifest={
        "name": "my-async-worker",
        "type": "async-service",
        "image": { ... },
        "resources": { "cpu_request": 0.2, "cpu_limit": 0.5, "memory_request": 200, "memory_limit": 500 },
        "ports": [{"port": 8000, "protocol": "TCP", "expose": true, "app_protocol": "http"}],
        "replicas": 1,
        "worker_config": {
            "input_config": { "type": "sqs", "queue_url": "...", "region_name": "us-east-1", "wait_time_seconds": 19, "visibility_timeout": 1 },
            "num_concurrent_workers": 1
        },
        "workspace_fqn": "cluster-id:workspace-name"
    },
    options={
        "workspace_id": "ws-internal-id",
        "force_deploy": false
    }
)
```

#### Via Direct API

```bash
TFY_API_SH=~/.claude/skills/truefoundry-async-service/scripts/tfy-api.sh

# First, get workspace ID from FQN
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"

# Then deploy (JSON body)
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-async-worker",
    "type": "async-service",
    ...
  },
  "workspaceId": "WORKSPACE_ID_HERE"
}'
```

## Autoscaling and Scale-to-Zero

Async Services support autoscaling based on queue depth, including scaling down to zero replicas when the queue is empty.

### Scale-to-Zero Configuration

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
| Production (latency-tolerant) | 0 | 10 | Scale-to-zero OK if cold start is acceptable |
| Production (low-latency) | 1 | 10 | Keep min=1 to avoid cold start delays |
| High-throughput | 2 | 20+ | Always-on replicas for sustained load |

**Key considerations:**

- `min: 0` enables scale-to-zero -- pods are terminated when the queue is empty. Cold start latency applies when new messages arrive.
- `min: 1` keeps at least one pod warm -- no cold start but consumes resources even when idle.
- Autoscaling triggers based on queue depth -- more messages in the queue means more replicas.
- Message acknowledgment happens only after processing completes, so messages are not lost during scale-down.

## Deploying Queue Infrastructure

If the user does not have a queue provisioned, use the `helm` skill to deploy one on the cluster. For Helm chart references (NATS, Kafka, RabbitMQ) and the full provisioning workflow, see `references/async-queue-configs.md`.

## After Deploy

```
Async Service deployed successfully!

Next steps:
1. Send test messages to the input queue to verify processing
2. Check deployment status: Use `applications` skill
3. View processing logs: Use `logs` skill
4. Monitor queue depth in your queue provider dashboard
5. Adjust autoscaling based on observed throughput
```

</instructions>

<success_criteria>

## Success Criteria

- The user's async service is deployed and connected to the specified input queue
- The agent has confirmed the queue type, credentials, and endpoint path with the user before deploying
- Messages sent to the input queue are consumed and processed by the service
- Scale-to-zero is configured correctly if the user requested it (min replicas = 0)
- The user can verify processing by sending a test message and checking logs
- The `worker_config.input_config` is correctly configured for the chosen queue type

</success_criteria>

<references>

## Composability

- **Find workspace first**: Use `workspaces` skill to get workspace FQN
- **Save workspace for next time**: Use `preferences` skill to remember default workspace
- **Deploy queue infrastructure**: Use `helm` skill to deploy NATS, Kafka, or RabbitMQ
- **Check what's deployed**: Use `applications` skill to list deployments
- **Test deployed service**: Use `service-test` skill to validate async endpoints
- **View processing logs**: Use `logs` skill with the application ID
- **Manage queue credentials**: Use `secrets` skill to store queue access keys
- **Regular HTTP service instead**: Use `deploy` skill for synchronous services
- **Check cluster status**: Use `status` skill for preflight checks

</references>

<troubleshooting>

## Error Handling

For troubleshooting queue connection failures, worker_config issues, message processing problems, and scale-to-zero issues, see `references/async-errors.md`.

### CLI Errors
- `tfy: command not found` -- Install with `pip install truefoundry`
- `tfy apply` validation errors -- Check YAML syntax, ensure required fields (name, type, image, resources, worker_config, workspace_fqn) are present

</troubleshooting>
</output>
