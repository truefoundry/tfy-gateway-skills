# Async Service Sidecar Deploy Template (SDK)

Use this `deploy.py` template when deploying an async service with the sidecar pattern via the TrueFoundry Python SDK.

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
    # GitSource,            # uncomment for Git repo builds
    # Image,                # uncomment for pre-built Docker images
    Port,
    Resources,
    # NodeSelector,         # uncomment for capacity type (spot/on-demand)
    SQSQueueConfig,       # or NATSQueueConfig, KafkaQueueConfig
    SidecarPattern,
    Replicas,
    # NvidiaGPU, GPUType,  # uncomment for GPU workloads
)

PROJECT_ROOT = str(Path(__file__).resolve().parent)

async_service = AsyncService(
    name="<SERVICE_NAME>",                          # ← ask user
    # Option A: Build from local source code
    image=Build(
        build_source=LocalSource(project_root_path=PROJECT_ROOT, local_build=True),
        build_spec=DockerFileBuild(
            dockerfile_path="<DOCKERFILE_PATH>",    # ← ask user (e.g., "./Dockerfile")
            build_context_path="<BUILD_CONTEXT>",   # ← ask user (e.g., "./")
            # build_args={"<ARG_NAME>": "<value>"},  # ← ask user if needed
            # build_secrets={"<SECRET_NAME>": "<value>"},  # ← ask user if needed
        ),
    ),
    # Option B: Build from Git repo (uncomment to use instead of Option A)
    # image=Build(
    #     build_source=GitSource(
    #         repo_url="<REPO_URL>",                 # ← ask user
    #         branch_name="<BRANCH>",                # ← ask user (or use ref="<COMMIT_SHA>")
    #     ),
    #     build_spec=DockerFileBuild(
    #         dockerfile_path="<DOCKERFILE_PATH>",   # ← ask user
    #         build_context_path="<BUILD_CONTEXT>",  # ← ask user
    #     ),
    # ),
    # Option C: Pre-built Docker image (uncomment to use instead of Option A)
    # image=Image(
    #     image_uri="<IMAGE_URI>",                   # ← ask user (e.g., "registry/image:tag")
    #     command="<ENTRYPOINT_COMMAND>",             # ← ask user
    # ),
    resources=Resources(
        cpu_request=<CPU_REQUEST>,                   # ← ask user (e.g., 0.2)
        cpu_limit=<CPU_LIMIT>,                       # ← ask user (e.g., 0.5)
        memory_request=<MEMORY_REQUEST>,             # ← ask user, in MB (e.g., 200)
        memory_limit=<MEMORY_LIMIT>,                 # ← ask user, in MB (e.g., 500)
        ephemeral_storage_request=<STORAGE_REQUEST>, # ← ask user, in MB (e.g., 1000)
        ephemeral_storage_limit=<STORAGE_LIMIT>,     # ← ask user, in MB (e.g., 2000)
        # devices=[NvidiaGPU(name=GPUType.<GPU_TYPE>, count=<COUNT>)],  # ← ask user if GPU needed
        # node=NodeSelector(capacity_type="<CAPACITY_TYPE>"),  # ← ask user: "any" | "spot" | "on_demand" | "spot_fallback_on_demand"
    ),
    ports=[
        Port(
            port=<PORT>,                             # ← ask user (e.g., 8000)
            protocol="<PROTOCOL>",                   # ← ask user: "TCP" or "HTTP"
            expose=<EXPOSE>,                         # ← ask user: True/False
            app_protocol="http",
        ),
    ],
    replicas=Replicas(
        min=<MIN_REPLICAS>,                          # ← ask user (0 = scale-to-zero)
        max=<MAX_REPLICAS>,                          # ← ask user
    ),
    sidecar=SidecarPattern(
        destination_url="http://0.0.0.0:<PORT>/<ENDPOINT_PATH>",  # ← ask user: port + endpoint path
    ),
    worker_config_concurrent_workers=<CONCURRENT_WORKERS>,  # ← ask user (e.g., 1)
    input_queue=SQSQueueConfig(
        queue_url="<QUEUE_URL>",                     # ← ask user
        aws_access_key_id=os.environ.get("AWS_ACCESS_KEY_ID", ""),
        aws_secret_access_key=os.environ.get("AWS_SECRET_ACCESS_KEY", ""),
        aws_region="<REGION>",                       # ← ask user (e.g., "us-east-1")
        visibility_timeout=<VISIBILITY_TIMEOUT>,     # ← ask user, in seconds (e.g., 30)
    ),
    # output_queue=SQSQueueConfig(...)               # ← ask user if output queue is needed
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

**Every `<PLACEHOLDER>` MUST be replaced with a user-confirmed value. Never assume defaults.**
