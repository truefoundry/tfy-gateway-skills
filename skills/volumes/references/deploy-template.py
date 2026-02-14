"""Minimal deploy.py template for TrueFoundry.

Copy to your project root and adapt: name, port, Dockerfile path, resources.

Version-aware: Prints SDK version at startup. If deployment fails due to
SDK incompatibilities, check references/sdk-version-map.md for version-
specific patterns and breaking changes.

Requires: pip install truefoundry python-dotenv
Env: TFY_BASE_URL, TFY_API_KEY, TFY_WORKSPACE_FQN (required; never auto-picked).
"""
import os
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent / ".env")
except ImportError:
    pass

# Compat shim: SDK < 0.5.0 reads TFY_HOST; newer versions read TFY_BASE_URL.
# This ensures both are set regardless of SDK version. See sdk-version-map.md.
if os.environ.get("TFY_BASE_URL") and not os.environ.get("TFY_HOST"):
    os.environ["TFY_HOST"] = os.environ["TFY_BASE_URL"].strip().rstrip("/")

from truefoundry.deploy import (
    Build,
    DockerFileBuild,
    LocalSource,
    Port,
    Resources,
    Service,
    # Env,  # uncomment if using typed env vars
    # SecretMount,  # uncomment if using TrueFoundry secret groups
)

import truefoundry
print(f"TrueFoundry SDK version: {truefoundry.__version__}")

PROJECT_ROOT = str(Path(__file__).resolve().parent)
if not Path(PROJECT_ROOT).exists():
    raise SystemExit(f"Project root not found: {PROJECT_ROOT}")

service = Service(
    name="my-app",                              # ← change
    image=Build(
        build_source=LocalSource(project_root_path=PROJECT_ROOT, local_build=True),
        build_spec=DockerFileBuild(
            dockerfile_path="Dockerfile",       # ← change if needed
            build_context_path=".",
        ),
    ),
    resources=Resources(
        cpu_request=0.25, cpu_limit=0.5,
        memory_request=256, memory_limit=512,
        ephemeral_storage_request=100, ephemeral_storage_limit=200,
    ),
    ports=[
        Port(port=8000, protocol="TCP",         # ← change port
             # Public URL: set expose=True + host matching a cluster base domain.
             # Get base domains: GET /api/svc/v1/clusters/{cluster_id} → base_domains
             # Host convention: {service}-{workspace}.{base_domain}
             # Example: "my-app-dev-ws.ml.tfy-eo.truefoundry.cloud"
             # Internal only: expose=False, no host (default).
             expose=bool(os.environ.get("TFY_DEPLOY_HOST")),
             host=os.environ.get("TFY_DEPLOY_HOST") or None,
             app_protocol="http"),
    ],
    # Environment variables (uncomment and adapt as needed):
    # env={
    #     # Plain environment variables:
    #     "DATABASE_URL": "postgresql://localhost:5432/mydb",
    #     "API_KEY": "your-api-key-here",
    #     "LOG_LEVEL": "info",
    #
    #     # Secret references from TrueFoundry secret groups:
    #     # Pattern: SecretMount(secret_fqn="secret-group-fqn:secret-key-name")
    #     # "DB_PASSWORD": SecretMount(secret_fqn="workspace:my-secrets:DB_PASSWORD"),
    #     # "API_SECRET": SecretMount(secret_fqn="workspace:my-secrets:API_SECRET"),
    # },
    replicas=1,
)

if __name__ == "__main__":
    workspace_fqn = (os.environ.get("TFY_WORKSPACE_FQN") or "").strip()
    if not workspace_fqn:
        raise SystemExit(
            "TFY_WORKSPACE_FQN is required. "
            "Get it from the TrueFoundry dashboard or tfy_workspaces_list. "
            "Do not auto-pick a workspace."
        )
    service.deploy(workspace_fqn=workspace_fqn, wait=False)
    print("Deployment submitted. Check the TrueFoundry dashboard for status and URL.")
