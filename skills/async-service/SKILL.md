---
name: async-service
description: Deploys queue-based async services on TrueFoundry. Supports SQS, NATS, Kafka, and Google AMQP with scale-to-zero. NOT for HTTP services (use deploy skill).
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
disable-model-invocation: true
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Async Service Deployment

Deploy an Async Service to TrueFoundry -- a queue-based processing service that consumes messages from SQS, NATS, Kafka, or AMQP, processes them asynchronously via `worker_config`. Supports scale-to-zero when queues are empty.

Two paths:

1. **CLI** (`tfy apply`) -- Write a YAML manifest and apply it. Works everywhere.
2. **REST API** (fallback) -- When CLI unavailable, use `tfy-api.sh`.

## When to Use

Deploy services that consume messages from queues (SQS, NATS, Kafka, Google AMQP) with optional scale-to-zero. Best for long-running tasks, large payloads, or decoupled processing.

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

### Basic Configuration
- [ ] **Service name** — What to call this deployment
- [ ] **Pattern** — Sidecar or Python library?
- [ ] **Environment** — Dev, staging, or production?

### Image Source
- [ ] **Image source** — Source code (build from repo) or pre-built Docker image?
- [ ] **If source code:**
  - [ ] **Repo URL** — Git repository URL
  - [ ] **Branch / SHA / Tag** — Which branch, commit SHA, or tag to build from (optional, defaults to main)
  - [ ] **Build method** — Dockerfile or Buildpack (Python code without Dockerfile)?
  - [ ] **Dockerfile path** — Path to Dockerfile (default: `./Dockerfile`)
  - [ ] **Build context path** — Path to build context (default: `./`)
  - [ ] **Build arguments** — Any Docker build args to pass (optional)
  - [ ] **Build secrets** — Any secrets needed during build (optional)
- [ ] **If Docker image:**
  - [ ] **Image URI** — Full image URI (e.g., `registry/image:tag`)
  - [ ] **Command** — Container entrypoint command

### Ports & Networking (Sidecar Pattern)
- [ ] **Port** — What port the HTTP service listens on
- [ ] **Protocol** — HTTP or TCP (default: HTTP)
- [ ] **Expose** — Should the port be publicly accessible? (default: no)
- [ ] **Enable authentication** — Require TrueFoundry auth on the exposed endpoint? (only if exposed)
- [ ] **Path suffix rewriting** — Enable rewriting to the path suffix? (optional)
- [ ] **Endpoint path** — The POST endpoint path the sidecar forwards to (e.g., `/predict`, `/process`)

### Worker Config
- [ ] **Queue type** — SQS, NATS, Kafka, or Google AMQP?
- [ ] **Queue details** — Queue URL/topic name, credentials
- [ ] **Region name** — Queue region (required for SQS)
- [ ] **Visibility timeout** — Seconds before an unacknowledged message is redelivered (required for SQS)
- [ ] **Worker auth** — Authentication for the queue connection (optional)
- [ ] **Output queue** — Is an output queue needed? If yes, which queue type and details?
- [ ] **Concurrent workers** — Number of concurrent workers processing messages (default: 1)

### Resources
- [ ] **Device type** — CPU only, or GPU? If GPU, which type? (T4, A10 4GB/8GB/12GB/24GB, H100)
- [ ] **CPU** — Request and limit (e.g., request: 0.2, limit: 0.5)
- [ ] **Memory** — Request and limit in MB (e.g., request: 200, limit: 500)
- [ ] **Storage** — Ephemeral storage request and limit in MB (e.g., request: 1000, limit: 2000)
- [ ] **Capacity type** — Any, Spot, or On Demand? (default: Any)

### Scaling
- [ ] **Autoscaling** — Min/max replicas, scale-to-zero? (min=0 enables scale-to-zero)

### Environment & Secrets
- [ ] **Environment variables** — Queue credentials, app-specific config (key-value pairs or raw JSON)
- [ ] **Secrets** — Whether to mount TrueFoundry secret groups

**Do NOT deploy with hardcoded defaults without asking. Every `<PLACEHOLDER>` in the templates below MUST be replaced with a value confirmed by the user. If unsure about any field, ask — never assume.**

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

For the complete SDK deploy.py template with all configuration options (image source, resources, ports, queue config, scaling), see [references/async-sidecar-deploy.md](references/async-sidecar-deploy.md).

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

#### Via Tool Call

```
tfy_applications_create_deployment(
    manifest={
        "name": "<SERVICE_NAME>",                    # ← ask user
        "type": "async-service",
        "image": {
            "type": "build",
            "build_source": {"type": "local", "project_root_path": "."},
            "build_spec": {
                "type": "dockerfile",
                "dockerfile_path": "<DOCKERFILE_PATH>",    # ← ask user
                "build_context_path": "<BUILD_CONTEXT>",   # ← ask user
                "build_args": {},                          # ← ask user if needed
                "build_secrets": {}                        # ← ask user if needed
            }
        },
        "resources": {
            "cpu_request": <CPU_REQUEST>,             # ← ask user
            "cpu_limit": <CPU_LIMIT>,                 # ← ask user
            "memory_request": <MEMORY_REQUEST>,       # ← ask user (MB)
            "memory_limit": <MEMORY_LIMIT>,           # ← ask user (MB)
            "ephemeral_storage_request": <STORAGE_REQUEST>,  # ← ask user (MB)
            "ephemeral_storage_limit": <STORAGE_LIMIT>       # ← ask user (MB)
            # "devices": [{"type": "nvidia_gpu", "name": "<GPU_TYPE>", "count": <COUNT>}]  # ← ask user if GPU needed
            # "node": {"capacity_type": "<CAPACITY_TYPE>"}  # ← ask user: "any" | "spot" | "on_demand" | "spot_fallback_on_demand"
        },
        "ports": [{"port": <PORT>, "protocol": "<PROTOCOL>", "expose": <EXPOSE>, "app_protocol": "http"}],
        "replicas": {"min": <MIN_REPLICAS>, "max": <MAX_REPLICAS>},
        "sidecar": {
            "destination_url": "http://0.0.0.0:<PORT>/<ENDPOINT_PATH>"  # ← ask user
        },
        "worker_config": {
            "concurrent_workers": <CONCURRENT_WORKERS>  # ← ask user
        },
        "input_queue": {
            "type": "<QUEUE_TYPE>",                  # ← ask user: "sqs" | "nats" | "kafka" | "google_amqp"
            "queue_url": "<QUEUE_URL>",              # ← ask user
            "aws_region": "<REGION>",                # ← ask user (SQS only)
            "visibility_timeout": <VISIBILITY_TIMEOUT>  # ← ask user (SQS only, seconds)
        },
        "workspace_fqn": "<WORKSPACE_FQN>"           # ← ask user, never auto-pick
    },
    options={
        "workspace_id": "<WORKSPACE_ID>",            # ← from workspace FQN lookup
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
    "name": "<SERVICE_NAME>",
    "type": "async-service",
    "image": {
      "type": "build",
      "build_source": {"type": "local", "project_root_path": "."},
      "build_spec": {
        "type": "dockerfile",
        "dockerfile_path": "<DOCKERFILE_PATH>",
        "build_context_path": "<BUILD_CONTEXT>",
        "build_args": {},
        "build_secrets": {}
      }
    },
    "resources": {
      "cpu_request": <CPU_REQUEST>,
      "cpu_limit": <CPU_LIMIT>,
      "memory_request": <MEMORY_REQUEST>,
      "memory_limit": <MEMORY_LIMIT>,
      "ephemeral_storage_request": <STORAGE_REQUEST>,
      "ephemeral_storage_limit": <STORAGE_LIMIT>
    },
    "ports": [{"port": <PORT>, "protocol": "<PROTOCOL>", "expose": <EXPOSE>, "app_protocol": "http"}],
    "replicas": {"min": <MIN_REPLICAS>, "max": <MAX_REPLICAS>},
    "sidecar": {
      "destination_url": "http://0.0.0.0:<PORT>/<ENDPOINT_PATH>"
    },
    "worker_config": {
      "concurrent_workers": <CONCURRENT_WORKERS>
    },
    "input_queue": {
      "type": "<QUEUE_TYPE>",
      "queue_url": "<QUEUE_URL>",
      "aws_region": "<REGION>",
      "visibility_timeout": <VISIBILITY_TIMEOUT>
    },
    "workspace_fqn": "<WORKSPACE_FQN>"
  },
  "workspaceId": "<WORKSPACE_ID>"
}'
```

> **Note (NATS):** For NATS queue configs, the actual API field names differ from SDK names:
> - SDK `stream` → API `stream_name`
> - SDK `subject` → API `root_subject`
> - SDK `consumer` → API `consumer_name`
> - SDK `input_queue` + `sidecar` → API `worker_config.input_config` + `worker_config.sidecar_config`
> When in doubt, use the SDK deploy.py approach which handles the mapping automatically.

## Deploying with the Python Library Pattern

For the Python library implementation (handler class, install steps, and deploy configuration), see [references/async-python-library.md](references/async-python-library.md). Use this pattern when processing time exceeds 1 minute per message or you need direct queue consumption control.

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
