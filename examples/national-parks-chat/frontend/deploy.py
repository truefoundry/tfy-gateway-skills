import os
from dotenv import load_dotenv
load_dotenv()

from truefoundry.deploy import Service, Build, DockerFileBuild, LocalSource, Port, Resources

service = Service(
    name="parks-frontend",
    image=Build(
        build_source=LocalSource(local_build=False),
        build_spec=DockerFileBuild(dockerfile_path="Dockerfile"),
    ),
    ports=[
        Port(
            port=3000,
            protocol="TCP",
            expose=True,
            host="parks-app-sai-ws.ml.tfy-eo.truefoundry.cloud",
            app_protocol="http",
        )
    ],
    resources=Resources(
        cpu_request=0.25, cpu_limit=0.5,
        memory_request=256, memory_limit=512,
        ephemeral_storage_request=1000, ephemeral_storage_limit=2000,
    ),
    replicas=1,
    env={
        "NEXT_PUBLIC_API_URL": "https://parks-api-sai-ws.ml.tfy-eo.truefoundry.cloud",
    },
)

service.deploy(workspace_fqn=os.environ.get("TFY_WORKSPACE_FQN", "tfy-ea-dev-eo-az:sai-ws"))
