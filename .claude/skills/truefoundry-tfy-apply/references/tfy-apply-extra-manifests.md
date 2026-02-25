# Additional Manifest Examples

## Async Service Manifest

Deploys an async worker that processes messages from a queue.

```yaml
name: my-async-worker
type: async-service
image:
  type: image
  image_uri: docker.io/myorg/worker:latest
resources:
  cpu_request: 0.5
  cpu_limit: 1.0
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1024
  ephemeral_storage_limit: 2048
replicas:
  min: 1
  max: 10
env:
  QUEUE_URL: sqs://my-queue
  LOG_LEVEL: info
workspace_fqn: cluster-id:workspace-name
```

## Notebook Manifest

Launches a Jupyter Notebook with optional GPU.

```yaml
name: my-notebook
type: notebook
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/jupyter:0.4.6-py3.11.14-sudo
resources:
  cpu_request: 2
  cpu_limit: 4
  memory_request: 4000
  memory_limit: 8000
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
  storage: 20000
auto_shutdown:
  wait_time: 30
workspace_fqn: cluster-id:workspace-name
```

GPU notebook -- add devices:

```yaml
name: gpu-notebook
type: notebook
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/jupyter:0.4.6-cu129-py3.11.14-sudo
resources:
  cpu_request: 4
  cpu_limit: 8
  memory_request: 16000
  memory_limit: 32000
  ephemeral_storage_request: 10000
  ephemeral_storage_limit: 20000
  storage: 50000
  devices:
    - type: nvidia_gpu
      name: T4
      count: 1
auto_shutdown:
  wait_time: 60
workspace_fqn: cluster-id:workspace-name
```

## SSH Server Manifest

Launches a remote development environment with SSH access.

```yaml
name: my-ssh-server
type: ssh-server
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/ssh-server:latest
resources:
  cpu_request: 2
  cpu_limit: 4
  memory_request: 4000
  memory_limit: 8000
  ephemeral_storage_request: 5000
  ephemeral_storage_limit: 10000
  storage: 20000
auto_shutdown:
  wait_time: 60
workspace_fqn: cluster-id:workspace-name
```

GPU SSH server -- add devices:

```yaml
name: gpu-dev-server
type: ssh-server
image:
  type: image
  image_uri: public.ecr.aws/truefoundrycloud/ssh-server:latest
resources:
  cpu_request: 4
  cpu_limit: 8
  memory_request: 16000
  memory_limit: 32000
  ephemeral_storage_request: 10000
  ephemeral_storage_limit: 20000
  storage: 50000
  devices:
    - type: nvidia_gpu
      name: A10_24GB
      count: 1
auto_shutdown:
  wait_time: 120
workspace_fqn: cluster-id:workspace-name
```
