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
| `env` | object | No | `{}` | Environment variables as key-value pairs. Values are strings. |
| `replicas` | int or object | No | `1` | Fixed integer or `{"min": N, "max": M}` for autoscaling. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN (format: `cluster-id:workspace-name`). |
| `liveness_probe` | object | No | -- | Liveness probe config. See [Probes](#probes). |
| `readiness_probe` | object | No | -- | Readiness probe config. See [Probes](#probes). |
| `startup_probe` | object | No | -- | Startup probe config. See [Probes](#probes). |
| `rollout_strategy` | object | No | -- | Rolling update strategy. See [Rollout Strategy](#rollout-strategy). |
| `mounts` | array | No | -- | Volume mounts. See [Mounts](#mounts). |
| `labels` | object | No | `{}` | Key-value labels for the deployment. |
| `allow_interception` | bool | No | `false` | Allow traffic interception for debugging. |

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
  DATABASE_URL: postgres://user:pass@db-host:5432/mydb
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

### Helm Source

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Source type: `oci-repo`, `helm-repo`, or `git-helm-repo` |
| `oci_chart_url` | string | Yes (oci-repo) | OCI chart URL (e.g., `oci://registry-1.docker.io/bitnamicharts/postgresql`) |
| `version` | string | Yes | Chart version (e.g., `"16.7.21"`) |
| `repo_url` | string | Yes (helm-repo) | Helm repository URL |
| `chart_name` | string | Yes (helm-repo) | Chart name in the repository |
| `repo_url` | string | Yes (git-helm-repo) | Git repository URL |
| `path` | string | Yes (git-helm-repo) | Path to chart within the repo |
| `branch_name` | string | No (git-helm-repo) | Git branch (default: main) |

### Minimal Example

```yaml
name: postgres-prod
type: helm
source:
  type: oci-repo
  version: "16.7.21"
  oci_chart_url: oci://registry-1.docker.io/bitnamicharts/postgresql
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
| `ports` | array | No | -- | Port configurations. Required for sidecar pattern. See [Port](#port). |
| `env` | object | No | `{}` | Environment variables as key-value pairs. |
| `workspace_fqn` | string | Yes | -- | Workspace FQN. |
| `replicas` | int or object | No | `1` | Fixed integer or `{"min": N, "max": M}`. Set `min: 0` for scale-to-zero. |
| `sidecar` | object | No | -- | Sidecar pattern config. See [Sidecar](#sidecar). |
| `input_queue` | object | Yes | -- | Input queue configuration. See [Queue Config](#queue-config). |
| `output_queue` | object | No | -- | Output queue configuration. Same structure as input_queue. |
| `mounts` | array | No | -- | Volume mounts. See [Mounts](#mounts). |

### Sidecar

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `destination_url` | string | Yes | HTTP endpoint for the sidecar to POST messages to (e.g., `http://0.0.0.0:8000/process`) |

### Minimal Example (Sidecar Pattern)

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
  destination_url: "http://0.0.0.0:8000/process"
input_queue:
  type: sqs
  queue_url: "https://sqs.us-east-1.amazonaws.com/123456789/my-input-queue"
  aws_region: us-east-1
  aws_access_key_id: "${AWS_ACCESS_KEY_ID}"
  aws_secret_access_key: "${AWS_SECRET_ACCESS_KEY}"
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
| `idle_timeout` | int | No | `1800` | Seconds of inactivity before auto-shutdown. Set `0` to disable. |
| `storage` | object | No | -- | Persistent storage configuration. |

### Storage

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `size` | string | Yes | Storage size (e.g., `"20Gi"`, `"50Gi"`) |

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
storage:
  size: "20Gi"
idle_timeout: 3600
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
    - type: "nvidia.com/gpu"
      name: "T4"
      count: 1
storage:
  size: "50Gi"
idle_timeout: 7200
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
| `ssh_keys` | array | No | -- | Authorized SSH public keys. |
| `storage` | object | No | -- | Persistent storage configuration. |

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
storage:
  size: "50Gi"
ssh_keys:
  - "ssh-ed25519 AAAAC3... user@host"
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
| `components` | array | Yes | -- | Array of manifest objects (service, job, helm, etc.) |
| `workspace_fqn` | string | Yes | -- | Workspace FQN. |

### Minimal Example

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
| `branch_name` | string | No (git) | Branch or ref to build from (default: `main`) |
| `project_root_path` | string | Yes (local) | Path to local project root |

### BuildSpec

Two build spec types are supported.

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

#### Python Build (No Dockerfile)

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `type` | string | Yes | -- | Must be `python` |
| `python_version` | string | No | `3.12` | Python version to use |
| `requirements_path` | string | No | `requirements.txt` | Path to requirements file |
| `command` | string | Yes | -- | Start command (e.g., `uvicorn main:app --host 0.0.0.0 --port 8000`) |

```yaml
build_spec:
  type: python
  python_version: "3.12"
  requirements_path: "requirements.txt"
  command: "uvicorn main:app --host 0.0.0.0 --port 8000"
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

```yaml
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
  devices:
    - type: "nvidia.com/gpu"
      name: "T4"
      count: 1
```

### GPU

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `nvidia.com/gpu` |
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
| `H200` | 141 GB | Hopper | Next-gen training |
| `B200` | 192 GB | Blackwell | Next-gen training |

Additional fractional GPU types: `A10_4GB`, `A10_8GB`, `A10_12GB`, `A10_24GB`.

Check available GPU types on the cluster before specifying -- not all types are available on every cluster.

```yaml
devices:
  - type: "nvidia.com/gpu"
    name: "A100_80GB"
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

Used by `async-service` type for input and output queue configuration.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Queue type: `sqs`, `nats`, `kafka`, or `amqp` |

#### SQS Queue

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `sqs` |
| `queue_url` | string | Yes | SQS queue URL |
| `aws_region` | string | Yes | AWS region |
| `aws_access_key_id` | string | Yes | AWS access key |
| `aws_secret_access_key` | string | Yes | AWS secret key |

#### NATS Queue

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `nats` |
| `nats_url` | string | Yes | NATS server URL |
| `subject` | string | Yes | NATS subject to subscribe to |
| `consumer_name` | string | No | Durable consumer name |

#### Kafka Queue

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `kafka` |
| `broker_url` | string | Yes | Kafka broker URL |
| `topic` | string | Yes | Kafka topic |
| `group_id` | string | No | Consumer group ID |

#### Google AMQP Queue

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Must be `amqp` |
| `queue_url` | string | Yes | AMQP connection URL |
| `queue_name` | string | Yes | Queue name |

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
