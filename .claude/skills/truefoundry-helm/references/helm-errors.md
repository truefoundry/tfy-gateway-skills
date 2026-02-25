# Helm Deployment Error Handling

## TFY_WORKSPACE_FQN Not Set
```
TFY_WORKSPACE_FQN is required. Get it from:
- TrueFoundry dashboard → Workspaces
- Or use: workspaces skill to list available workspaces
Do not auto-pick a workspace.
```

## Invalid Workspace ID
```
Could not find workspace ID for FQN: {fqn}
Use the workspaces skill to verify the workspace exists and get its ID.
```

## Chart Not Found
```
Helm chart not found in registry.
Check:
- Chart name is correct (e.g., "postgresql", not "postgres")
- Registry URL is reachable
- Version exists (omit version to use latest)
```

## Values Validation Failed
```
Helm values failed validation.
Common issues:
- Missing required fields (auth, passwords, etc.)
- Invalid resource format (use "1" or "1000m" for CPU, "1Gi" for memory)
- Invalid storage size format (use "10Gi", not "10GB")

Check the chart's values.yaml for required fields:
https://artifacthub.io/packages/helm/{repo}/{chart}
```

## Insufficient Resources
```
Deployment failed: Insufficient resources in cluster.
Requested: {cpu} CPU, {memory} RAM
Available: {available}

Options:
- Reduce resource requests in values
- Use a larger cluster node pool
- Remove resource limits (not recommended for prod)
```

## PVC Binding Failed
```
Persistent volume claim failed to bind.
Check:
- Storage class exists in the cluster (use: kubectl get storageclass)
- Requested size is within quota limits
- Cluster has available persistent volume provisioner
```

## Connection Issues After Deploy
```
Chart deployed but connection failed.
Check:
1. Application status: Use `applications` skill
2. Pod logs: Use `logs` skill with the application ID
3. Service DNS: {name}-{chart}.{namespace}.svc.cluster.local
4. Port: Check chart documentation for default port
5. Credentials: Verify password/secret configuration
```
