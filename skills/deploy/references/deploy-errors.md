# Deploy Error Handling

Common deployment errors and how to resolve them.

## TFY_WORKSPACE_FQN Not Set

```
TFY_WORKSPACE_FQN is required. Get it from:
- TrueFoundry dashboard -> Workspaces
- Or run: tfy_workspaces_list (if MCP server is available)
Do not auto-pick a workspace.
```

## SDK Not Installed (SDK path only)

```
Install the TrueFoundry SDK:
  pip install truefoundry python-dotenv

If this fails on Python 3.13+, switch to REST API deployment (Path 1).
```

## Python Version Incompatible (SDK path only)

```
TrueFoundry SDK requires Python 3.10-3.12. Current: X.Y
Options:
  1. Use REST API deployment (recommended) -- works with any Python
  2. Create a compatible venv: python3.12 -m venv .venv-deploy && source .venv-deploy/bin/activate
```

## Host Not Configured in Cluster

```
"Provided host is not configured in cluster"
The host you specified doesn't match any base_domains on the cluster.
Fix: Look up cluster base domains:
  GET /api/svc/v1/clusters/CLUSTER_ID -> base_domains
Use the wildcard domain (e.g., *.ml.your-org.truefoundry.cloud)
and construct: {service}-{workspace}.{base_domain}
```

## Git Build Failed

```
The remote build from Git failed. Check:
- Git repo URL is accessible (public or credentials configured in TrueFoundry)
- Branch/ref exists
- Dockerfile path is correct relative to build context
- Check build logs in TrueFoundry dashboard
```

## Build Failed (SDK path)

```
Build failed on TrueFoundry. Check the dashboard for build logs.
Common issues:
- Missing dependencies in Dockerfile
- Wrong port configuration
- Dockerfile CMD not matching the app's start command
```

## No Dockerfile (SDK path)

```
No Dockerfile found. Create one for your app first.
For a Python app: FROM python:3.12-slim, COPY, pip install, CMD.
For Node.js: FROM node:20-slim, COPY, npm install, CMD.
Or switch to REST API path with PythonBuild (no Dockerfile needed).
```
