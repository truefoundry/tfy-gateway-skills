# TrueFoundry SDK Patterns Reference

<!-- Reference for AI agents deploying to TrueFoundry.
     These are tested patterns from real deployments.
     Each pattern has been verified to work with the TrueFoundry Python SDK.
     Do NOT guess or invent API shapes — use only what is documented here. -->

## 1. Service with Pre-built Image

Use this when deploying an existing container image (e.g., vLLM, Ollama, or any Docker Hub image).

```python
from truefoundry.deploy import Image, Port, Resources, Service, NvidiaGPU, GPUType

service = Service(
    name="my-service",
    image=Image(
        image_uri="vllm/vllm-openai:latest",
        command="python3 -m vllm.entrypoints.openai.api_server --model google/gemma-2-2b-it --host 0.0.0.0 --port 8000",
    ),
    ports=[Port(port=8000, protocol="TCP", expose=False, app_protocol="http")],
    resources=Resources(
        cpu_request=4, cpu_limit=4,
        memory_request=16384, memory_limit=16384,
        ephemeral_storage_request=50000, ephemeral_storage_limit=50000,
        devices=[NvidiaGPU(name=GPUType.T4, count=1)],
    ),
    env={},
)
service.deploy(workspace_fqn="YOUR_WORKSPACE_FQN", wait=False)
```

**IMPORTANT:** `command` goes inside `Image()`, NOT on `Service` directly. `Service` does not accept a `command` parameter.

---

## 2. Service with Local Code Build (Dockerfile)

Use this when the user has a Dockerfile in their project directory.

```python
from truefoundry.deploy import Build, DockerFileBuild, LocalSource, Port, Resources, Service

PROJECT_ROOT = "."  # path to the project root

service = Service(
    name="my-app",
    image=Build(
        build_source=LocalSource(project_root_path=PROJECT_ROOT, local_build=True),
        build_spec=DockerFileBuild(
            dockerfile_path="Dockerfile",
            build_context_path=".",
        ),
    ),
    ports=[Port(port=8000, protocol="TCP", expose=False, app_protocol="http")],
    resources=Resources(
        cpu_request=0.5, cpu_limit=1,
        memory_request=1024, memory_limit=2048,
        ephemeral_storage_request=1000, ephemeral_storage_limit=5000,
    ),
    env={},
)
service.deploy(workspace_fqn="YOUR_WORKSPACE_FQN", wait=False)
```

---

## 3. Service with PythonBuild (No Dockerfile)

Use this when the user has a Python app but no Dockerfile. The platform builds the image automatically.

```python
from truefoundry.deploy import Build, PythonBuild, LocalSource, Port, Resources, Service

PROJECT_ROOT = "."  # path to the project root

service = Service(
    name="my-app",
    image=Build(
        build_source=LocalSource(project_root_path=PROJECT_ROOT, local_build=True),
        build_spec=PythonBuild(
            python_version="3.12",
            command="uvicorn main:app --host 0.0.0.0 --port 8000",
            requirements_path="requirements.txt",
        ),
    ),
    ports=[Port(port=8000, protocol="TCP", expose=False, app_protocol="http")],
    resources=Resources(
        cpu_request=0.5, cpu_limit=1,
        memory_request=1024, memory_limit=2048,
        ephemeral_storage_request=1000, ephemeral_storage_limit=5000,
    ),
    env={},
)
service.deploy(workspace_fqn="YOUR_WORKSPACE_FQN", wait=False)
```

---

## 4. GPU Resources

**IMPORTANT:** Do NOT hardcode GPU types. Always fetch available GPUs from the cluster first.

### Check available GPUs

```bash
# Fetch cluster details to see available GPUs
GET /api/svc/v1/clusters/{cluster_id}
# The error message also tells you: "Valid devices are [T4, A10_4GB, ...]"
```

### GPUType enum values

```python
from truefoundry.deploy import NvidiaGPU, GPUType

# GPUType enum values (may vary by SDK version):
# T4, A10G, A10_4GB, A10_8GB, A10_12GB, A10_24GB,
# A100_40GB, A100_80GB, L4, L40S, H100_80GB, H100_94GB, H100_96GB, H200, B200
#
# But NOT all are available on every cluster. Always check first.

resources = Resources(
    cpu_request=4, cpu_limit=4,
    memory_request=16384, memory_limit=16384,
    ephemeral_storage_request=50000, ephemeral_storage_limit=50000,
    devices=[NvidiaGPU(name=GPUType.T4, count=1)],
)
```

---

## 5. Secrets in Environment Variables

Use `tfy-secret://` URI strings for secret references. Do NOT use `SecretMount` for env vars.

```python
env = {
    "DB_URL": "postgresql://localhost:5432/mydb",           # plain value
    "API_KEY": "tfy-secret://tfy-eo:my-secrets:API_KEY",   # secret reference
}
```

**NOTE:** `SecretMount` is for mounting secrets as FILES (requires `mount_path`), not for env vars.

---

## 6. Ports — Public vs Internal

```python
# Public (requires host matching cluster base_domain):
Port(
    port=8000,
    protocol="TCP",
    expose=True,
    host="my-app-dev-ws.ml.tfy-eo.truefoundry.cloud",
    app_protocol="http",
)

# Internal only:
Port(port=8000, protocol="TCP", expose=False, app_protocol="http")
```

**IMPORTANT:** Host must match the cluster's `base_domains`. Look up via:

```
GET /api/svc/v1/clusters/{cluster_id} → base_domains
```

Convention: `{service-name}-{workspace-name}.{base_domain}`

---

## 7. Helm Chart Deployment (API Manifest, Not SDK)

Helm charts are deployed via the API, not the Python SDK.

```json
{
  "manifest": {
    "name": "my-postgres",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "16.7.21",
      "oci_chart_url": "oci://registry-1.docker.io/bitnamicharts/postgresql"
    },
    "values": {},
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

**NOTE:** The manifest uses `type: "helm"` with `source.oci_chart_url`, NOT `kind: "HelmRelease"` with `chart.repo`.

---

## Documentation Links

- [Deploy Service](https://docs.truefoundry.com/docs/deploy-service-using-python-sdk)
- [Image & Build](https://docs.truefoundry.com/docs/api-reference-image-and-build)
- [Resources](https://docs.truefoundry.com/docs/configuring-resources)
- [GPU (Fractional)](https://docs.truefoundry.com/docs/using-fractional-gpus)
- [Ports & Domains](https://docs.truefoundry.com/docs/define-ports-and-domains)
- [Env & Secrets](https://docs.truefoundry.com/docs/environment-variables-and-secrets-jobs)
- [Secret Mounts](https://docs.truefoundry.com/docs/attaching-mounts)
