# Deploy Error Handling

Common deployment errors and how to resolve them.

## CLI Errors

### tfy: command not found

```
The TrueFoundry CLI is not installed.
Install it with: pip install truefoundry
Then verify: tfy --version
```

### tfy apply validation errors

```
YAML manifest validation failed. Check:
- Required fields are present: name, type, image, resources, workspace_fqn
- YAML syntax is valid (proper indentation, no tabs)
- Field names match the schema (see references/manifest-schema.md)
- workspace_fqn format is correct: "cluster-id:workspace-name"
```

### tfy apply --dry-run shows unexpected diff

```
The diff shows changes you didn't expect. This usually means:
- An existing deployment has different values than your manifest
- Default values are being applied that differ from the current state
Review the diff carefully before applying.
```

## TFY_WORKSPACE_FQN Not Set

```
TFY_WORKSPACE_FQN is required. Get it from:
- TrueFoundry dashboard -> Workspaces
- Or run: tfy_workspaces_list (if tool server is available)
Do not auto-pick a workspace.
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

## Build Failed

```
Build failed on TrueFoundry. Check the dashboard for build logs.
Common issues:
- Missing dependencies in Dockerfile
- Wrong port configuration
- Dockerfile CMD not matching the app's start command
```

## No Dockerfile

```
No Dockerfile found. Options:
1. Create a Dockerfile for your app
2. Use PythonBuild in the manifest (no Dockerfile needed):
   image:
     type: build
     build_source:
       type: git
       repo_url: https://github.com/user/repo
       branch_name: main
     build_spec:
       type: python
       python_version: "3.12"
       requirements_path: requirements.txt
       command: uvicorn main:app --host 0.0.0.0 --port 8000
```

## `tfy apply` Fails with "must match exactly one schema in oneOf"

```
This error occurs when using `tfy apply` with a build_source (git or local).
`tfy apply` only supports pre-built images (image.type: image).

Fix: Use `tfy deploy -f truefoundry.yaml --no-wait` for source-based deployments.
This is the most common deploy skill mistake — always check the image type before
choosing the command.
```

## `tfy apply` Fails with Missing `ref` Field

```
If git build_source is rejected for missing a `ref` field, this is another reason
to prefer `tfy deploy -f` for source-based deployments. `tfy deploy` handles
git refs automatically. If you must use `tfy apply`, add a `ref` field to
build_source with the commit SHA or tag.
```

## Cluster API Returns 403 Forbidden

```
The user's API key does not have permission to access the cluster API.
Fallback steps:
1. Check .env for TFY_CLUSTER_FQN
2. List existing apps in the workspace and extract domain from ports[].host
3. Ask the user for the base domain directly
4. For internal-only services, skip domain discovery (set expose: false)
See references/cluster-discovery.md for details.
```

## Replicas Format Rejected

```
If `replicas: { min: N, max: M }` is rejected, try block-style YAML:

replicas:
  min: 2
  max: 5

Or fall back to a fixed integer:

replicas: 2

Some tfy CLI versions may not accept inline object notation for replicas.
```

## REST API Fallback Errors

### 401 Unauthorized

```
TFY_API_KEY is invalid or expired.
Check: echo $TFY_API_KEY (should be set)
Regenerate from TrueFoundry dashboard -> Settings -> API Keys
```

### 404 Workspace Not Found

```
The workspace FQN does not exist.
List available workspaces: GET /api/svc/v1/workspaces
```
