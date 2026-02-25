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
