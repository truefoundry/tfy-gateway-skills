import os
from dotenv import load_dotenv
load_dotenv()

from truefoundry.deploy import Service, Build, PythonBuild, LocalSource, Port, Resources

service = Service(
    name="parks-backend",
    image=Build(
        build_source=LocalSource(local_build=False),
        build_spec=PythonBuild(
            python_version="3.11",
            command="uvicorn main:app --host 0.0.0.0 --port 8000",
            requirements_path="requirements.txt",
        ),
    ),
    ports=[
        Port(
            port=8000,
            protocol="TCP",
            expose=True,
            host="parks-api-sai-ws.ml.tfy-eo.truefoundry.cloud",
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
        "REDIS_URL": "redis://:parksredis123@parks-redis-redis-master.sai-ws.svc.cluster.local:6379/0",
    },
)

service.deploy(workspace_fqn=os.environ.get("TFY_WORKSPACE_FQN", "tfy-ea-dev-eo-az:sai-ws"))
