# Manifest Schema Reference

Complete YAML manifest field reference for all TrueFoundry deployment types. This is the single source of truth for manifest structure used by `tfy apply -f manifest.yaml` and REST API `PUT /api/svc/v1/apps`.

---

## Service

Long-running HTTP/gRPC service with optional autoscaling, health probes, and external exposure.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Service name. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `service` |
| `image` | object | Yes | -- | Image source. See [Image](#image). |
| `ports` | array | Yes | -- | Port configurations. See [Port](#port). |
| `resources` | object | Yes | -- | CPU, memory, GPU, storage. See [Resources](#resources). |
| `env` | object | No | `{}` | Environment variables as key-value pairs. Values are strings or `tfy-secret://` references. See [Environment Variables](#environment-variables). |
| `replicas` | int or object | No | `1` | Fixed integer or `{"min": N, "max": M}` for autoscaling. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN (format: `cluster-id:workspace-name`). |
| `liveness_probe` | object | No | -- | Liveness probe config. See [Probes](#probes). |
| `readiness_probe` | object | No | -- | Readiness probe config. See [Probes](#probes). |
| `startup_probe` | object | No | -- | Startup probe config. See [Probes](#probes). |
| `rollout_strategy` | object | No | -- | Rolling update strategy. See [Rollout Strategy](#rollout-strategy). |
| `mounts` | array | No | -- | Volume mounts. See [Mounts](#mounts). |
| `labels` | object | No | `{}` | Key-value labels for the deployment. |
| `allow_interception` | bool | No | `false` | Allow traffic interception for debugging. |
| `artifacts_download` | object | No | -- | Artifact download config for model files. See [Artifacts Download](#artifacts-download). |

### Minimal Example

```yaml
name: my-api
type: service
image:
  type: image
  image_uri: docker.io/myorg/my-api:v1.0
ports:
  - port: 8000
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
env:
  LOG_LEVEL: info
workspace_fqn: cluster-id:workspace-name
```

### Full Example (with probes, autoscaling, exposed port)

```yaml
name: my-api
type: service
image:
  type: image
  image_uri: docker.io/myorg/my-api:v1.0
ports:
  - port: 8000
    protocol: TCP
    expose: true
    host: my-api-ws.ml.example.truefoundry.cloud
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas:
  min: 2
  max: 5
env:
  LOG_LEVEL: info
  DATABASE_URL: tfy-secret://my-org:my-api-secrets:DATABASE_URL
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
readiness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
rollout_strategy:
  type: rolling
  max_unavailable_percentage: 25
  max_surge_percentage: 25
workspace_fqn: cluster-id:workspace-name
```

---

## Job

Batch workload that runs to completion and exits. Supports manual and cron triggers.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Job name. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `job` |
| `image` | object | Yes | -- | Image source. See [Image](#image). |
| `resources` | object | Yes | -- | CPU, memory, GPU, storage. See [Resources](#resources). |
| `env` | object | No | `{}` | Environment variables as key-value pairs. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN. |
| `retries` | int | No | `0` | Number of retry attempts on failure. |
| `timeout` | int | No | `3600` | Maximum job duration in seconds. |
| `trigger` | object | No | -- | Trigger configuration. See [Trigger](#trigger). |
| `mounts` | array | No | -- | Volume mounts. See [Mounts](#mounts). |

### Minimal Example

```yaml
name: data-pipeline
type: job
image:
  type: image
  image_uri: docker.io/myorg/pipeline:v1.0
  command: "python run_job.py"
resources:
  cpu_request: 1.0
  cpu_limit: 2.0
  memory_request: 2048
  memory_limit: 4096
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
retries: 3
timeout: 3600
workspace_fqn: cluster-id:workspace-name
```

### Scheduled Job Example

```yaml
name: nightly-etl
type: job
image:
  type: image
  image_uri: docker.io/myorg/etl:v1.0
  command: "python etl.py"
resources:
  cpu_request: 2.0
  cpu_limit: 4.0
  memory_request: 4096
  memory_limit: 8192
  ephemeral_storage_request: 2000
  ephemeral_storage_limit: 5000
retries: 2
timeout: 7200
trigger:
  type: cron
  schedule: "0 2 * * *"
env:
  INPUT_BUCKET: s3://data/input
  OUTPUT_BUCKET: s3://data/output
workspace_fqn: cluster-id:workspace-name
```

---

## Helm

Deploy any OCI-compatible Helm chart (databases, caches, message queues, monitoring).

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Release name. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `helm` |
| `source` | object | Yes | -- | Chart source. See [Helm Source](#helm-source). |
| `values` | object | No | `{}` | Helm values passed to the chart. Chart-specific. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN. |

### Source (Helm Repo)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `helm-repo` |
| `repo_url` | string | Yes | Helm repository URL |
| `chart` | string | Yes | Chart name |
| `version` | string | Yes | Chart version |

### Source (OCI Repo)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `oci-repo` |
| `oci_chart_url` | string | Yes | OCI chart URL (e.g., `oci://REGISTRY/CHART_NAME` — search [Artifact Hub](https://artifacthub.io) for the official chart) |
| `version` | string | Yes | Chart version |

### Source (Git Helm Repo)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `git-helm-repo` |
| `repo_url` | string | Yes | Git repository URL containing the Helm chart |
| `chart_path` | string | Yes | Path to chart within the repo |
| `version` | string | No | Git ref (branch, tag, commit) |

### Minimal Example

```yaml
name: postgres-prod
type: helm
source:
  type: oci-repo
  version: "16.7.21"
  oci_chart_url: oci://REGISTRY/CHART_NAME  # Search Artifact Hub for the official chart
values:
  auth:
    postgresPassword: "STRONG_PASSWORD_HERE"
    database: myapp
  primary:
    persistence:
      enabled: true
      size: 50Gi
    resources:
      requests:
        cpu: "2"
        memory: 2Gi
      limits:
        cpu: "4"
        memory: 4Gi
workspace_fqn: cluster-id:workspace-name
```

---

## Async Service

Queue-based processing service that consumes messages from SQS, NATS, Kafka, or Google AMQP. Supports scale-to-zero.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Service name. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `async-service` |
| `image` | object | Yes | -- | Image source. See [Image](#image). |
| `resources` | object | Yes | -- | CPU, memory, GPU, storage. See [Resources](#resources). |
| `ports` | array | No | -- | Port configurations. See [Port](#port). |
| `env` | object | No | `{}` | Environment variables as key-value pairs. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN. |
| `replicas` | int or object | No | `1` | Fixed integer or `{"min": N, "max": M}`. Set `min: 0` for scale-to-zero. |
| `worker_config` | object | Yes | -- | Worker and queue configuration. See [Worker Config](#worker-config). |
| `mounts` | array | No | -- | Volume mounts. See [Mounts](#mounts). |

### Worker Config

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `input_config` | object | Yes | Input queue configuration. See [Queue Input Config](#queue-input-config). |
| `num_concurrent_workers` | int | No | Number of concurrent workers. Default: `1`. |

### Queue Input Config

Four queue types are supported.

**SQS:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `sqs` |
| `queue_url` | string | Yes | SQS queue URL |
| `region_name` | string | Yes | AWS region |
| `wait_time_seconds` | int | No | Long polling wait time |
| `visibility_timeout` | int | No | Message visibility timeout in seconds |

**NATS:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `nats` |
| `nats_url` | string | Yes | NATS server URL |
| `stream_name` | string | Yes | NATS JetStream stream name |
| `root_subject` | string | Yes | Root subject to subscribe to |
| `consumer_name` | string | Yes | Consumer name |
| `nats_metrics_url` | string | No | NATS metrics URL for autoscaling |
| `wait_time_seconds` | int | No | Wait time |

**Kafka:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `kafka` |
| `bootstrap_servers` | string | Yes | Kafka bootstrap servers |
| `topic_name` | string | Yes | Kafka topic |
| `consumer_group` | string | Yes | Consumer group ID |
| `tls` | bool | No | Enable TLS. Default: `false` |
| `wait_time_seconds` | int | No | Wait time |

**AMQP:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `amqp` |
| `url` | string | Yes | AMQP connection URL |
| `queue_name` | string | Yes | Queue name |
| `wait_time_seconds` | int | No | Wait time |

### Minimal Example

```yaml
name: my-async-worker
type: async-service
image:
  type: image
  image_uri: docker.io/myorg/worker:v1.0
ports:
  - port: 8000
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
worker_config:
  input_config:
    type: sqs
    queue_url: "https://sqs.us-east-1.amazonaws.com/123456789/my-queue"
    region_name: us-east-1
    wait_time_seconds: 20
    visibility_timeout: 30
  num_concurrent_workers: 1
replicas: 1
workspace_fqn: cluster-id:workspace-name
```

---

## Notebook

Jupyter notebook environment with persistent storage and optional GPU.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Notebook name. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `notebook` |
| `image` | object | Yes | -- | Image source. See [Image](#image). |
| `resources` | object | Yes | -- | CPU, memory, GPU, storage. See [Resources](#resources). |
| `env` | object | No | `{}` | Environment variables. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN. |
| `cull_timeout` | int | No | `30` | Minutes of inactivity before auto-shutdown. |
| `home_directory_size` | int | No | `20` | Home directory size in GB. |

> **Note:** `node.capacity_type` can be set to `on_demand` or `spot` in the resources section.

### Minimal Example

```yaml
name: research-notebook
type: notebook
image:
  type: image
  image_uri: jupyter/scipy-notebook:latest
resources:
  cpu_request: 1.0
  cpu_limit: 2.0
  memory_request: 2048
  memory_limit: 4096
  ephemeral_storage_request: 2000
  ephemeral_storage_limit: 5000
home_directory_size: 20
cull_timeout: 60
env:
  JUPYTER_TOKEN: my-secret-token
workspace_fqn: cluster-id:workspace-name
```

### GPU Notebook Example

```yaml
name: ml-notebook
type: notebook
image:
  type: image
  image_uri: jupyter/tensorflow-notebook:latest
resources:
  cpu_request: 4.0
  cpu_limit: 8.0
  memory_request: 16384
  memory_limit: 32768
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
  devices:
    - type: nvidia_gpu
      name: T4
      count: 1
home_directory_size: 50
cull_timeout: 120
workspace_fqn: cluster-id:workspace-name
```

---

## SSH Server

Remote development environment accessible via SSH.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | SSH server name. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `ssh-server` |
| `image` | object | Yes | -- | Image source. See [Image](#image). |
| `resources` | object | Yes | -- | CPU, memory, GPU, storage. See [Resources](#resources). |
| `env` | object | No | `{}` | Environment variables. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN. |
| `home_directory_size` | int | No | `20` | Home directory size in GB. |

> **Note:** `node.capacity_type` can be set to `on_demand` or `spot` in the resources section.

### Minimal Example

```yaml
name: dev-server
type: ssh-server
image:
  type: image
  image_uri: ubuntu:22.04
resources:
  cpu_request: 2.0
  cpu_limit: 4.0
  memory_request: 4096
  memory_limit: 8192
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
home_directory_size: 50
workspace_fqn: cluster-id:workspace-name
```

---

## Volume

Persistent volume for data storage shared across services.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Volume name. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `volume` |
| `size` | string | Yes | -- | Volume size (e.g., `"10Gi"`, `"100Gi"`) |
| `access_mode` | string | No | `ReadWriteOnce` | `ReadWriteOnce`, `ReadWriteMany`, or `ReadOnlyMany` |
| `storage_class` | string | No | -- | Kubernetes storage class. Cluster-specific. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN. |

### Minimal Example

```yaml
name: shared-data
type: volume
size: "100Gi"
access_mode: ReadWriteOnce
workspace_fqn: cluster-id:workspace-name
```

---

## Application Set

Deploy multiple related resources as a single unit.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Application set name. |
| `type` | string | Yes | -- | Must be `application-set` |
| `components` | array | Conditional | -- | Array of manifest objects (service, job, helm, etc.). Required if not using template pattern. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN. |
| `template` | string | Conditional | -- | Template name (e.g., `finetune-qlora`). Required if using template pattern. |
| `convert_template_manifest` | bool | Conditional | -- | Must be `true` when using template pattern. |
| `values` | object | Conditional | -- | Template values. Structure depends on template. |

> **Note:** Either `components` OR `template`+`values` must be provided, not both.

### Components Example

```yaml
name: my-app-stack
type: application-set
components:
  - name: api-service
    type: service
    image:
      type: image
      image_uri: docker.io/myorg/api:v1.0
    ports:
      - port: 8000
        protocol: TCP
        expose: true
        app_protocol: http
    resources:
      cpu_request: 0.5
      cpu_limit: 1.0
      memory_request: 512
      memory_limit: 1024
      ephemeral_storage_request: 1000
      ephemeral_storage_limit: 2000
  - name: worker-job
    type: job
    image:
      type: image
      image_uri: docker.io/myorg/worker:v1.0
    resources:
      cpu_request: 1.0
      cpu_limit: 2.0
      memory_request: 1024
      memory_limit: 2048
      ephemeral_storage_request: 1000
      ephemeral_storage_limit: 2000
workspace_fqn: cluster-id:workspace-name
```

### Template Example (QLoRA Fine-tuning)

```yaml
name: qlora-my-model
type: application-set
template: finetune-qlora
convert_template_manifest: true
values:
  name: qlora-my-model
  model_id: unsloth/Llama-3.3-70B-Instruct
  hf_token: ""
  ml_repo: my-ml-repo
  data_type: chat
  data:
    type: upload
    training_uri: ""
  hyperparams:
    batch_size: 1
    epochs: 10
    learning_rate: 0.0001
    lora_alpha: 64
    lora_r: 32
    max_length: 2048
  image_uri: tfy.jfrog.io/tfy-images/llm-finetune:0.4.1
  resources:
    node:
      type: node_selector
    devices:
      - type: nvidia_gpu
        count: 2
        name: H100_94GB
    cpu_request: 78
    cpu_limit: 80
    memory_request: 535500
    memory_limit: 630000
    ephemeral_storage_request: 710000
    ephemeral_storage_limit: 810000
    shared_memory_size: 534500
workspace_fqn: cluster-id:workspace-name
```

---

## Shared Object Schemas

### Image

The `image` field defines how the container image is sourced. Two forms are supported.

#### Pre-built Image

Use an existing Docker image directly.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `image` |
| `image_uri` | string | Yes | Full image URI with tag (e.g., `docker.io/org/app:v1`) |
| `command` | string or array | No | Override container entrypoint. Omit if not needed -- do NOT set to `null`. |

```yaml
image:
  type: image
  image_uri: "docker.io/org/app:v1"
  command: "python main.py"
```

#### Build from Source

Build the image from a Git repository.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `build` |
| `build_source` | object | Yes | Source code location. See [BuildSource](#buildsource). |
| `build_spec` | object | Yes | Build instructions. See [BuildSpec](#buildspec). |
| `docker_registry` | string | No | Docker registry FQN for pushing built images. TrueFoundry auto-selects if omitted. |

```yaml
image:
  type: build
  build_source:
    type: git
    repo_url: "https://github.com/user/repo"
    branch_name: "main"
  build_spec:
    type: dockerfile
    dockerfile_path: "Dockerfile"
    build_context_path: "."
```

### BuildSource

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | `git` or `local` |
| `repo_url` | string | Yes (git) | Git repository URL |
| `branch_name` | string | No (git) | Branch to build from. Default: current branch (`git branch --show-current`). |
| `ref` | string | Yes (git) | Git ref (branch name, commit SHA, or tag). Required by `tfy apply` for git build sources. Typically set to the same value as `branch_name`. |
| `project_root_path` | string | Yes (local) | Path to local project root |

### BuildSpec

Two build spec types are supported.

> **Valid `build_spec.type` values: `dockerfile` | `tfy-python-buildpack`**
> Do NOT use `docker`, `build`, `python`, or any other value — the API will reject them.

#### Dockerfile Build

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `type` | string | Yes | -- | Must be `dockerfile` |
| `dockerfile_path` | string | No | `Dockerfile` | Path to Dockerfile relative to build context |
| `build_context_path` | string | No | `.` | Build context directory |
| `build_args` | object | No | `{}` | Docker build arguments as key-value pairs |

```yaml
build_spec:
  type: dockerfile
  dockerfile_path: "Dockerfile"
  build_context_path: "."
  build_args:
    PYTHON_VERSION: "3.12"
```

#### TrueFoundry Python Buildpack (No Dockerfile)

For Python projects without a Dockerfile, TrueFoundry can auto-build the image.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `type` | string | Yes | -- | Must be `tfy-python-buildpack` |
| `build_context_path` | string | No | `./` | Build context directory |
| `command` | string | Yes | -- | Start command (e.g., `uvicorn app:app --host 0.0.0.0 --port 8000`) |
| `python_version` | string | No | `3.10` | Python version to use |
| `python_dependencies` | object | Yes | -- | Dependency config. See below. |

**Python Dependencies:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `pip` |
| `requirements_path` | string | Yes | Path to requirements file (e.g., `requirements.txt`) |

```yaml
build_spec:
  type: tfy-python-buildpack
  build_context_path: ./
  command: uvicorn app:app --host 0.0.0.0 --port 8000
  python_version: "3.10"
  python_dependencies:
    type: pip
    requirements_path: requirements.txt
```

### Port

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `port` | int | Yes | -- | Container port number |
| `protocol` | string | No | `TCP` | Protocol: `TCP` or `UDP` |
| `expose` | bool | No | `false` | Whether to expose externally via ingress |
| `host` | string | Conditional | -- | Hostname for external access. Required when `expose: true`. Must match a cluster-configured domain. |
| `app_protocol` | string | No | `http` | Application protocol: `http` or `grpc` |

```yaml
ports:
  - port: 8000
    protocol: TCP
    expose: true
    host: my-api-ws.ml.example.truefoundry.cloud
    app_protocol: http
  - port: 50051
    protocol: TCP
    expose: false
    app_protocol: grpc
```

### Environment Variables

The `env` field is a key-value object. Values can be plain strings or `tfy-secret://` references to TrueFoundry secret groups.

#### Plain Values

```yaml
env:
  LOG_LEVEL: info
  APP_PORT: "8000"
```

#### Secret References

For sensitive values (passwords, tokens, API keys), use the `tfy-secret://` format instead of inline values:

```
tfy-secret://<TENANT_NAME>:<SECRET_GROUP_NAME>:<SECRET_KEY>
```

| Component | Description | Example |
|-----------|-------------|---------|
| `TENANT_NAME` | Subdomain of `TFY_BASE_URL` | `my-org` (from `https://my-org.truefoundry.cloud`) |
| `SECRET_GROUP_NAME` | Name of the secret group | `my-app-secrets` |
| `SECRET_KEY` | Key of the secret within the group | `DB_PASSWORD` |

#### Mixed Example

```yaml
env:
  LOG_LEVEL: info
  APP_PORT: "8000"
  DB_PASSWORD: tfy-secret://my-org:my-app-secrets:DB_PASSWORD
  API_KEY: tfy-secret://my-org:my-app-secrets:API_KEY
```

The secret group must be created before deploying. See the `secrets` skill for how to create secret groups and the `deploy` skill for the full secrets workflow.

### Resources

| Field | Type | Unit | Required | Default | Description |
|-------|------|------|----------|---------|-------------|
| `cpu_request` | float | cores | Yes | -- | Guaranteed CPU allocation |
| `cpu_limit` | float | cores | Yes | -- | Maximum CPU allocation |
| `memory_request` | int | MB | Yes | -- | Guaranteed memory in megabytes |
| `memory_limit` | int | MB | Yes | -- | Maximum memory in megabytes |
| `ephemeral_storage_request` | int | MB | Yes | -- | Guaranteed ephemeral disk in megabytes |
| `ephemeral_storage_limit` | int | MB | Yes | -- | Maximum ephemeral disk in megabytes |
| `devices` | array | -- | No | -- | GPU devices. See [GPU](#gpu). |
| `shared_memory_size` | int | MB | No | -- | Shared memory (/dev/shm) size in MB. Important for multi-GPU training and large model inference. |
| `node` | object | -- | No | -- | Node selection preferences. See [Node](#node). |

#### Node

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `node_selector` |
| `capacity_type` | string | No | `on_demand` or `spot`. Default: any. |

```yaml
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
  devices:
    - type: nvidia_gpu
      name: T4
      count: 1
  node:
    type: node_selector
    capacity_type: on_demand
```

### GPU

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `nvidia_gpu` |
| `name` | string | Yes | GPU type name. See enum values below. |
| `count` | int | Yes | Number of GPUs (1, 2, 4, 8) |

#### GPU Type Enum Values

| Value | VRAM | Architecture | Typical Use |
|-------|------|--------------|-------------|
| `T4` | 16 GB | Turing | Inference, small models |
| `A10G` | 24 GB | Ampere | Medium inference, fine-tuning |
| `L4` | 24 GB | Ada Lovelace | Inference optimized |
| `L40S` | 48 GB | Ada Lovelace | Large inference |
| `A100_40GB` | 40 GB | Ampere | Large models, training |
| `A100_80GB` | 80 GB | Ampere | Very large models |
| `H100_80GB` | 80 GB | Hopper | Training, large models |
| `H100_94GB` | 94 GB | Hopper | Training, large models |
| `H200` | 141 GB | Hopper | Next-gen training |
| `B200` | 192 GB | Blackwell | Next-gen training |

Additional fractional GPU types: `A10_4GB`, `A10_8GB`, `A10_12GB`, `A10_24GB`.

Check available GPU types on the cluster before specifying -- not all types are available on every cluster.

```yaml
devices:
  - type: nvidia_gpu
    name: A100_80GB
    count: 2
```

### Probes

All three probe types (`liveness_probe`, `readiness_probe`, `startup_probe`) share the same structure.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `config` | object | Yes | -- | Probe check configuration. See below. |
| `initial_delay_seconds` | int | No | `5` | Seconds to wait before first probe |
| `period_seconds` | int | No | `10` | Seconds between probes |
| `timeout_seconds` | int | No | `2` | Seconds before probe times out |
| `failure_threshold` | int | No | `3` | Consecutive failures before action |
| `success_threshold` | int | No | `1` | Consecutive successes needed |

#### Probe Config Types

**HTTP Probe:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `http` |
| `path` | string | Yes | HTTP path to check (e.g., `/health`) |
| `port` | int | Yes | Port to check |

```yaml
liveness_probe:
  config:
    type: http
    path: /health
    port: 8000
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
```

**TCP Probe:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `tcp` |
| `port` | int | Yes | Port to check |

```yaml
readiness_probe:
  config:
    type: tcp
    port: 5432
  initial_delay_seconds: 5
  period_seconds: 10
  timeout_seconds: 2
  failure_threshold: 3
```

**Command Probe:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `command` |
| `command` | array | Yes | Command to execute. Exit 0 = healthy. |

```yaml
liveness_probe:
  config:
    type: command
    command: ["pg_isready", "-U", "postgres"]
  initial_delay_seconds: 10
  period_seconds: 10
  timeout_seconds: 5
  failure_threshold: 3
```

### Trigger

Used by `job` type to configure execution triggers.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Trigger type: `manual` or `cron` |
| `schedule` | string | Yes (cron) | Cron expression (e.g., `"0 2 * * *"` for 2 AM daily) |

```yaml
trigger:
  type: cron
  schedule: "0 2 * * *"
```

### Queue Config

Queue configuration is now part of `worker_config.input_config` in the async-service manifest. See [Queue Input Config](#queue-input-config) under the Async Service section for full details on all four supported queue types (SQS, NATS, Kafka, AMQP).

### Artifacts Download

Used for downloading model files from HuggingFace Hub or other sources before container start.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `artifacts` | array | Yes | List of artifact sources to download. |
| `cache_volume` | object | No | Cache volume for downloaded artifacts. |

#### Artifact (HuggingFace Hub)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `huggingface-hub` |
| `model_id` | string | Yes | HuggingFace model ID (e.g., `deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B`) |
| `revision` | string | No | Specific commit SHA or branch |
| `ignore_patterns` | array | No | Glob patterns to skip (e.g., `["*.h5", "*.ot", "pytorch_model*.bin"]`) |
| `download_path_env_variable` | string | No | Env var name set to download path (default: `MODEL_ID`) |

#### Cache Volume

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cache_size` | int | Yes | Cache size in GB |
| `storage_class` | string | No | Storage class (e.g., `azureblob-nfs-premium`) |

### Rollout Strategy

Controls how deployments are rolled out for services.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `type` | string | Yes | `rolling` | Strategy type: `rolling` |
| `max_unavailable_percentage` | int | No | `25` | Max percentage of pods that can be unavailable during update |
| `max_surge_percentage` | int | No | `25` | Max percentage of extra pods that can be created during update |

```yaml
rollout_strategy:
  type: rolling
  max_unavailable_percentage: 25
  max_surge_percentage: 25
```

### Autoscaling

When `replicas` is an object instead of an integer, autoscaling is enabled.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `min` | int | Yes | Minimum number of replicas. Set `0` for scale-to-zero (async-service only). |
| `max` | int | Yes | Maximum number of replicas |

```yaml
# Fixed replicas
replicas: 1

# Autoscaling
replicas:
  min: 2
  max: 10

# Scale-to-zero (async-service only)
replicas:
  min: 0
  max: 5
```

### Mounts

Mount volumes or secrets into the container.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Mount type: `volume`, `secret`, `config_map` |
| `mount_path` | string | Yes | Path inside the container |
| `name` | string | Yes | Name of the volume, secret, or config map to mount |
| `read_only` | bool | No | Whether to mount read-only (default: `false`) |

```yaml
mounts:
  - type: volume
    name: shared-data
    mount_path: /data
    read_only: false
  - type: secret
    name: my-secret-group
    mount_path: /secrets
    read_only: true
```

### Capacity Type (Node Affinity)

For GPU or resource-intensive workloads, specify node capacity preference.

| Value | Description |
|-------|-------------|
| `on_demand` | Use on-demand (non-preemptible) nodes. Best for production. |
| `spot` | Use spot/preemptible nodes. Cheaper but may be interrupted. |
| `any` | Use any available node type. |

---

## Workflow

Python-based DAG orchestration built on [Flyte](https://flyte.org/). Workflows are defined using `@task`/`@workflow` decorators in Python and deployed via `tfy deploy workflow` CLI or `tfy apply`.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Workflow name. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `workflow` |
| `source` | object | Yes | -- | Source code location. See [Workflow Source](#workflow-source). |
| `workflow_file_path` | string | Yes | -- | Path to Python file containing the `@workflow` decorated function. |
| `alerts` | array | No | -- | Alert/notification config. See [Workflow Alerts](#workflow-alerts). |

> **Note:** `workspace_fqn` is passed via CLI flag (`--workspace_fqn`) or as a sibling key in the REST API, not inside the manifest itself.

### Workflow Source

**Local Source:**

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `type` | string | Yes | -- | Must be `local` |
| `project_root_path` | string | No | `./` | Path to project root directory |

**Remote Source:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `remote` |
| `remote_uri` | string | Yes | URI to remote source archive |

### Workflow Alerts

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `notification_target` | object | No | -- | Where to send alerts. See notification types below. |
| `on_completion` | bool | No | `false` | Alert on successful completion |
| `on_failure` | bool | No | `true` | Alert on failure |

**Notification target types:**

- `Email`: `type: email`, `notification_channel` (string), `to_emails` (array of strings)
- `SlackWebhook`: `type: slack-webhook`, `notification_channel` (string)
- `SlackBot`: `type: slack-bot`, `notification_channel` (string), `channels` (array of strings)

### Minimal Example (CLI -- Primary)

```bash
tfy deploy workflow \
  --name my-ml-pipeline \
  --file workflow.py \
  --workspace_fqn "cluster-id:workspace-name"
```

### YAML Manifest Example (Alternative)

```yaml
name: my-ml-pipeline
type: workflow
source:
  type: local
  project_root_path: ./
workflow_file_path: workflow.py
```

```bash
tfy apply -f workflow-manifest.yaml --workspace-fqn "cluster-id:workspace-name"
```

### With Alerts Example

```yaml
name: nightly-pipeline
type: workflow
source:
  type: local
  project_root_path: ./
workflow_file_path: workflow.py
alerts:
  - notification_target:
      type: slack-webhook
      notification_channel: my-slack-channel
    on_failure: true
    on_completion: false
```

> **Important:** Workflow task definitions (resources, images, pip packages) live in the Python code via `PythonTaskConfig`, not in the YAML manifest. The manifest only controls the deployment wrapper. See the `workflows` skill for Python code patterns.

---

## Agent

Register an AI agent with TrueFoundry's Agent Gateway. Agents can be prompt-based (backed by a ChatPrompt version) or hosted A2A agents.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Agent name. |
| `type` | string | Yes | -- | Must be `agent` |
| `description` | string | Yes | -- | Human-readable agent description. |
| `source` | object | Yes | -- | Agent source. See [Agent Source](#agent-source). |
| `collaborators` | array | Yes | -- | Access control list. See [Collaborators](#collaborators). |
| `sample_inputs` | array | No | -- | Example inputs shown in Agent Chat UI. |
| `owned_by` | object | No | -- | Ownership info. `{"account": "team-slug"}` |

### Agent Source

**Prompt Source** (backed by a ChatPrompt):

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `type` | string | Yes | -- | Must be `prompt` |
| `prompt_version_fqn` | string | Yes | -- | FQN of a ChatPrompt version |
| `skills` | array | No | -- | Skills/tools the agent can use. See [Agent Skills](#agent-skills). |

**Hosted A2A Agent** (external agent via A2A protocol):

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `type` | string | Yes | -- | Must be `hosted-a2a-agent` |
| `agent_card_url` | string | Yes | -- | URL to the A2A agent card |
| `headers` | object | No | -- | Auth headers as key-value pairs |

### Agent Skills

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | Unique skill identifier |
| `name` | string | Yes | Display name |
| `description` | string | Yes | What the skill does |
| `tags` | array | No | Categorization tags |
| `examples` | array | No | Example invocations |
| `input_modes` | array | No | Supported input modes |
| `output_modes` | array | No | Supported output modes |

### Collaborators

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `subject` | string | Yes | User or team identifier |
| `role_id` | string | Yes | Role ID (e.g., `admin`, `viewer`) |

### Sample Inputs

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string | No | Sample text input |
| `variables` | object | No | Variable key-value pairs for prompt templates |

### Prompt-based Agent Example

```yaml
name: support-agent
type: agent
description: Customer support agent that answers product questions
source:
  type: prompt
  prompt_version_fqn: "prompt:my-org:support-prompt:3"
  skills:
    - id: product-search
      name: Product Search
      description: Search the product catalog
      tags: ["search", "products"]
      examples: ["Find laptops under $1000"]
collaborators:
  - subject: "team:engineering"
    role_id: admin
  - subject: "team:support"
    role_id: viewer
sample_inputs:
  - text: "How do I reset my password?"
  - text: "What's the return policy for electronics?"
```

> **Security:** `agent_card_url` and `hosted-a2a-agent` sources are fetched at runtime and can influence agent behavior. Only register agents from trusted, authenticated endpoints. Use `headers` with secret references for auth.

### A2A Agent Example

```yaml
name: external-research-agent
type: agent
description: Research agent hosted externally via A2A protocol
source:
  type: hosted-a2a-agent
  agent_card_url: "https://research-agent.example.com/.well-known/agent.json"
  headers:
    Authorization: "Bearer ${secret:api-key}"
collaborators:
  - subject: "team:research"
    role_id: admin
```

---

## MCP Server (Remote)

Register a remote MCP server with TrueFoundry's Agent Gateway for discovery and access control. Connects to an externally hosted MCP server.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Server name. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `mcp-server/remote` |
| `description` | string | Yes | -- | Human-readable description of what the server provides. |
| `url` | string | Yes | -- | MCP server URL. |
| `transport` | string | Yes | -- | `streamable-http` or `sse`. |
| `auth_data` | object | No | -- | Auth config. See [MCP Auth](#mcp-auth). |
| `collaborators` | array | No | -- | Access control list. See [Collaborators](#collaborators). |
| `tls_settings` | object | No | -- | TLS configuration (e.g., custom CA certificates). |
| `tags` | array | No | -- | Categorization tags. |

### MCP Auth

| Type | Fields | Description |
|------|--------|-------------|
| `header` | `headers` (object, required) | Static header-based auth. |
| `oauth2` | `authorization_url`, `token_url`, `client_id`, `client_secret`, `jwt_source` (`access_token` or `id_token`), `scopes`, `pkce` (bool), `dynamic_client_registration` (object) | OAuth2 flow. |
| `passthrough` | (none) | Pass through caller's credentials. |

**OAuth2 `dynamic_client_registration`:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `registration_endpoint` | string | Yes | Dynamic client registration endpoint URL. |
| `initial_access_token` | string | No | Initial access token for registration. |

### MCP Transport Values

| Value | Description |
|-------|-------------|
| `streamable-http` | Streamable HTTP transport (preferred) |
| `sse` | Server-Sent Events transport (legacy) |

### Example

```yaml
name: github-mcp
type: mcp-server/remote
description: GitHub repository tools
url: "https://github-mcp.internal.example.com/mcp"
transport: streamable-http
auth_data:
  type: header
  headers:
    Authorization: "Bearer ${secret:github-token}"
collaborators:
  - subject: "team:engineering"
    role_id: admin
tags:
  - developer-tools
```

### OAuth2 Example

```yaml
name: jira-mcp
type: mcp-server/remote
description: Jira project management tools
url: "https://jira-mcp.example.com/mcp"
transport: streamable-http
auth_data:
  type: oauth2
  authorization_url: "https://auth.example.com/authorize"
  token_url: "https://auth.example.com/token"
  client_id: "my-client-id"
  client_secret: "tfy-secret://my-org:mcp-secrets:jira-client-secret"
  jwt_source: access_token
  scopes:
    - read:jira-work
    - write:jira-work
  pkce: true
collaborators:
  - subject: "team:engineering"
    role_id: admin
```

---

## MCP Server (Virtual)

Create a virtual MCP server that aggregates multiple registered remote servers behind a single endpoint. Useful for presenting a unified toolset to agents.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Virtual server name. |
| `type` | string | Yes | -- | Must be `mcp-server/virtual` |
| `description` | string | Yes | -- | Human-readable description. |
| `servers` | array | Yes | -- | Backend server references. See below. |
| `collaborators` | array | No | -- | Access control list. See [Collaborators](#collaborators). |

### Server Source

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Name of a registered remote MCP server. |
| `enabled_tools` | array | No | Subset of tools to expose (all if omitted). |

### Example

```yaml
name: all-dev-tools
type: mcp-server/virtual
description: Unified development toolset
servers:
  - name: github-mcp
    enabled_tools: ["search_repos", "create_pr"]
  - name: slack-mcp
collaborators:
  - subject: "team:engineering"
    role_id: admin
```

---

## MCP Server (OpenAPI)

Register an MCP server backed by an OpenAPI specification. TrueFoundry automatically converts OpenAPI operations into MCP tools. Maximum 30 tools per server.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Server name. |
| `type` | string | Yes | -- | Must be `mcp-server/openapi` |
| `description` | string | Yes | -- | Human-readable description. |
| `spec` | object | Yes | -- | OpenAPI spec source. See below. |
| `collaborators` | array | No | -- | Access control list. See [Collaborators](#collaborators). |

### Spec Source

Provide the OpenAPI spec either as a remote URL or inline.

> **Security: Remote specs are fetched at runtime and converted into MCP tools that control agent capabilities. Only use trusted, verified URLs. Prefer `inline` specs for sensitive environments to avoid runtime dependency on external endpoints.**

**Remote URL:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `remote` |
| `url` | string | Yes | URL to the OpenAPI spec (JSON or YAML). |

**Inline:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `inline` |
| `content` | string | Yes | OpenAPI spec content (JSON or YAML string). |

### Example

```yaml
name: weather-api
type: mcp-server/openapi
description: Weather data tools from OpenAPI spec
spec:
  type: remote
  url: "https://api.weather.example.com/openapi.json"
collaborators:
  - subject: "team:data-science"
    role_id: admin
```

---

## MCP Server References in Agents/Prompts

Agents and prompts reference MCP servers using these patterns:

**By FQN** (registered server):
```yaml
type: mcp-server-fqn
integration_fqn: "mcp-server:my-org:github-mcp"
enable_all_tools: true
```

**By URL** (direct connection):
```yaml
type: mcp-server-url
url: "https://my-mcp-server.example.com/mcp"
headers:
  Authorization: "Bearer my-token"
enable_all_tools: false
tools:
  - name: search_repos
  - name: create_pr
```

---

## Role

Define a role with specific permissions for access control across TrueFoundry resources.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Role identifier. Lowercase alphanumeric and hyphens only. |
| `type` | string | Yes | -- | Must be `role` |
| `displayName` | string | No | -- | Human-readable display name. |
| `description` | string | No | -- | Role description. |
| `resourceType` | string | Yes | -- | Resource type this role applies to (e.g., `workspace`, `application`, `mcp-server`). |
| `permissions` | array | Yes | -- | List of permission strings granted by this role. |

### Example

```yaml
name: mcp-server-viewer
type: role
displayName: MCP Server Viewer
description: Read-only access to MCP servers
resourceType: mcp-server
permissions:
  - read
  - list
```

---

## Team

Define a team with members for organizational access control.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Team identifier. |
| `type` | string | Yes | -- | Must be `team` |
| `description` | string | No | -- | Team description. |
| `members` | array | No | -- | Team members. See below. |

### Member

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `subject` | string | Yes | User identifier (e.g., email or user ID). |
| `role` | string | Yes | Role within the team (e.g., `admin`, `member`). |

### Example

```yaml
name: ml-platform-team
type: team
description: ML platform engineering team
members:
  - subject: "user:alice@example.com"
    role: admin
  - subject: "user:bob@example.com"
    role: member
```

---

## Gateway Guardrails Config

Configure guardrail rules for TrueFoundry's AI Gateway. Rules define when and how guardrails are applied to LLM inputs/outputs and MCP tool invocations.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Config name. |
| `type` | string | Yes | -- | Must be `gateway-guardrails-config` |
| `gateway_ref` | string | Yes | -- | Reference to the gateway this config applies to. |
| `rules` | array | Yes | -- | Guardrail rules. See below. |

### Rule

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | string | Yes | -- | Unique rule identifier. |
| `when` | object | Yes | -- | Conditions for applying this rule. See below. |
| `llm_input_guardrails` | array | No | -- | Guardrails applied to LLM inputs. |
| `llm_output_guardrails` | array | No | -- | Guardrails applied to LLM outputs. |
| `mcp_tool_pre_invoke_guardrails` | array | No | -- | Guardrails applied before MCP tool invocation. |
| `mcp_tool_post_invoke_guardrails` | array | No | -- | Guardrails applied after MCP tool invocation. |

### When Conditions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `target_conditions` | array | No | Conditions on the target resource (e.g., agent, model). |
| `subject_conditions` | array | No | Conditions on the calling subject (e.g., user, team). |

### Example

```yaml
name: production-guardrails
type: gateway-guardrails-config
gateway_ref: "gateway:my-org:prod-gateway"
rules:
  - id: pii-detection
    when:
      target_conditions:
        - type: agent
          names: ["customer-support-agent"]
      subject_conditions:
        - type: team
          names: ["external-users"]
    llm_input_guardrails:
      - name: pii-detector
        config:
          block_on_detection: true
    llm_output_guardrails:
      - name: pii-redactor
        config:
          redact: true
```

---

## Guardrail Config Group (Provider Account)

Register a guardrail integration provider with TrueFoundry. Defines how external guardrail providers are integrated and enforced.

### Top-level Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | string | Yes | -- | Config group name. |
| `type` | string | Yes | -- | Must be `provider-account/guardrail-config-group` |
| `integrations` | array | Yes | -- | Guardrail provider integrations. See below. |

### Integration

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `type` | string | Yes | -- | Provider type identifier. |
| `operation` | string | Yes | -- | `validate` or `mutate`. |
| `enforcing_strategy` | string | Yes | -- | `enforce`, `audit`, or `enforce_but_ignore_on_error`. |
| `priority` | int | No | -- | Execution priority (lower runs first). |

### Enforcing Strategy Values

| Value | Description |
|-------|-------------|
| `enforce` | Block requests that fail guardrail checks. |
| `audit` | Log failures but allow requests through. |
| `enforce_but_ignore_on_error` | Enforce unless the guardrail itself errors, then allow through. |

### Example

```yaml
name: content-safety-guardrails
type: provider-account/guardrail-config-group
integrations:
  - type: openai-moderation
    operation: validate
    enforcing_strategy: enforce
    priority: 1
  - type: custom-pii-scanner
    operation: mutate
    enforcing_strategy: enforce_but_ignore_on_error
    priority: 2
```

---

## Enum Reference

### Type Values

| Value | Description |
|-------|-------------|
| `service` | Long-running HTTP/gRPC service |
| `job` | Batch workload that runs to completion |
| `helm` | Helm chart deployment |
| `async-service` | Queue-based processing service |
| `notebook` | Jupyter notebook environment |
| `ssh-server` | Remote development via SSH |
| `volume` | Persistent volume |
| `application-set` | Multi-resource deployment |
| `workflow` | Python DAG orchestration (Flyte-based) |
| `agent` | AI agent registration for Agent Gateway |
| `mcp-server/remote` | Remote MCP server registration |
| `mcp-server/virtual` | Virtual MCP server (aggregates multiple servers) |
| `mcp-server/openapi` | MCP server backed by OpenAPI spec |
| `role` | Role definition for access control |
| `team` | Team definition with members |
| `gateway-guardrails-config` | Guardrail rules for AI Gateway |
| `provider-account/guardrail-config-group` | Guardrail provider integration |

### Protocol Values

| Value | Description |
|-------|-------------|
| `TCP` | TCP protocol (default) |
| `UDP` | UDP protocol |

### App Protocol Values

| Value | Description |
|-------|-------------|
| `http` | HTTP protocol (default) |
| `grpc` | gRPC protocol |

### Build Spec Type Values

| Value | Description |
|-------|-------------|
| `dockerfile` | Build from Dockerfile |
| `tfy-python-buildpack` | Auto-build Python project (no Dockerfile needed) |
| `python` | Auto-build Python app (no Dockerfile needed) |

### Build Source Type Values

| Value | Description |
|-------|-------------|
| `git` | Clone and build from Git repository |
| `local` | Build from local source code |

### Trigger Type Values

| Value | Description |
|-------|-------------|
| `manual` | Triggered manually via API or dashboard |
| `cron` | Triggered on a cron schedule |

### Queue Type Values

| Value | Description |
|-------|-------------|
| `sqs` | Amazon SQS |
| `nats` | NATS JetStream |
| `kafka` | Apache Kafka |
| `amqp` | Google AMQP / RabbitMQ |

### Probe Config Type Values

| Value | Description |
|-------|-------------|
| `http` | HTTP GET probe |
| `tcp` | TCP socket probe |
| `command` | Exec command probe |

---

## Gotchas

1. **Do not set `command: null`** -- Omit the `command` field entirely if not needed. Setting it to `null` causes errors.
2. **Memory values are in MB** -- Not bytes, not GB. `512` means 512 MB.
3. **Ephemeral storage is required** -- Always include `ephemeral_storage_request` and `ephemeral_storage_limit`.
4. **`host` must match cluster base domains** -- Use cluster discovery API to look up valid domains. Wrong domain causes deployment failure.
5. **`replicas` can be int or object** -- Use `1` for fixed, or `{"min": 2, "max": 10}` for autoscaling.
6. **`workspace_fqn` goes in the manifest** -- When using the REST API, also pass `workspaceId` (internal ID) as a sibling of `manifest`.
7. **Git repos must be accessible** -- For private repos, ensure credentials are configured in TrueFoundry.
8. **Scale-to-zero is async-service only** -- Setting `min: 0` on a regular service is not supported.
9. **Workflow `workspace_fqn` is a CLI flag, not a manifest field** -- Pass it via `--workspace_fqn` on `tfy deploy workflow` or as a sibling key in the REST API.
10. **Workflow task config lives in Python, not YAML** -- Resources, images, and pip packages for individual tasks are defined in the Python file via `PythonTaskConfig`, not in the deployment manifest.
11. **MCP server types vs MCP service** -- `mcp-server/remote`, `mcp-server/virtual`, and `mcp-server/openapi` register servers with the Agent Gateway. To actually run an MCP server, deploy it as a `service` type.
12. **Agent `collaborators` is required** -- Every agent manifest must include at least one collaborator for access control.
