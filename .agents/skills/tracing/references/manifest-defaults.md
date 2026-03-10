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

### Build-from-Git Variant (Dockerfile)

```yaml
name: ${SERVICE_NAME}
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: ${REPO_URL}
    branch_name: ${BRANCH}  # Use current branch: git branch --show-current
  build_spec:
    type: dockerfile
    dockerfile_path: Dockerfile
    build_context_path: "."
ports:
  - port: ${PORT:-8000}
    protocol: TCP
    expose: true
    app_protocol: http
    host: ${SERVICE_NAME}-${WORKSPACE}.ml.${BASE_DOMAIN}
    path: /${SERVICE_NAME}-${WORKSPACE}-${PORT:-8000}/
resources:
  node:
    type: node_selector
  cpu_request: 0.5
  cpu_limit: 0.5
  memory_request: 1000
  memory_limit: 1000
  ephemeral_storage_request: 500
  ephemeral_storage_limit: 500
labels:
  tfy_openapi_path: openapi.json
allow_interception: false
replicas: 1
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Build-from-Git Variant (Python Buildpack — No Dockerfile)

```yaml
name: ${SERVICE_NAME}
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: ${REPO_URL}
    branch_name: ${BRANCH}  # Use current branch: git branch --show-current
  build_spec:
    type: tfy-python-buildpack
    build_context_path: ./
    command: uvicorn app:app --host 0.0.0.0 --port 8000
    python_version: "${PYTHON_VERSION:-3.10}"
    python_dependencies:
      type: pip
      requirements_path: requirements.txt
ports:
  - port: ${PORT:-8000}
    protocol: TCP
    expose: true
    app_protocol: http
    host: ${SERVICE_NAME}-${WORKSPACE}.ml.${BASE_DOMAIN}
    path: /${SERVICE_NAME}-${WORKSPACE}-${PORT:-8000}/
resources:
  node:
    type: node_selector
  cpu_request: 0.5
  cpu_limit: 0.5
  memory_request: 1000
  memory_limit: 1000
  ephemeral_storage_request: 500
  ephemeral_storage_limit: 500
labels:
  tfy_openapi_path: openapi.json
allow_interception: false
replicas: 1
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 2. LLM Inference

Model serving with vLLM (primary), TGI, Ollama, or NVIDIA NIM.

> **Recommended:** Call `GET /api/svc/v1/model-catalogues/deployment-specs?huggingfaceHubUrl=...&workspaceId=...` to get recommended GPU, CPU, and memory for a specific model. The values below are a rough guide; use the deployment-specs API for accurate per-model values.

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `16` | Smaller models (< 1B): 4-8 cores. Larger models: scale up. |
| `cpu_limit` | `18` | Same |
| `memory_request` | `182750` (~178 GB) | Smaller models need less. Use deployment-specs API. |
| `memory_limit` | `215000` (~210 GB) | Same |
| `ephemeral_storage_request` | `5000` | Large model downloads: increase to 50000+ |
| `ephemeral_storage_limit` | `105000` | Same |
| `shared_memory_size` | `181750` | Should be close to `memory_request` for GPU workloads |
| `gpu` | `A10_12GB x1` | Use deployment-specs API for accurate GPU recommendation |
| `replicas` | `1` | Production: use `min: 1, max: 3` |
| `allow_interception` | `false` | -- |
| `rollout_strategy` | `rolling_update (max_surge=0%, max_unavailable=25%)` | -- |
| `startup_probe failure_threshold` | `38` | Very large models (70B+): increase to 60-120 |
| `startup_probe initial_delay` | `10` | -- |
| `startup_probe period_seconds` | `10` | Gives ~6 min startup budget at default |
| `readiness_probe failure_threshold` | `5` | -- |
| `liveness_probe failure_threshold` | `10` | -- |

### GPU Sizing Guide (rough)

| Model Size | GPU | CPU | Memory |
|------------|-----|-----|--------|
| < 1B | T4 x1 | 4 | 16 GB |
| 1B-3B | A10_12GB x1 | 8-16 | 32-64 GB |
| 3B-7B | A10G x1 | 8-16 | 64-128 GB |
| 7B-13B | A100_40GB x1 | 10-16 | 90-180 GB |
| 13B-30B | A100_80GB x1 | 12-16 | 128-200 GB |
| 30B-70B | A100_80GB x2-4 or H100_94GB x2 | 16+ | 200+ GB |

> These are rough estimates. Always prefer the deployment-specs API for accurate sizing.

### Template (vLLM)

```yaml
name: ${MODEL_NAME}-vllm
type: service
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/vllm/vllm-openai:v0.13.0
  command: >-
    python3 -u -m vllm.entrypoints.openai.api_server
    --host 0.0.0.0 --port 8000
    --download-dir /data/
    --tokenizer-mode auto
    --model '$(MODEL_ID)'
    --tokenizer '$(MODEL_ID)'
    --trust-remote-code
    --dtype '$(DTYPE)'
    --tensor-parallel-size '$(GPU_COUNT)'
    --gpu-memory-utilization '$(GPU_MEMORY_UTILIZATION)'
    --served-model-name '$(MODEL_NAME)'
    --root-path '$(TFY_SERVICE_ROOT_PATH)'
    --max-model-len '$(MAX_MODEL_LENGTH)'
    --async-scheduling
ports:
  - port: 8000
    protocol: TCP
    expose: false
    app_protocol: http
resources:
  cpu_request: 16
  cpu_limit: 18
  memory_request: 182750
  memory_limit: 215000
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 105000
  shared_memory_size: 181750
  devices:
    - type: "nvidia.com/gpu"
      name: "${GPU_TYPE:-A10_12GB}"
      count: ${GPU_COUNT:-1}
artifacts_download:
  - type: huggingface-hub
    model_id: ${HF_MODEL_ID}
    revision: ${MODEL_REVISION:-main}
    ignore_patterns: ""
    download_path_env_variable: MODEL_ID
cache_volume:
  cache_size: ${CACHE_SIZE}
  storage_class: ${STORAGE_CLASS}
replicas: 1
allow_interception: false
rollout_strategy:
  type: rolling_update
  max_surge_percentage: 0
  max_unavailable_percentage: 25
labels:
  tfy_model_server: vLLM
  tfy_openapi_path: openapi.json
  tfy_sticky_session_header_name: x-truefoundry-sticky-session-id
  huggingface_model_task: text-generation
env:
  DTYPE: bfloat16
  GPU_COUNT: "${GPU_COUNT:-1}"
  MAX_MODEL_LENGTH: "${MAX_MODEL_LENGTH:-8192}"
  VLLM_NO_USAGE_STATS: "1"
  NVIDIA_REQUIRE_CUDA: "cuda>=12.1"
  GPU_MEMORY_UTILIZATION: "0.90"
  VLLM_CACHE_ROOT: /opt/truefoundry/.cache/vllm
startup_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 10
  period_seconds: 10
  timeout_seconds: 5
  failure_threshold: 38
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 3
  period_seconds: 10
  timeout_seconds: 5
  failure_threshold: 10
readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 3
  period_seconds: 10
  timeout_seconds: 5
  failure_threshold: 5
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

> **Note:** TGI is also supported as an alternative model server. Use the same resource structure but replace the image and command with TGI equivalents (`ghcr.io/huggingface/text-generation-inference`).

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

Queue-based worker using `worker_config.input_config`.

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `cpu_request` | `0.2` | CPU-bound processing: 2-4 cores |
| `cpu_limit` | `0.5` | Same |
| `memory_request` | `200` | ML inference workers: 4096-16384 |
| `memory_limit` | `500` | Same |
| `ephemeral_storage_request` | `1000` | File processing: 5000+ |
| `ephemeral_storage_limit` | `2000` | Same |
| `replicas` | `1` | Scale up for high throughput |
| `worker_config.num_concurrent_workers` | `1` | Increase for I/O-bound work |

### Template (SQS)

```yaml
name: ${SERVICE_NAME}
type: async-service
image:
  type: build
  build_source:
    type: git
    repo_url: ${REPO_URL}
    branch_name: ${BRANCH}  # Use current branch: git branch --show-current
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
  cpu_request: 0.2
  cpu_limit: 0.5
  memory_request: 200
  memory_limit: 500
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas: 1
worker_config:
  num_concurrent_workers: 1
  input_config:
    type: sqs
    wait_time_seconds: ${WAIT_TIME_SECONDS:-20}
    queue_url: ${SQS_QUEUE_URL}
    region_name: ${AWS_REGION}
    visibility_timeout: ${VISIBILITY_TIMEOUT:-30}
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Template (NATS)

```yaml
name: ${SERVICE_NAME}
type: async-service
image:
  type: build
  build_source:
    type: git
    repo_url: ${REPO_URL}
    branch_name: ${BRANCH}  # Use current branch: git branch --show-current
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
  cpu_request: 0.2
  cpu_limit: 0.5
  memory_request: 200
  memory_limit: 500
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas: 1
worker_config:
  num_concurrent_workers: 1
  input_config:
    type: nats
    wait_time_seconds: ${WAIT_TIME_SECONDS:-20}
    nats_url: ${NATS_URL}
    stream_name: ${NATS_STREAM_NAME}
    root_subject: ${NATS_ROOT_SUBJECT}
    consumer_name: ${NATS_CONSUMER_NAME}
    nats_metrics_url: ${NATS_METRICS_URL}
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Template (Kafka)

```yaml
name: ${SERVICE_NAME}
type: async-service
image:
  type: build
  build_source:
    type: git
    repo_url: ${REPO_URL}
    branch_name: ${BRANCH}  # Use current branch: git branch --show-current
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
  cpu_request: 0.2
  cpu_limit: 0.5
  memory_request: 200
  memory_limit: 500
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas: 1
worker_config:
  num_concurrent_workers: 1
  input_config:
    type: kafka
    wait_time_seconds: ${WAIT_TIME_SECONDS:-20}
    bootstrap_servers: ${KAFKA_BOOTSTRAP_SERVERS}
    topic_name: ${KAFKA_TOPIC_NAME}
    consumer_group: ${KAFKA_CONSUMER_GROUP}
    tls: ${KAFKA_TLS:-false}
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Template (AMQP)

```yaml
name: ${SERVICE_NAME}
type: async-service
image:
  type: build
  build_source:
    type: git
    repo_url: ${REPO_URL}
    branch_name: ${BRANCH}  # Use current branch: git branch --show-current
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
  cpu_request: 0.2
  cpu_limit: 0.5
  memory_request: 200
  memory_limit: 500
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas: 1
worker_config:
  num_concurrent_workers: 1
  input_config:
    type: amqp
    wait_time_seconds: ${WAIT_TIME_SECONDS:-20}
    url: ${AMQP_URL}
    queue_name: ${AMQP_QUEUE_NAME}
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 6. Helm Database

PostgreSQL, MySQL, MongoDB via Helm charts. Source types: `helm-repo`, `oci-repo`, `git-helm-repo`.

### Defaults (PostgreSQL)

| Field | Default | Override When |
|-------|---------|--------------|
| `chart` | Search [Artifact Hub](https://artifacthub.io) for the official chart | Same for MySQL, MongoDB -- find the official chart from the project maintainers |
| `version` | `"16.7.21"` | Check latest at registry |
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
  oci_chart_url: oci://REGISTRY/CHART_NAME  # Search Artifact Hub for the official chart
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
  oci_chart_url: oci://REGISTRY/CHART_NAME  # Search Artifact Hub for the official chart
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

### Template (MongoDB)

```yaml
name: ${DB_NAME:-mongodb}
type: helm
source:
  type: oci-repo
  version: "${MONGO_CHART_VERSION:-16.4.3}"
  oci_chart_url: oci://REGISTRY/CHART_NAME  # Search Artifact Hub for the official chart
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

Redis, Memcached via Helm charts. Source types: `helm-repo`, `oci-repo`, `git-helm-repo`.

### Defaults (Redis)

| Field | Default | Override When |
|-------|---------|--------------|
| `chart` | Search [Artifact Hub](https://artifacthub.io) for the official chart | Same for Memcached -- find the official chart from the project maintainers |
| `version` | `"20.6.2"` | Check latest at registry |
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
  oci_chart_url: oci://REGISTRY/CHART_NAME  # Search Artifact Hub for the official chart
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

### Template (Memcached)

```yaml
name: ${CACHE_NAME:-memcached}
type: helm
source:
  type: oci-repo
  version: "${MEMCACHED_CHART_VERSION:-7.5.5}"
  oci_chart_url: oci://REGISTRY/CHART_NAME  # Search Artifact Hub for the official chart
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
| `image` | `public.ecr.aws/truefoundrycloud/jupyter:0.4.5-py3.12.12-sudo` | Custom image with extra packages |
| `cpu_request` | `1` | ML workloads: 4-8 cores |
| `cpu_limit` | `3` | Same |
| `memory_request` | `4000` | ML with large datasets: 8192-32768 |
| `memory_limit` | `6000` | Same |
| `ephemeral_storage_request` | `5000` | Large datasets: 10000+ |
| `ephemeral_storage_limit` | `10000` | Same |
| `home_directory_size` | `20` (GB) | Large datasets or many notebooks: `50`-`100` |
| `cull_timeout` | `30` (min) | Long experiments: `60`-`120`. Disable: `0`. |
| `node.capacity_type` | `on_demand` | Cost savings: `spot` (but risk preemption) |
| `gpu` | None | ML training/inference: add appropriate GPU |

### Template

```yaml
name: ${NOTEBOOK_NAME}
type: notebook
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/jupyter:0.4.5-py3.12.12-sudo
resources:
  cpu_request: 1
  cpu_limit: 3
  memory_request: 4000
  memory_limit: 6000
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
home_directory_size: 20
cull_timeout: 30
node:
  type: node_selector
  capacity_type: on_demand
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### GPU Notebook Template

```yaml
name: ${NOTEBOOK_NAME}
type: notebook
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/jupyter:0.4.5-py3.12.12-sudo
resources:
  cpu_request: 4
  cpu_limit: 8
  memory_request: 16384
  memory_limit: 32768
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
  devices:
    - type: "nvidia.com/gpu"
      name: "${GPU_TYPE:-T4}"
      count: ${GPU_COUNT:-1}
home_directory_size: 50
cull_timeout: 60
node:
  type: node_selector
  capacity_type: on_demand
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 9. SSH Server

Remote development environment accessible via SSH.

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `image` (CPU) | `public.ecr.aws/truefoundrycloud/ssh-server:0.4.5-py3.12.12` | Custom image |
| `image` (GPU/CUDA) | `public.ecr.aws/truefoundrycloud/ssh-server:0.4.5-cu129-py3.12.12` | Custom CUDA image |
| `cpu_request` | `1` | Heavy development: 4-8 cores |
| `cpu_limit` | `3` | Same |
| `memory_request` | `4000` | ML development: 16384-32768 |
| `memory_limit` | `6000` | Same |
| `ephemeral_storage_request` | `5000` | Large repos or datasets: 20000+ |
| `ephemeral_storage_limit` | `10000` | Same |
| `home_directory_size` | `20` (GB) | Large projects: `50`-`100` |
| `node.capacity_type` | `on_demand` | Cost savings: `spot` (but risk preemption) |
| `gpu` | None | ML development: add appropriate GPU |

### Template (CPU)

```yaml
name: ${SERVER_NAME}
type: ssh-server
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/ssh-server:0.4.5-py3.12.12
resources:
  cpu_request: 1
  cpu_limit: 3
  memory_request: 4000
  memory_limit: 6000
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
home_directory_size: 20
node:
  type: node_selector
  capacity_type: on_demand
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

### Template (GPU / CUDA)

```yaml
name: ${SERVER_NAME}
type: ssh-server
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/ssh-server:0.4.5-cu129-py3.12.12
resources:
  cpu_request: 4
  cpu_limit: 8
  memory_request: 16384
  memory_limit: 32768
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
  devices:
    - type: "nvidia.com/gpu"
      name: "${GPU_TYPE:-T4}"
      count: ${GPU_COUNT:-1}
home_directory_size: 50
node:
  type: node_selector
  capacity_type: on_demand
env: {}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

---

## 10. LLM Finetuning

Fine-tuning language models using TrueFoundry's application-set with the `finetune-qlora` template.

### Defaults

| Field | Default | Override When |
|-------|---------|--------------|
| `type` | `application-set` | -- |
| `template` | `finetune-qlora` | -- |
| `convert_template_manifest` | `true` | -- |
| `image_uri` | `tfy.jfrog.io/tfy-images/llm-finetune:0.4.1` | Newer version available |
| `batch_size` | `1` | Increase if GPU memory allows |
| `epochs` | `10` | Fewer for large datasets, more for small |
| `learning_rate` | `0.0001` | Adjust based on convergence |
| `lora_alpha` | `64` | -- |
| `lora_r` | `32` | Higher rank for more expressive adapters |
| `max_length` | `2048` | Longer context: `4096`-`8192` |
| `data_type` | `chat` | Completion-style data: `completion` |
| `cpu_request` | `78` | Smaller models need less |
| `cpu_limit` | `80` | Same |
| `memory_request` | `535500` (~523 GB) | Smaller models need less |
| `memory_limit` | `630000` (~615 GB) | Same |
| `ephemeral_storage_request` | `710000` | Smaller models need less |
| `ephemeral_storage_limit` | `810000` | Same |
| `shared_memory_size` | `534500` | Should be close to `memory_request` |
| `gpu` (70B QLoRA) | `H100_94GB x2` | See GPU sizing table below |

### GPU Sizing for Fine-tuning (QLoRA)

| Model Size | GPU | CPU | Memory |
|------------|-----|-----|--------|
| < 1B | T4 x1 | 4 | 16 GB |
| 1B-3B | T4 x1 | 4-8 | 32 GB |
| 3B-7B | A10G x1 or T4 x1 (tight) | 8 | 64 GB |
| 7B-13B | A100_40GB x1 | 8-12 | 90 GB |
| 13B-30B | A100_80GB x1 | 12-16 | 128 GB |
| 30B-70B | H100_94GB x2 | 78+ | 535+ GB |

For LoRA, multiply VRAM by ~1.5x. For full fine-tuning, multiply by ~3-4x.

### Template

```yaml
name: ${FINETUNE_NAME}
type: application-set
template: finetune-qlora
convert_template_manifest: true
values:
  name: ${FINETUNE_NAME}
  model_id: ${HF_MODEL_ID}
  hf_token: ${HF_TOKEN}
  ml_repo: ${ML_REPO}
  data_type: ${DATA_TYPE:-chat}
  data:
    type: ${DATA_SOURCE_TYPE:-upload}
    training_uri: ${TRAINING_DATA_URI}
  hyperparams:
    batch_size: ${BATCH_SIZE:-1}
    epochs: ${EPOCHS:-10}
    learning_rate: ${LEARNING_RATE:-0.0001}
    lora_alpha: ${LORA_ALPHA:-64}
    lora_r: ${LORA_R:-32}
    max_length: ${MAX_LENGTH:-2048}
  image_uri: tfy.jfrog.io/tfy-images/llm-finetune:0.4.1
  resources:
    cpu_request: 78
    cpu_limit: 80
    memory_request: 535500
    memory_limit: 630000
    ephemeral_storage_request: 710000
    ephemeral_storage_limit: 810000
    shared_memory_size: 534500
    devices:
      - type: "nvidia.com/gpu"
        name: "${GPU_TYPE:-H100_94GB}"
        count: ${GPU_COUNT:-2}
workspace_fqn: ${TFY_WORKSPACE_FQN}
```

#### Data Source Types

| `data.type` | Description | `training_uri` Example |
|-------------|-------------|----------------------|
| `upload` | Upload a file | Path to local file |
| `truefoundry-artifact` | TrueFoundry artifact reference | Artifact FQN |
| `file-url` | Remote file URL | `https://example.com/data.jsonl` |

---

## Quick Reference: Resource Defaults by Workload

| Workload | CPU Req | CPU Lim | Mem Req (MB) | Mem Lim (MB) | Eph Req (MB) | Eph Lim (MB) | GPU |
|----------|---------|---------|-------------|-------------|-------------|-------------|-----|
| Web API | 0.5 | 1.0 | 512 | 1024 | 1000 | 2000 | -- |
| LLM Inference | 16 | 18 | 182750 | 215000 | 5000 | 105000 | A10_12GB+ |
| Job (one-time) | 1.0 | 2.0 | 2048 | 4096 | 1000 | 2000 | -- |
| Scheduled Job | 1.0 | 2.0 | 2048 | 4096 | 1000 | 2000 | -- |
| Async Service | 0.2 | 0.5 | 200 | 500 | 1000 | 2000 | -- |
| Notebook | 1 | 3 | 4000 | 6000 | 5000 | 10000 | -- |
| SSH Server | 1 | 3 | 4000 | 6000 | 5000 | 10000 | -- |
| LLM Finetuning | 78 | 80 | 535500 | 630000 | 710000 | 810000 | H100_94GB+ |
