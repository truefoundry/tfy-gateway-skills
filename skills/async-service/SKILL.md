---
name: async-service
description: This skill should be used when the user asks "deploy async service", "queue-based service", "async worker", "message queue processing", "deploy SQS consumer", "deploy Kafka consumer", "deploy NATS consumer", "scale to zero", "async processing", "background job processor", "event-driven service", "queue consumer", or wants to deploy a TrueFoundry Async Service that processes messages from queues with scale-to-zero support. NOT for regular HTTP services — use deploy skill for that.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
metadata:
  disable-model-invocation: "true"
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Async Service Deployment

Deploy an Async Service to TrueFoundry — a queue-based processing service that consumes messages from SQS, NATS, Kafka, or Google AMQP, processes them asynchronously, and optionally writes results to an output queue. Supports scale-to-zero when queues are empty.

## When to Use

- User wants to process messages from a queue (SQS, NATS, Kafka, Google AMQP)
- User says "deploy async service", "queue consumer", "async worker"
- User needs scale-to-zero capability (no traffic = no pods running)
- User has workloads with large payloads stored in S3/blob storage
- User has long-running processing tasks (seconds to minutes per request)
- User needs resilience against traffic surges (queue buffers prevent 5XX errors)
- User wants to decouple request receipt from processing
- User wants at-least-once message processing guarantees

## When NOT to Use

- User wants a synchronous HTTP API → use `deploy` skill
- User wants request-response with low latency (< 1s) → use `deploy` skill
- User wants to deploy an LLM → use `llm-deploy` skill
- User wants to deploy infrastructure (database, queue broker) → use `helm` skill
- User wants to run a one-off batch job → use `deploy` skill with job type

</objective>

<context>

## Async Service vs Regular Service

| Aspect | Regular Service (`deploy` skill) | Async Service |
|--------|----------------------------------|---------------|
| **Communication** | Synchronous HTTP request/response | Queue-based, asynchronous |
| **Latency** | Sub-second expected | Seconds to minutes acceptable |
| **Payload size** | Limited by HTTP timeout | Large payloads via queue + S3 |
| **Traffic spikes** | Can cause 5XX errors | Queue buffers absorb spikes |
| **Scale-to-zero** | Not supported | Supported — no pods when queue is empty |
| **Message durability** | Lost if pod crashes mid-request | Messages persist in queue, redelivered on failure |
| **Use case** | REST APIs, web apps, dashboards | Background processing, ML inference, ETL pipelines |

**Rule of thumb:** If the caller does not need an immediate response, use an Async Service.

## Prerequisites

**Always verify before deploying:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**
3. **Queue infrastructure** — A message queue must be provisioned and accessible. Use the `helm` skill to deploy NATS, Kafka, or RabbitMQ on the cluster, or use a managed service (AWS SQS, Google AMQP).

For credential check commands and .env setup, see `references/prerequisites.md`.

## Architecture Overview

An Async Service has three components:

1. **Input queue** — Messages arrive here (SQS, NATS, Kafka, or Google AMQP)
2. **Processing service** — Your application code that handles each message
3. **Output queue** (optional) — Results are written here after processing

### Two Implementation Patterns

#### Pattern 1: Sidecar (Recommended for Most Cases)

The `tfy-async-sidecar` runs alongside your HTTP service. It:

1. Consumes messages from the input queue
2. Sends each message as a POST request to your HTTP endpoint
3. Writes the response to the output queue (if configured)
4. Acknowledges the message only after successful processing and output write

```
[Input Queue] → [tfy-async-sidecar] → POST → [Your HTTP Service]
                                                    ↓
                                           [Output Queue] (optional)
```

**Use when:**
- Your service is written in any language (Python, Node.js, Go, Java, etc.)
- Processing time is under 1 minute per message
- You already have an HTTP service and want to add queue consumption
- You want to keep queue logic separate from business logic

**Your service only needs:** An HTTP endpoint that accepts POST requests with the message payload.

#### Pattern 2: Python Library

TrueFoundry provides an open-source Python library that integrates directly with queue frameworks. Your code implements a processing handler function.

**Use when:**
- Processing code is Python
- Processing time exceeds 1 minute per message
- You want direct control over queue consumption logic
- You need custom acknowledgment patterns

</context>

<instructions>

## User Confirmation Checklist

**Before deploying an Async Service, ALWAYS confirm these with the user:**

- [ ] **Pattern** — Sidecar or Python library?
- [ ] **Queue type** — SQS, NATS, Kafka, or Google AMQP?
- [ ] **Queue details** — Queue URL/topic name, credentials
- [ ] **Service name** — What to call this deployment
- [ ] **Port** — What port the HTTP service listens on (sidecar pattern)
- [ ] **Endpoint path** — The POST endpoint path (e.g., `/predict`, `/process`) (sidecar pattern)
- [ ] **Output queue** — Is an output queue needed? If yes, which queue?
- [ ] **Resources** — CPU, memory (analyze the workload first — see `deploy` skill Step 1)
- [ ] **Autoscaling** — Min/max replicas, scale-to-zero?
- [ ] **Environment** — Dev, staging, or production?
- [ ] **Environment variables** — Queue credentials, app-specific config
- [ ] **Secrets** — Whether to mount TrueFoundry secret groups

**Do NOT deploy with hardcoded defaults without asking.**

## Queue Configuration

For queue-specific connection JSON (SQS, NATS, Kafka, Google AMQP), message-sending examples, and Helm deploy snippets for self-hosted queues, see `references/async-queue-configs.md`.

## Deploying with the Sidecar Pattern

### Step 1: Prepare Your HTTP Service

Your service needs a POST endpoint that accepts the queue message payload and returns a response. Example with FastAPI:

```python
# server.py
from fastapi import FastAPI, Request

app = FastAPI()

@app.post("/process")
async def process(request: Request):
    payload = await request.json()
    # Your processing logic here
    result = {"status": "processed", "input": payload}
    return result

@app.get("/health")
async def health():
    return {"status": "ok"}
```

### Step 2: Deploy via SDK (deploy.py)

```python
"""Deploy an Async Service to TrueFoundry using the sidecar pattern."""
import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent / ".env")
except ImportError:
    pass

if os.environ.get("TFY_BASE_URL") and not os.environ.get("TFY_HOST"):
    os.environ["TFY_HOST"] = os.environ["TFY_BASE_URL"].strip().rstrip("/")

from truefoundry.deploy import (
    AsyncService,
    Build,
    DockerFileBuild,
    LocalSource,
    Port,
    Resources,
    SQSQueueConfig,       # or NATSQueueConfig, KafkaQueueConfig
    SidecarPattern,
    Replicas,
)

PROJECT_ROOT = str(Path(__file__).resolve().parent)

async_service = AsyncService(
    name="my-async-worker",                         # ← change
    image=Build(
        build_source=LocalSource(project_root_path=PROJECT_ROOT, local_build=True),
        build_spec=DockerFileBuild(
            dockerfile_path="Dockerfile",
            build_context_path=".",
        ),
    ),
    resources=Resources(
        cpu_request=0.5, cpu_limit=1.0,
        memory_request=512, memory_limit=1024,
        ephemeral_storage_request=100, ephemeral_storage_limit=200,
    ),
    ports=[
        Port(port=8000, protocol="TCP", expose=False, app_protocol="http"),
    ],
    replicas=Replicas(min=0, max=5),                # scale-to-zero enabled
    sidecar=SidecarPattern(
        destination_url="http://0.0.0.0:8000/process",  # ← your POST endpoint
    ),
    input_queue=SQSQueueConfig(
        queue_url="https://sqs.us-east-1.amazonaws.com/123456789/my-input-queue",
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", ""),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", ""),
        aws_region="us-east-1",
    ),
    # output_queue=SQSQueueConfig(...)  # optional: for writing results
)

if __name__ == "__main__":
    workspace_fqn = (os.environ.get("TFY_WORKSPACE_FQN") or "").strip()
    if not workspace_fqn:
        raise SystemExit(
            "TFY_WORKSPACE_FQN is required. "
            "Get it from the TrueFoundry dashboard or tfy_workspaces_list. "
            "Do not auto-pick a workspace."
        )
    async_service.deploy(workspace_fqn=workspace_fqn, wait=False)
    print("Async Service deployment submitted. Check the TrueFoundry dashboard for status.")
```

### Step 3: Deploy via API Manifest

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

#### Via MCP

```
tfy_applications_create_deployment(
    manifest={
        "name": "my-async-worker",
        "type": "async-service",
        "image": {
            "type": "build",
            "build_source": {"type": "local", "project_root_path": "."},
            "build_spec": {"type": "dockerfile", "dockerfile_path": "Dockerfile", "build_context_path": "."}
        },
        "resources": {
            "cpu_request": 0.5, "cpu_limit": 1.0,
            "memory_request": 512, "memory_limit": 1024
        },
        "ports": [{"port": 8000, "protocol": "TCP", "expose": false}],
        "replicas": {"min": 0, "max": 5},
        "sidecar": {
            "destination_url": "http://0.0.0.0:8000/process"
        },
        "input_queue": {
            "type": "sqs",
            "queue_url": "https://sqs.us-east-1.amazonaws.com/123456789/my-input-queue",
            "aws_region": "us-east-1"
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
# Set the path to tfy-api.sh for your agent (example for Claude Code):
TFY_API_SH=~/.claude/skills/truefoundry-async-service/scripts/tfy-api.sh

# First, get workspace ID from FQN
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"

# Then deploy
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-async-worker",
    "type": "async-service",
    "image": {
      "type": "build",
      "build_source": {"type": "local", "project_root_path": "."},
      "build_spec": {"type": "dockerfile", "dockerfile_path": "Dockerfile", "build_context_path": "."}
    },
    "resources": {
      "cpu_request": 0.5,
      "cpu_limit": 1.0,
      "memory_request": 512,
      "memory_limit": 1024
    },
    "ports": [{"port": 8000, "protocol": "TCP", "expose": false}],
    "replicas": {"min": 0, "max": 5},
    "sidecar": {
      "destination_url": "http://0.0.0.0:8000/process"
    },
    "input_queue": {
      "type": "sqs",
      "queue_url": "https://sqs.us-east-1.amazonaws.com/123456789/my-input-queue",
      "aws_region": "us-east-1"
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID_HERE"
}'
```

## Deploying with the Python Library Pattern

### Step 1: Install the Library

```bash
pip install truefoundry[async]
```

### Step 2: Implement the Handler

```python
# worker.py
from truefoundry.async_service import AsyncHandler, Message

class MyHandler(AsyncHandler):
    def __init__(self):
        # Initialize models, connections, etc.
        pass

    async def process(self, message: Message) -> dict:
        """Process a single message from the queue."""
        payload = message.body
        # Your processing logic here (can take minutes)
        result = {"status": "processed", "output": payload}
        return result

handler = MyHandler()
```

### Step 3: Deploy

Use the same `deploy.py` approach as the sidecar pattern but replace `SidecarPattern` with `PythonLibraryPattern` configuration in the SDK, or set `"pattern": "python-library"` in the API manifest. The entry command should point to your worker script.

## Autoscaling and Scale-to-Zero

Async Services support autoscaling based on queue depth, including scaling down to zero replicas when the queue is empty.

### Scale-to-Zero Configuration

```python
# SDK
from truefoundry.deploy import Replicas

async_service = AsyncService(
    # ...
    replicas=Replicas(
        min=0,    # scale-to-zero when queue is empty
        max=10,   # max replicas under load
    ),
)
```

### API Manifest

```json
{
  "replicas": {
    "min": 0,
    "max": 10
  }
}
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

- `min: 0` enables scale-to-zero — pods are terminated when the queue is empty. Cold start latency applies when new messages arrive.
- `min: 1` keeps at least one pod warm — no cold start but consumes resources even when idle.
- Autoscaling triggers based on queue depth — more messages in the queue means more replicas.
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
- Output queue is configured and receiving results if the user specified one

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

For troubleshooting queue connection failures, sidecar communication issues, message processing problems, and scale-to-zero issues, see `references/async-errors.md`.

</troubleshooting>
