# Deploy Examples

YAML manifest examples for each deployment option. Use `tfy apply -f tfy-manifest.yaml` to deploy.

## Common Setup

```bash
# Check CLI is available
tfy --version

# If not installed
pip install truefoundry
```

For REST API fallback, see `cli-fallback.md`.

## Option A: Pre-built Image

If the user already has a Docker image:

1. Confirm image URI, name, port, resources (use Step 2 analysis from SKILL.md)
2. Write manifest:

```yaml
# tfy-manifest.yaml
name: my-service
type: service
image:
  type: image
  image_uri: docker.io/myorg/my-api:v1.0
ports:
  - port: 8000
    protocol: TCP
    expose: true
    host: my-service-ws.ml.your-org.truefoundry.cloud
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
env:
  LOG_LEVEL: info
replicas: 1
workspace_fqn: cluster-id:workspace-name
```

3. Deploy:
```bash
tfy apply -f tfy-manifest.yaml
```

4. Poll status + report URL (see "After Deploy" section in SKILL.md)

## Option B: Git Repo + Dockerfile (Remote Build)

If the user's code is in Git with a Dockerfile:

1. Confirm Git repo URL, branch, Dockerfile path, name, port, resources
2. Write manifest:

```yaml
# tfy-manifest.yaml
name: my-service
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: https://github.com/user/repo
    branch_name: main
  build_spec:
    type: dockerfile
    dockerfile_path: Dockerfile
    build_context_path: "."
ports:
  - port: 8000
    protocol: TCP
    expose: true
    host: my-service-ws.ml.your-org.truefoundry.cloud
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas: 1
workspace_fqn: cluster-id:workspace-name
```

3. Deploy:
```bash
tfy apply -f tfy-manifest.yaml
```

4. Poll status + report URL

## Option C: Git Repo + PythonBuild (No Dockerfile)

If the user has Python code in Git but no Dockerfile:

1. Detect Python version, requirements path, entry command
2. Write manifest:

```yaml
# tfy-manifest.yaml
name: my-service
type: service
image:
  type: build
  build_source:
    type: git
    repo_url: https://github.com/user/repo
    branch_name: main
  build_spec:
    type: tfy-python-buildpack
    build_context_path: ./
    command: uvicorn main:app --host 0.0.0.0 --port 8000
    python_version: "3.10"
    python_dependencies:
      type: pip
      requirements_path: requirements.txt
ports:
  - port: 8000
    protocol: TCP
    expose: true
    host: my-service-ws.ml.your-org.truefoundry.cloud
    app_protocol: http
resources:
  cpu_request: 0.5
  cpu_limit: 1
  memory_request: 512
  memory_limit: 1024
  ephemeral_storage_request: 1000
  ephemeral_storage_limit: 2000
replicas: 1
workspace_fqn: cluster-id:workspace-name
```

3. Deploy:
```bash
tfy apply -f tfy-manifest.yaml
```

## Option D: Local Code + Docker Build

If code isn't in Git, but Docker is available:

1. Build image locally:
   ```bash
   docker build -t {registry}/{name}:{tag} .
   ```
2. Push:
   ```bash
   docker push {registry}/{name}:{tag}
   ```
3. Continue with Option A using the pushed image URI

Note: Ask the user which registry to use (Docker Hub, GHCR, or their org's registry).

## REST API Fallback

If `tfy` CLI is not available, convert the YAML manifest to JSON and use `tfy-api.sh`:

```bash
TFY_API_SH=~/.claude/skills/truefoundry-deploy/scripts/tfy-api.sh

# Step 1: Get Workspace ID
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"
# Extract the `id` field -- this is the `workspaceId` for the deploy call.

# Step 2: Deploy (JSON body)
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "my-service",
    "type": "service",
    "image": {
      "type": "image",
      "image_uri": "docker.io/myorg/my-api:v1.0"
    },
    "ports": [{"port": 8000, "protocol": "TCP", "expose": true,
               "host": "my-service-ws.ml.your-org.truefoundry.cloud",
               "app_protocol": "http"}],
    "resources": {
      "cpu_request": 0.5, "cpu_limit": 1,
      "memory_request": 512, "memory_limit": 1024,
      "ephemeral_storage_request": 1000, "ephemeral_storage_limit": 2000
    },
    "env": {"LOG_LEVEL": "info"},
    "replicas": 1,
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}'
```
