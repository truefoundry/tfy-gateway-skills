---
name: volumes
description: This skill should be used when the user asks "create a volume", "list volumes", "persistent storage", "mount a volume", "attach storage", "shared storage for pods", "add disk to service", "volume sizing", "storage class options", "expand volume", "attach PVC", "mount shared data", or wants to manage TrueFoundry persistent volumes. NOT for blob storage (S3/GCS) questions.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

<objective>

# Volumes

Create and manage persistent volumes on TrueFoundry. Volumes provide shared, low-latency disk storage that persists across container restarts and can be mounted by multiple pods.

## When to Use

- User asks "create a volume", "add persistent storage"
- User asks "list volumes", "show my volumes"
- User wants to share data across pods or replicas (training data, model weights)
- User needs checkpointing for ML training jobs
- User wants to mount storage to a service or job
- User asks about storage classes or volume types
- User wants to attach pre-existing Kubernetes PersistentVolumes (EFS, GCS, S3)

## When NOT to Use

- User needs large archival storage or global access -> suggest blob storage (S3/GCS) instead
- User wants ephemeral scratch space -> use `ephemeral_storage` in resource config
- User wants to deploy an app -> use `deploy` skill
- User wants to manage secrets -> use `secrets` skill

</objective>

<context>

## Volumes vs Blob Storage

Help the user choose the right storage type:

| Aspect | Volumes | Blob Storage (S3/GCS) |
|--------|---------|----------------------|
| **Access method** | Standard file system APIs (open, read, write) | SDK clients (boto3, gcsfs) |
| **Speed** | Faster (local-disk latency) | Slower (network round-trips) |
| **Durability** | High | Extremely high (11 nines) |
| **Cost** | Higher per GB | Lower per GB |
| **Scope** | Region/cluster limited | Global access |
| **Best for** | Shared model weights, training checkpoints, low-latency reads | Large archives, datasets accessed infrequently, cross-region data |

**Choose volumes when:**
- Multiple pods need concurrent file system access to the same data
- You need file system semantics (locking, renaming, directory listing)
- Low-latency access to frequently-read data (model weights, config files)
- ML training checkpointing where write speed matters

**Choose blob storage when:**
- Data is larger than a few hundred GB
- Global or cross-region access is needed
- Data is written once and read occasionally
- Cost is the primary concern

**Warning:** Do not write to the same file path from multiple pods simultaneously -- this can cause data corruption. Coordinate writes across pods or use separate paths.

## Prerequisites

**Always verify before deploying:**

1. **Credentials** -- `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** -- `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.** Volumes are workspace-scoped: a volume created in one workspace can only be used by applications in that same workspace.
3. **Cluster storage class** -- The target cluster must have a storage provisioner configured for the desired storage class.

For credential check commands and .env setup, see `references/prerequisites.md`.

## Volume Types

### Dynamic Volumes (Create New)

TrueFoundry provisions a new Kubernetes PersistentVolumeClaim (PVC). You specify size and storage class; the cluster allocator handles the rest.

**Key properties:**
- Size is expandable after creation but **cannot be reduced**
- Access mode is `ReadWriteMany` (multiple pods can mount simultaneously)
- Reclaim policy is `Retain` (data persists even if the volume resource is deleted from TrueFoundry)

### Static Volumes (Use Existing)

Mount a pre-existing Kubernetes PersistentVolume by name. Use this for:
- **AWS EFS** -- Elastic File System via `efs.csi.aws.com` driver
- **AWS S3** -- S3 buckets via `s3.csi.aws.com` driver
- **GCP Filestore / GCS** -- via `gcsfuse.csi.storage.gke.io` driver
- **Azure Files / Azure Blob** -- via `file.csi.azure.com` or `blob.csi.azure.com` drivers

Static volumes require the PersistentVolume to already exist in the Kubernetes cluster. See the "Static Volume Setup" section below.

## Storage Classes by Cloud Provider

Present only the storage classes available on the user's cluster. These are the common defaults:

### AWS
| Storage Class | Driver | Description |
|---------------|--------|-------------|
| `efs-sc` | `efs.csi.aws.com` | Elastic File System -- shared NFS, scales automatically |

### GCP
| Storage Class | Driver | Description |
|---------------|--------|-------------|
| `standard-rwx` | Filestore | Basic HDD Filestore -- cost-effective shared storage |
| `premium-rwx` | Filestore | Premium SSD Filestore -- higher IOPS |
| `enterprise-rwx` | Filestore | Enterprise-grade Filestore -- highest durability and performance |

### Azure
| Storage Class | Driver | Description |
|---------------|--------|-------------|
| `azurefile` | `file.csi.azure.com` | Azure Files -- standard tier |
| `azurefile-premium` | `file.csi.azure.com` | Azure Files -- premium SSD tier |
| `azureblob-nfs-premium` | `blob.csi.azure.com` | Azure Blob NFS -- premium |
| `azureblob-fuse-premium` | `blob.csi.azure.com` | Azure Blob FUSE -- premium |

**To discover available storage classes on a cluster**, see `references/cluster-discovery.md` or check the cluster details:

```bash
# Via MCP
tfy_clusters_list(cluster_id="CLUSTER_ID")

# Via Direct API
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

</context>

<instructions>

## Creating a Volume

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

### Before Creating

**ALWAYS ask the user these questions in order:**

1. **Volume type** -- "Do you want to create a new volume or use an existing Kubernetes PersistentVolume?"
   - **Create new** → proceed with dynamic volume questions below
   - **Use existing** → ask for the PersistentVolume name in Kubernetes, then skip to workspace
2. **Volume name** -- What should the volume be called?
3. **Size** -- How much storage? (integer in GB, e.g. `50`). Cannot be reduced later.
4. **Storage class** -- Which storage class? Present available options from the cluster.
5. **Workspace** -- Which workspace? Volumes are workspace-scoped.
6. **Volume Browser** -- "Do you want to enable Volume Browser? It provides a web UI to browse and manage files in your volume without SSH." (Optional)
   - If yes, ask for:
     - **Endpoint host** -- The hostname where the browser will be accessible (e.g. `my-cluster.example.truefoundry.com`). Present available hosts from the cluster's base domain.
     - **Endpoint path** -- URL path prefix (optional, defaults to `/`)
     - **Username** -- Login username for the browser (optional, defaults to `admin`)
     - **Password secret** -- FQN of a TrueFoundry secret containing the browser password. If user doesn't have one, help them create it using the `secrets` skill first.

Present a summary and ask for confirmation:

```
Volume to create:
  Type:          Create new (dynamic)
  Name:          training-data
  Size:          100 GB
  Storage class: efs-sc
  Workspace:     my-cluster:my-workspace
  Volume Browser: Enabled
    Endpoint:    https://my-cluster.example.truefoundry.com/training-data/
    Username:    admin
    Password:    (secret: my-cluster:my-workspace:vol-browser-pw)

Note: Size can be expanded later but not reduced.
Proceed?
```

For volumes without Volume Browser:
```
Volume to create:
  Type:          Create new (dynamic)
  Name:          training-data
  Size:          100 GB
  Storage class: efs-sc
  Workspace:     my-cluster:my-workspace
  Volume Browser: Disabled

Note: Size can be expanded later but not reduced.
Proceed?
```

### Via MCP

**Create new volume (without Volume Browser):**

```
tfy_applications_create_deployment(
    manifest={
        "type": "volume",
        "name": "my-volume",
        "config": {
            "type": "dynamic",
            "size": 100,
            "storage_class": "efs-sc"
        }
    },
    options={"workspace_id": "ws-id-here"}
)
```

**Create new volume (with Volume Browser):**

```
tfy_applications_create_deployment(
    manifest={
        "type": "volume",
        "name": "my-volume",
        "config": {
            "type": "dynamic",
            "size": 100,
            "storage_class": "efs-sc"
        },
        "volume_browser": {
            "username": "admin",
            "password_secret_fqn": "my-cluster:my-workspace:vol-browser-pw",
            "endpoint": {
                "host": "my-cluster.example.truefoundry.com",
                "path": "/my-volume/"
            }
        }
    },
    options={"workspace_id": "ws-id-here"}
)
```

**Use existing PersistentVolume:**

```
tfy_applications_create_deployment(
    manifest={
        "type": "volume",
        "name": "my-existing-vol",
        "config": {
            "type": "static",
            "persistent_volume_name": "pv-name-in-k8s"
        }
    },
    options={"workspace_id": "ws-id-here"}
)
```

**Note:** This requires human approval (HITL) when using MCP.

### Via Direct API

**Create new volume (without Volume Browser):**

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "type": "volume",
    "name": "my-volume",
    "config": {
      "type": "dynamic",
      "size": 100,
      "storage_class": "efs-sc"
    }
  },
  "workspaceId": "ws-id-here"
}'
```

**Create new volume (with Volume Browser):**

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "type": "volume",
    "name": "my-volume",
    "config": {
      "type": "dynamic",
      "size": 100,
      "storage_class": "efs-sc"
    },
    "volume_browser": {
      "username": "admin",
      "password_secret_fqn": "my-cluster:my-workspace:vol-browser-pw",
      "endpoint": {
        "host": "my-cluster.example.truefoundry.com",
        "path": "/my-volume/"
      }
    }
  },
  "workspaceId": "ws-id-here"
}'
```

### Using an Existing Kubernetes PersistentVolume

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "type": "volume",
    "name": "my-existing-vol",
    "config": {
      "type": "static",
      "persistent_volume_name": "pv-name-in-k8s"
    }
  },
  "workspaceId": "ws-id-here"
}'
```

## Listing Volumes

### Via MCP

```
tfy_applications_list(filters={"workspace_fqn": "my-cluster:my-workspace", "application_type": "volume"})
```

### Via Direct API

```bash
# List volumes in a workspace
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=my-cluster:my-workspace&applicationType=volume'

# Get a specific volume by ID
$TFY_API_SH GET /api/svc/v1/apps/VOLUME_APP_ID
```

### Presenting Volumes

```
Volumes in my-cluster:my-workspace:
| Name           | Size   | Storage Class | Status   | Created            |
|----------------|--------|---------------|----------|--------------------|
| training-data  | 100Gi  | efs-sc        | RUNNING  | 2026-02-10 14:30   |
| model-cache    | 50Gi   | premium-rwx   | RUNNING  | 2026-02-08 09:15   |
```

## Attaching Volumes to Services and Jobs

Volumes are mounted into containers at a specified path. The volume must be in the same workspace as the application.

### SDK (in deploy.py)

```python
from truefoundry.deploy import Service, VolumeMount

service = Service(
    name="my-service",
    # ... image, ports, resources ...
    mounts=[
        VolumeMount(
            mount_path="/data",
            volume_fqn="my-cluster:my-workspace:my-volume",
        ),
    ],
)
```

### API Manifest (Service)

```json
{
  "manifest": {
    "kind": "Service",
    "name": "my-service",
    "image": {"type": "image", "image_uri": "my-image:latest"},
    "mounts": [
      {
        "type": "volume",
        "mount_path": "/data",
        "volume_fqn": "my-cluster:my-workspace:my-volume"
      }
    ],
    "resources": {
      "cpu_request": 0.5, "cpu_limit": 1.0,
      "memory_request": 512, "memory_limit": 1024
    }
  },
  "workspaceId": "ws-id-here"
}
```

### API Manifest (Job)

```json
{
  "manifest": {
    "kind": "Job",
    "name": "my-training-job",
    "image": {"type": "image", "image_uri": "my-training:latest"},
    "mounts": [
      {
        "type": "volume",
        "mount_path": "/data",
        "volume_fqn": "my-cluster:my-workspace:training-data"
      },
      {
        "type": "volume",
        "mount_path": "/checkpoints",
        "volume_fqn": "my-cluster:my-workspace:checkpoint-vol"
      }
    ],
    "resources": {
      "cpu_request": 4.0, "cpu_limit": 8.0,
      "memory_request": 16384, "memory_limit": 32768
    }
  },
  "workspaceId": "ws-id-here"
}
```

### Volume FQN Format

The volume FQN follows the pattern: `{cluster}:{workspace}:{volume-name}`

Example: `my-cluster:my-workspace:training-data`

## LLM Cache Volumes

For LLM deployments, TrueFoundry supports a `cache_volume` shorthand that creates a volume for model weight caching. This avoids re-downloading large models on every pod restart. See the `llm-deploy` skill for details.

```yaml
# In LLM deployment manifest
cache_volume:
  cache_size: 50
  storage_class: efs-sc
```

## Volume Sizing Guidelines

| Use Case | Recommended Size | Notes |
|----------|-----------------|-------|
| Small model cache (< 7B params) | 20-50 Gi | 2x the model size in FP16 |
| Large model cache (7B-70B params) | 50-200 Gi | 2x the model size; account for multiple formats |
| Shared training dataset | 50-500 Gi | Depends on dataset size; leave 20% headroom |
| Checkpointing | 20-100 Gi | Depends on checkpoint frequency and model size |
| General shared storage | 10-50 Gi | Start small, expand as needed |

**Sizing tips:**
- Always add 20% headroom above your expected data size
- Volume size can be expanded later but **never reduced** -- start conservatively if unsure
- For model caching, use 2x the model's disk size to account for download + extraction
- Monitor volume usage after deployment and expand proactively before hitting limits

## Static Volume Setup

For mounting pre-existing cloud storage as Kubernetes PersistentVolumes.

### AWS EFS

1. Install the EFS CSI driver on the cluster
2. Create an EFS access point with proper permissions (UID:1000, GID:1000)
3. Create the PersistentVolume in Kubernetes referencing `file_system_id::access_point_id`
4. In TrueFoundry, create a volume with `type: existing` and the PV name

### AWS S3 (via CSI)

1. Configure IAM policies for S3 access
2. Create a PersistentVolume with the `s3.csi.aws.com` driver and bucket name in `volumeAttributes`
3. In TrueFoundry, create a volume with `type: existing` and the PV name

### GCP GCS (via GCS Fuse)

1. Enable the GCS Fuse CSI driver on the GKE cluster
2. Configure IAM service account with `storage.objectAdmin` role
3. Create a Kubernetes ServiceAccount with workload identity annotation
4. Create the PersistentVolume with `gcsfuse.csi.storage.gke.io` driver
5. In TrueFoundry, create a volume with `type: existing` and the PV name

### Azure Files / Blob

1. Ensure the Azure CSI drivers are installed on the AKS cluster
2. Create the Azure storage resource (File Share or Blob container)
3. Create the PersistentVolume referencing the Azure resource
4. In TrueFoundry, create a volume with `type: existing` and the PV name

**Note:** Static volume setup requires Kubernetes cluster access. If the user does not have cluster admin permissions, direct them to their platform administrator.

## Volume Browser

TrueFoundry provides an optional Volume Browser -- a web-based file manager UI for browsing, uploading, downloading, and managing files inside a volume without SSH access.

### Volume Browser Configuration

The `volume_browser` object is optional on the volume manifest. Omit it entirely to disable.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `username` | string | No | Login username for the browser UI (defaults to `admin`) |
| `password_secret_fqn` | string | No | FQN of a TrueFoundry secret containing the browser password. Create the secret first using the `secrets` skill. Format: `cluster:workspace:secret-name` |
| `endpoint` | object | **Yes** (if volume_browser is set) | Public endpoint where the browser will be served |
| `endpoint.host` | string | **Yes** | Hostname (e.g. the cluster's base domain). Get available hosts from the cluster details. |
| `endpoint.path` | string | No | URL path prefix (e.g. `/my-volume/`). Defaults to `/` |
| `service_account` | string | No | Kubernetes ServiceAccount for the browser pod. Defaults to `default` |

### Setting Up Volume Browser

1. **Create a password secret** (if the user doesn't have one):
   - Use the `secrets` skill to create a secret containing the desired password
   - Note the secret FQN (e.g. `my-cluster:my-workspace:vol-browser-pw`)

2. **Get the cluster's base domain** for the endpoint host:
   ```bash
   # Via MCP
   tfy_clusters_list(cluster_id="CLUSTER_ID")

   # Via Direct API
   $TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
   ```
   Look for the cluster's base domain in the response (e.g. `my-cluster.example.truefoundry.com`).

3. **Include `volume_browser` in the volume manifest** -- see API examples above in "Creating a Volume".

### Volume Browser Access

Once enabled, the Volume Browser is accessible at `https://{endpoint.host}{endpoint.path}`. Users log in with the configured username and password.

</instructions>

<success_criteria>

- The agent asked "create new or use existing?" before proceeding
- The agent has confirmed volume name, size, storage class, and workspace with the user before creating
- The agent asked whether to enable Volume Browser and collected endpoint/password details if yes
- The volume was successfully created and is in RUNNING status
- The user can list all volumes in their target workspace
- The user can attach the volume to a service or job using the correct volume FQN
- The agent has advised on appropriate sizing based on the user's use case
- The user understands the difference between volumes and blob storage for their scenario

</success_criteria>

<references>

## Composability

- **Before deploying with volumes**: Use `workspaces` skill to get workspace FQN, then create the volume in the same workspace
- **With secrets skill**: Create a password secret before enabling Volume Browser (password_secret_fqn is required)
- **With deploy skill**: After creating a volume, add `VolumeMount` to the service's deploy.py to attach it
- **With llm-deploy skill**: Use `cache_volume` in LLM deployment manifests for model weight caching
- **With jobs skill**: Mount volumes to training jobs for checkpointing and shared data access
- **With applications skill**: List volumes alongside other application types to see what storage exists
- **After creating**: Use `applications` skill to verify the volume was created successfully

</references>

<troubleshooting>

## Error Handling

### Volume Not Found
```
Volume not found in workspace. Check:
- Volume name and workspace FQN are correct
- Volume was created in the same workspace as your application
- Use: GET /api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationType=volume
```

### Storage Class Not Available
```
Storage class not found on this cluster. Check available storage classes:
- GET /api/svc/v1/clusters/CLUSTER_ID
- Common classes: efs-sc (AWS), standard-rwx (GCP), azurefile (Azure)
- Ask your platform admin if no storage classes are configured.
```

### Volume Size Cannot Be Reduced
```
Volume size can only be increased, not decreased.
Current size: 100Gi. You requested: 50Gi.
To use less storage, create a new smaller volume and migrate data.
```

### Workspace Mismatch
```
Volume and application must be in the same workspace.
Volume workspace: my-cluster:ws-a
Application workspace: my-cluster:ws-b
Create the volume in the same workspace as your application, or redeploy the application to the volume's workspace.
```

### Permission Denied
```
Cannot access or create volumes. Check your API key permissions for this workspace.
```

### PersistentVolume Not Found (Static Volumes)
```
The Kubernetes PersistentVolume name you specified does not exist in the cluster.
Verify the PV exists: kubectl get pv <pv-name>
If you need to create it, contact your platform administrator.
```

### Data Corruption Warning
```
Multiple pods writing to the same file path can cause data corruption.
Ensure each pod writes to a unique sub-directory, or use a single-writer pattern.
Example: /data/pod-{POD_NAME}/ for per-pod directories.
```

</troubleshooting>
