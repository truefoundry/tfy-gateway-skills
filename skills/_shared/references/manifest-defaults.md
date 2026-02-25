# Manifest Defaults

Per-workload-type recommended defaults with "Override When" guidance and complete YAML templates. All templates use `${VARIABLE}` for user-provided values and sensible defaults for everything else.

See `references/manifest-schema.md` for full field documentation.

---

## 1. Web API

Standard HTTP service (FastAPI, Flask, Express, Django, Go, etc.)

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `0.5` | High computation (image processing, crypto, heavy parsing) |
| `cpu_limit` | `1.0` | Same |
| `memory_request` | `512` | Large data processing, in-memory caching, ML libraries loaded |
| `memory_limit` | `1024` | Same |
| `ephemeral_storage_request` | `1000` | Large file uploads, temp file processing |
| `ephemeral_storage_limit` | `2000` | Same |
| `replicas` | `1` | Production: use `min: 2, max: 5` for HA and autoscaling |
| `expose` | `false` | Public-facing API: set `true` with a valid `host` |
| `app_protocol` | `http` | gRPC service: use `grpc` |
| `liveness_probe path` | `/health` | Custom health endpoint (e.g., `/api/health`, `/livez`) |
| `readiness_probe path` | `/health` | Custom readiness endpoint (e.g., `/readyz`) |
| `initial_delay_seconds` | `5` | Slow startup (DB migrations, cache warming): increase to 15-30 |
| `failure_threshold` | `3` | Slow startup: increase to 10-30 |

### Template

```yaml
name: ${SERVICE_NAME}
type: service
image:
  type: image
  image_uri: ${IMAGE_URI}
ports:
  - port: ${PORT:-8000}
    protocol: TCP
    expose: false
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas: 1
env: {}
liveness_probe:
  config:
    type: http
    path: /health
    port: ${PORT:-8000}
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
readiness_probe:
  config:
    type: http
    path: /health
    port: ${PORT:-8000}
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Build-from-Git Variant

```yaml
name: ${SERVICE_NAME}
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: ${REPO_URL}
    branch_name: ${BRANCH:-main}
  build_spec:
    type: dockerfile
    dockerfile_path: Dockerfile
    build_context_path: "."
ports:
  - port: ${PORT:-8000}
    protocol: TCP
    expose: false
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas: 1
env: {}
liveness_probe:
  config:
    type: http
    path: /health
    port: ${PORT:-8000}
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
readiness_probe:
  config:
    type: http
    path: /health
    port: ${PORT:-8000}
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 2. LLM Inference

Model serving with vLLM, TGI, Ollama, or NVIDIA NIM.

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `4.0` | Larger models: 8-16 cores |
| `cpu_limit` | `8.0` | Same |
| `memory_request` | `16384` (16 GB) | 7B models: 64 GB. 70B models: 200+ GB. |
| `memory_limit` | `32768` (32 GB) | Same as above, 1.5-2x request |
| `ephemeral_storage_request` | `5000` | Large model downloads: 10000-50000 |
| `ephemeral_storage_limit` | `10000` | Same |
| `gpu` | `T4 x1` | 7B models: `A10G x1`. 13B: `A100_40GB x1`. 70B: `A100_80GB x2-4`. |
| `replicas` | `1` | Production: `min: 1, max: 3` |
| `startup_probe failure_threshold` | `60` | Very large models (70B+): increase to 90-120 |
| `startup_probe period_seconds` | `10` | Gives 10 min startup budget at default |
| `liveness_probe path` | `/health` | NVIDIA NIM: `/v1/health/live` |
| `readiness_probe path` | `/health` | NVIDIA NIM: `/v1/health/ready` |

### GPU Sizing Guide

| Model Size | GPU | CPU | Memory |
|------------|-----|-----|--------|
| < 1B | T4 x1 | 4 | 16 GB |
| 1B-3B | T4 x1 | 4-8 | 32 GB |
| 3B-7B | A10G x1 | 8-10 | 64 GB |
| 7B-13B | A100_40GB x1 | 10-12 | 90 GB |
| 13B-30B | A100_80GB x1 | 12-16 | 128 GB |
| 30B-70B | A100_80GB x2-4 or H100_80GB x2 | 16+ | 200+ GB |

### Template (vLLM)

```yaml
name: ${MODEL_NAME}-vllm
type: service
image:
  type: image
  image_uri: vllm/vllm-openai:latest
  command: >-
    python -m vllm.entrypoints.openai.api_server
    --model ${HF_MODEL_ID}
    --host 0.0.0.0
    --port 8000
    --dtype auto
    --max-model-len ${MAX_MODEL_LEN:-4096}
ports:
  - port: 8000
    protocol: TCP
    expose: false
    app_protocol: http
resources:
  cpu_request: 4.0
  cpu_limit: 8.0
  memory_request: 16384
  memory_limit: 32768
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
  devices:
    - type: "nvidia.com/gpu"
      name: "${GPU_TYPE:-T4}"
      count: ${GPU_COUNT:-1}
replicas: 1
env:
  HUGGING_FACE_HUB_TOKEN: ${HF_TOKEN}
startup_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 30
  period_seconds: 10
  timeout_seconds: 5
  failure_threshold: 60
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 30
  timeout_seconds: 5
  failure_threshold: 3
readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 5
  failure_threshold: 3
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Template (TGI)

```yaml
name: ${MODEL_NAME}-tgi
type: service
image:
  type: image
  image_uri: ghcr.io/huggingface/text-generation-inference:latest
  command: >-
    text-generation-launcher
    --model-id ${HF_MODEL_ID}
    --port 8000
    --hostname 0.0.0.0
    --dtype auto
    --max-input-length ${MAX_INPUT_LEN:-2048}
    --max-total-tokens ${MAX_TOTAL_TOKENS:-4096}
ports:
  - port: 8000
    protocol: TCP
    expose: false
    app_protocol: http
resources:
  cpu_request: 4.0
  cpu_limit: 8.0
  memory_request: 16384
  memory_limit: 32768
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
  devices:
    - type: "nvidia.com/gpu"
      name: "${GPU_TYPE:-T4}"
      count: ${GPU_COUNT:-1}
replicas: 1
env:
  HUGGING_FACE_HUB_TOKEN: ${HF_TOKEN}
startup_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 30
  period_seconds: 10
  timeout_seconds: 5
  failure_threshold: 60
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 30
  timeout_seconds: 5
  failure_threshold: 3
readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 5
  failure_threshold: 3
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 3. Job (One-time)

Single-execution batch job.

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `1.0` | CPU-intensive workloads: 4-8 cores |
| `cpu_limit` | `2.0` | Same |
| `memory_request` | `2048` | Large dataset processing: 8192+ |
| `memory_limit` | `4096` | Same |
| `ephemeral_storage_request` | `1000` | Large temp files: 5000-20000 |
| `ephemeral_storage_limit` | `2000` | Same |
| `retries` | `0` | Flaky external dependencies: 2-3 |
| `timeout` | `3600` (1h) | Long-running ETL: 7200-86400. Quick scripts: 300-600. |

### Template

```yaml
name: ${JOB_NAME}
type: job
image:
  type: image
  image_uri: ${IMAGE_URI}
  command: "${COMMAND}"
resources:
  cpu_request: 1.0
  cpu_limit: 2.0
  memory_request: 2048
  memory_limit: 4096
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
retries: 0
timeout: 3600
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 4. Scheduled Job

Cron-triggered recurring job.

### Defaults

Same resource defaults as one-time job. Additional:

| Field | Default | Override When |
|-------|---------|--------------|
| `trigger.type` | `cron` | -- |
| `trigger.schedule` | `"0 2 * * *"` (2 AM daily) | Adjust to match business requirements |
| `retries` | `2` | Jobs that must not fail: 3-5. Idempotent jobs: 0. |
| `timeout` | `7200` (2h) | Adjust based on expected runtime |

### Template

```yaml
name: ${JOB_NAME}
type: job
image:
  type: image
  image_uri: ${IMAGE_URI}
  command: "${COMMAND}"
resources:
  cpu_request: 1.0
  cpu_limit: 2.0
  memory_request: 2048
  memory_limit: 4096
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
retries: 2
timeout: 7200
trigger:
  type: cron
  schedule: "${CRON_SCHEDULE:-0 2 * * *}"
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Common Cron Schedules

| Schedule | Expression |
|----------|-----------|
| Every hour | `0 * * * *` |
| Every 6 hours | `0 */6 * * *` |
| Daily at 2 AM | `0 2 * * *` |
| Weekly Sunday midnight | `0 0 * * 0` |
| Monthly 1st at midnight | `0 0 1 * *` |

---

## 5. Async Service

Queue-based worker with scale-to-zero support.

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `0.5` | CPU-bound processing: 2-4 cores |
| `cpu_limit` | `1.0` | Same |
| `memory_request` | `512` | ML inference workers: 4096-16384 |
| `memory_limit` | `1024` | Same |
| `ephemeral_storage_request` | `1000` | File processing: 5000+ |
| `ephemeral_storage_limit` | `2000` | Same |
| `replicas.min` | `0` | Low-latency required (avoid cold start): set `1` |
| `replicas.max` | `5` | High throughput: 10-20+ |
| `sidecar.destination_url` | `http://0.0.0.0:8000/process` | Custom endpoint path |

### Template (SQS + Sidecar)

```yaml
name: ${SERVICE_NAME}
type: async-service
image:
  type: image
  image_uri: ${IMAGE_URI}
ports:
  - port: ${PORT:-8000}
    protocol: TCP
    expose: false
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas:
  min: 0
  max: 5
sidecar:
  destination_url: "http://0.0.0.0:${PORT:-8000}/${ENDPOINT_PATH:-process}"
input_queue:
  type: sqs
  queue_url: ${SQS_QUEUE_URL}
  aws_region: ${AWS_REGION}
  aws_access_key_id: ${AWS_ACCESS_KEY_ID}
  aws_secret_access_key: ${AWS_SECRET_ACCESS_KEY}
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Template (NATS + Sidecar)

```yaml
name: ${SERVICE_NAME}
type: async-service
image:
  type: image
  image_uri: ${IMAGE_URI}
ports:
  - port: ${PORT:-8000}
    protocol: TCP
    expose: false
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas:
  min: 0
  max: 5
sidecar:
  destination_url: "http://0.0.0.0:${PORT:-8000}/${ENDPOINT_PATH:-process}"
input_queue:
  type: nats
  nats_url: ${NATS_URL}
  subject: ${NATS_SUBJECT}
  consumer_name: ${CONSUMER_NAME}
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 6. Helm Database

PostgreSQL, MySQL, MongoDB via Helm charts.

### Defaults (PostgreSQL)

| Field | Default | Override When |
|-------|---------|--------------|
| `chart` | `bitnamicharts/postgresql` | MySQL: `bitnamicharts/mysql`. MongoDB: `bitnamicharts/mongodb`. |
| `version` | `"16.7.21"` | <!-- TODO: user to confirm defaults --> Check latest at registry |
| `persistence.size` | `10Gi` | Production: `50Gi`-`500Gi` based on data volume |
| `cpu requests` | `"0.5"` | Production: `"2"`-`"4"` |
| `memory requests` | `512Mi` | Production: `"2Gi"`-`"8Gi"` |
| `replicas` | `1` | Production HA: `3` (with read replicas) |
| `password` | Generated | Use TrueFoundry secrets for production |

### Template (PostgreSQL)

```yaml
name: ${DB_NAME:-postgres}
type: helm
source:
  type: oci-repo
  version: "${PG_CHART_VERSION:-16.7.21}"
  oci_chart_url: oci://registry-1.docker.io/bitnamicharts/postgresql
values:
  auth:
    postgresPassword: "${DB_PASSWORD}"
    database: "${DB_DATABASE:-myapp}"
  primary:
    persistence:
      enabled: true
      size: "${DB_STORAGE:-10Gi}"
    resources:
      requests:
        cpu: "${DB_CPU:-0.5}"
        memory: "${DB_MEMORY:-512Mi}"
      limits:
        cpu: "${DB_CPU_LIMIT:-1}"
        memory: "${DB_MEMORY_LIMIT:-1Gi}"
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Template (MySQL)

```yaml
name: ${DB_NAME:-mysql}
type: helm
source:
  type: oci-repo
  version: "${MYSQL_CHART_VERSION:-11.1.17}"
  oci_chart_url: oci://registry-1.docker.io/bitnamicharts/mysql
values:
  auth:
    rootPassword: "${DB_PASSWORD}"
    database: "${DB_DATABASE:-myapp}"
  primary:
    persistence:
      enabled: true
      size: "${DB_STORAGE:-10Gi}"
    resources:
      requests:
        cpu: "${DB_CPU:-0.5}"
        memory: "${DB_MEMORY:-512Mi}"
      limits:
        cpu: "${DB_CPU_LIMIT:-1}"
        memory: "${DB_MEMORY_LIMIT:-1Gi}"
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

<!-- TODO: user to confirm defaults for chart versions -->

### Template (MongoDB)

```yaml
name: ${DB_NAME:-mongodb}
type: helm
source:
  type: oci-repo
  version: "${MONGO_CHART_VERSION:-16.4.3}"
  oci_chart_url: oci://registry-1.docker.io/bitnamicharts/mongodb
values:
  auth:
    rootPassword: "${DB_PASSWORD}"
    databases:
      - "${DB_DATABASE:-myapp}"
  persistence:
    enabled: true
    size: "${DB_STORAGE:-10Gi}"
  resources:
    requests:
      cpu: "${DB_CPU:-0.5}"
      memory: "${DB_MEMORY:-512Mi}"
    limits:
      cpu: "${DB_CPU_LIMIT:-1}"
      memory: "${DB_MEMORY_LIMIT:-1Gi}"
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Connection DNS Patterns

After deploying, the database is accessible within the cluster at:

| Database | Service DNS | Default Port |
|----------|-------------|-------------|
| PostgreSQL | `${RELEASE_NAME}-postgresql.${NAMESPACE}.svc.cluster.local` | 5432 |
| MySQL | `${RELEASE_NAME}-mysql.${NAMESPACE}.svc.cluster.local` | 3306 |
| MongoDB | `${RELEASE_NAME}-mongodb.${NAMESPACE}.svc.cluster.local` | 27017 |

---

## 7. Helm Cache

Redis, Memcached via Helm charts.

### Defaults (Redis)

| Field | Default | Override When |
|-------|---------|--------------|
| `chart` | `bitnamicharts/redis` | Memcached: `bitnamicharts/memcached` |
| `version` | `"20.6.2"` | <!-- TODO: user to confirm defaults --> Check latest at registry |
| `persistence.size` | `5Gi` | Large cache: `20Gi`-`50Gi` |
| `cpu requests` | `"0.25"` | High-throughput cache: `"1"`-`"2"` |
| `memory requests` | `256Mi` | Large working set: `"1Gi"`-`"4Gi"` |
| `maxmemory-policy` | `allkeys-lru` | Session store: `noeviction` |

### Template (Redis)

```yaml
name: ${CACHE_NAME:-redis}
type: helm
source:
  type: oci-repo
  version: "${REDIS_CHART_VERSION:-20.6.2}"
  oci_chart_url: oci://registry-1.docker.io/bitnamicharts/redis
values:
  auth:
    password: "${REDIS_PASSWORD}"
  master:
    persistence:
      enabled: true
      size: "${CACHE_STORAGE:-5Gi}"
    resources:
      requests:
        cpu: "${CACHE_CPU:-0.25}"
        memory: "${CACHE_MEMORY:-256Mi}"
      limits:
        cpu: "${CACHE_CPU_LIMIT:-0.5}"
        memory: "${CACHE_MEMORY_LIMIT:-512Mi}"
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

<!-- TODO: user to confirm defaults for chart versions -->

### Template (Memcached)

```yaml
name: ${CACHE_NAME:-memcached}
type: helm
source:
  type: oci-repo
  version: "${MEMCACHED_CHART_VERSION:-7.5.5}"
  oci_chart_url: oci://registry-1.docker.io/bitnamicharts/memcached
values:
  resources:
    requests:
      cpu: "${CACHE_CPU:-0.25}"
      memory: "${CACHE_MEMORY:-256Mi}"
    limits:
      cpu: "${CACHE_CPU_LIMIT:-0.5}"
      memory: "${CACHE_MEMORY_LIMIT:-512Mi}"
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Connection DNS Patterns

| Cache | Service DNS | Default Port |
|-------|-------------|-------------|
| Redis (master) | `${RELEASE_NAME}-redis-master.${NAMESPACE}.svc.cluster.local` | 6379 |
| Memcached | `${RELEASE_NAME}-memcached.${NAMESPACE}.svc.cluster.local` | 11211 |

---

## 8. Notebook

Jupyter notebook for interactive development and data exploration.

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `1.0` | ML workloads: 4-8 cores |
| `cpu_limit` | `2.0` | Same |
| `memory_request` | `2048` | ML with large datasets: 8192-32768 |
| `memory_limit` | `4096` | Same |
| `ephemeral_storage_request` | `2000` | Large datasets: 10000+ |
| `ephemeral_storage_limit` | `5000` | Same |
| `storage.size` | `"20Gi"` | Large datasets or many notebooks: `"50Gi"`-`"100Gi"` |
| `idle_timeout` | `1800` (30 min) | Long experiments: `3600`-`7200`. Disable: `0`. |
| `gpu` | None | ML training/inference: add appropriate GPU |

### Template

```yaml
name: ${NOTEBOOK_NAME}
type: notebook
image:
  type: image
  image_uri: ${NOTEBOOK_IMAGE:-jupyter/scipy-notebook:latest}
resources:
  cpu_request: 1.0
  cpu_limit: 2.0
  memory_request: 2048
  memory_limit: 4096
  ephemeral_storage_request: 2000
  ephemeral_storage_limit: 5000
storage:
  size: "${STORAGE_SIZE:-20Gi}"
idle_timeout: ${IDLE_TIMEOUT:-1800}
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### GPU Notebook Template

```yaml
name: ${NOTEBOOK_NAME}
type: notebook
image:
  type: image
  image_uri: ${NOTEBOOK_IMAGE:-jupyter/tensorflow-notebook:latest}
resources:
  cpu_request: 4.0
  cpu_limit: 8.0
  memory_request: 16384
  memory_limit: 32768
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
  devices:
    - type: "nvidia.com/gpu"
      name: "${GPU_TYPE:-T4}"
      count: ${GPU_COUNT:-1}
storage:
  size: "${STORAGE_SIZE:-50Gi}"
idle_timeout: ${IDLE_TIMEOUT:-3600}
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 9. SSH Server

Remote development environment accessible via SSH.

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `2.0` | Heavy development: 4-8 cores |
| `cpu_limit` | `4.0` | Same |
| `memory_request` | `4096` | ML development: 16384-32768 |
| `memory_limit` | `8192` | Same |
| `ephemeral_storage_request` | `5000` | Large repos or datasets: 20000+ |
| `ephemeral_storage_limit` | `10000` | Same |
| `storage.size` | `"50Gi"` | Large projects: `"100Gi"`-`"200Gi"` |
| `gpu` | None | ML development: add appropriate GPU |

### Template

```yaml
name: ${SERVER_NAME}
type: ssh-server
image:
  type: image
  image_uri: ${SSH_IMAGE:-ubuntu:22.04}
resources:
  cpu_request: 2.0
  cpu_limit: 4.0
  memory_request: 4096
  memory_limit: 8192
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
storage:
  size: "${STORAGE_SIZE:-50Gi}"
ssh_keys:
  - "${SSH_PUBLIC_KEY}"
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 10. LLM Finetuning

Training jobs for fine-tuning language models (QLoRA, LoRA, full fine-tuning).

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `4.0` | Large models (30B+): 8-16 cores |
| `cpu_limit` | `8.0` | Same |
| `memory_request` | `32768` (32 GB) | 13B+ models: 64 GB-128 GB |
| `memory_limit` | `65536` (64 GB) | Same |
| `ephemeral_storage_request` | `10000` | Large datasets + model checkpoints: 50000+ |
| `ephemeral_storage_limit` | `20000` | Same |
| `gpu` (QLoRA, < 7B) | `T4 x1` | See GPU sizing table below |
| `gpu` (QLoRA, 7B) | `A10G x1` | -- |
| `gpu` (QLoRA, 13B) | `A100_40GB x1` | -- |
| `gpu` (QLoRA, 70B) | `A100_80GB x2` | -- |
| `retries` | `1` | Checkpointed training: `0`. Unstable infra: `2-3`. |
| `timeout` | `86400` (24h) | Short fine-tunes: `7200`. Multi-day: `259200`. |

### GPU Sizing for Fine-tuning (QLoRA)

| Model Size | GPU | CPU | Memory |
|------------|-----|-----|--------|
| < 1B | T4 x1 | 4 | 16 GB |
| 1B-3B | T4 x1 | 4-8 | 32 GB |
| 3B-7B | A10G x1 or T4 x1 (tight) | 8 | 64 GB |
| 7B-13B | A100_40GB x1 | 8-12 | 90 GB |
| 13B-30B | A100_80GB x1 | 12-16 | 128 GB |
| 30B-70B | A100_80GB x2 or H100_80GB x1 | 16+ | 256 GB |

For LoRA, multiply VRAM by ~1.5x. For full fine-tuning, multiply by ~3-4x.

### Template

```yaml
name: ${FINETUNE_JOB_NAME}
type: job
image:
  type: image
  image_uri: ${TRAINING_IMAGE}
  command: "${TRAINING_COMMAND}"
resources:
  cpu_request: 4.0
  cpu_limit: 8.0
  memory_request: 32768
  memory_limit: 65536
  ephemeral_storage_request: 10000
  ephemeral_storage_limit: 20000
  devices:
    - type: "nvidia.com/gpu"
      name: "${GPU_TYPE:-A10G}"
      count: ${GPU_COUNT:-1}
retries: 1
timeout: 86400
env:
  HUGGING_FACE_HUB_TOKEN: ${HF_TOKEN}
  WANDB_API_KEY: ${WANDB_API_KEY}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## Quick Reference: Resource Defaults by Workload

| Workload | CPU Req | CPU Lim | Mem Req (MB) | Mem Lim (MB) | Eph Req (MB) | Eph Lim (MB) | GPU |
|----------|---------|---------|-------------|-------------|-------------|-------------|-----|
| Web API | 0.5 | 1.0 | 512 | 1024 | 1000 | 2000 | -- |
| LLM Inference | 4.0 | 8.0 | 16384 | 32768 | 5000 | 10000 | T4+ |
| Job (one-time) | 1.0 | 2.0 | 2048 | 4096 | 1000 | 2000 | -- |
| Scheduled Job | 1.0 | 2.0 | 2048 | 4096 | 1000 | 2000 | -- |
| Async Service | 0.5 | 1.0 | 512 | 1024 | 1000 | 2000 | -- |
| Notebook | 1.0 | 2.0 | 2048 | 4096 | 2000 | 5000 | -- |
| SSH Server | 2.0 | 4.0 | 4096 | 8192 | 5000 | 10000 | -- |
| LLM Finetuning | 4.0 | 8.0 | 32768 | 65536 | 10000 | 20000 | A10G+ |
