"""Deploy simple_server to TrueFoundry."""
import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")
except ImportError:
    pass

if os.environ.get("TFY_BASE_URL") and not os.environ.get("TFY_HOST"):
    os.environ["TFY_HOST"] = os.environ["TFY_BASE_URL"].strip().rstrip("/")

from truefoundry.deploy import (
    Build,
    DockerFileBuild,
    LocalSource,
    Port,
    Resources,
    Service,
)

PROJECT_ROOT = str(Path(__file__).resolve().parent)

service = Service(
    name="simple-server",
    image=Build(
        build_source=LocalSource(project_root_path=PROJECT_ROOT, local_build=True),
        build_spec=DockerFileBuild(
            dockerfile_path="Dockerfile",
            build_context_path=".",
        ),
    ),
    resources=Resources(
        cpu_request=0.25, cpu_limit=0.5,
        memory_request=256, memory_limit=512,
        ephemeral_storage_request=100, ephemeral_storage_limit=200,
    ),
    ports=[
        Port(port=8000, protocol="TCP", expose=True,
             host="simple-server-sai-ws.ml.tfy-eo.truefoundry.cloud",
             app_protocol="http"),
    ],
    replicas=1,
)

if __name__ == "__main__":
    workspace_fqn = "tfy-ea-dev-eo-az:sai-ws"
    service.deploy(workspace_fqn=workspace_fqn, wait=False)
    print("Deployment submitted. Check the TrueFoundry dashboard for status and URL.")
