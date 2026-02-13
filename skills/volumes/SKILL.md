---
name: volumes
description: This skill should be used when the user asks "create a volume", "list volumes", "persistent storage", "mount a volume", "attach storage", "shared storage for pods", or wants to manage TrueFoundry persistent volumes. NOT for blob storage (S3/GCS) questions.
allowed-tools: Bash(*/tfy-api.sh *)
---

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

1. **Credentials** -- `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** -- `TFY_WORKSPACE_FQN` is required. Volumes are workspace-scoped: a volume created in one workspace can only be used by applications in that same workspace. Never auto-pick. Ask the user if missing.
3. **Cluster storage class** -- The target cluster must have a storage provisioner configured for the desired storage class.

```bash
# Check credentials
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
echo "TFY_WORKSPACE_FQN: ${TFY_WORKSPACE_FQN:-(not set)}"
```

**If TFY_WORKSPACE_FQN is not set, STOP. Ask the user.** Suggest they use the `workspaces` skill or check the TrueFoundry dashboard.

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

**To discover available storage classes on a cluster**, check the cluster details:

```bash
# Via MCP
tfy_clusters_list(cluster_id="CLUSTER_ID")

# Via Direct API
TFY_API_SH=~/.claude/skills/truefoundry-volumes/scripts/tfy-api.sh
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

## Creating a Volume

When using direct API, use the **full path** to this skill's `scripts/tfy-api.sh`. The path depends on which agent is installed (e.g. `~/.claude/skills/truefoundry-volumes/scripts/tfy-api.sh` for Claude Code, `~/.cursor/skills/truefoundry-volumes/scripts/tfy-api.sh` for Cursor). In the examples below, replace `TFY_API_SH` with the full path.

### Before Creating

**ALWAYS confirm with the user before creating a volume:**

1. **Volume name** -- What should the volume be called?
2. **Size** -- How much storage? (in Gi, e.g. `50Gi`). Cannot be reduced later.
3. **Storage class** -- Which storage class? Present available options from the cluster.
4. **Workspace** -- Which workspace? Volumes are workspace-scoped.

Present a summary and ask for confirmation:

```
Volume to create:
  Name:          training-data
  Size:          100Gi
  Storage class: efs-sc
  Workspace:     tfy-ea-dev-eo-az:my-ws

Note: Size can be expanded later but not reduced.
Proceed?
```

### Via MCP

```
tfy_applications_create_deployment(
    manifest={
        "kind": "Volume",
        "name": "my-volume",
        "volume_config": {
            "type": "new",
            "size": "100Gi",
            "storage_class": "efs-sc"
        }
    },
    options={"workspace_id": "ws-id-here"}
)
```

**Note:** This requires human approval (HITL) when using MCP.

### Via Direct API

```bash
TFY_API_SH=~/.claude/skills/truefoundry-volumes/scripts/tfy-api.sh

# Create a new volume
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "kind": "Volume",
    "name": "my-volume",
    "volume_config": {
      "type": "new",
      "size": "100Gi",
      "storage_class": "efs-sc"
    }
  },
  "workspaceId": "ws-id-here"
}'
```

### Using an Existing Kubernetes PersistentVolume

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "kind": "Volume",
    "name": "my-existing-vol",
    "volume_config": {
      "type": "existing",
      "persistent_volume_name": "pv-name-in-k8s"
    }
  },
  "workspaceId": "ws-id-here"
}'
```

## Listing Volumes

### Via MCP

```
tfy_applications_list(filters={"workspace_fqn": "tfy-ea-dev-eo-az:my-ws", "application_type": "volume"})
```

### Via Direct API

```bash
TFY_API_SH=~/.claude/skills/truefoundry-volumes/scripts/tfy-api.sh

# List volumes in a workspace
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=tfy-ea-dev-eo-az:my-ws&applicationType=volume'

# Get a specific volume by ID
$TFY_API_SH GET /api/svc/v1/apps/VOLUME_APP_ID
```

### Presenting Volumes

```
Volumes in tfy-ea-dev-eo-az:my-ws:
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
            volume_fqn="tfy-ea-dev-eo-az:my-ws:my-volume",
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
        "volume_fqn": "tfy-ea-dev-eo-az:my-ws:my-volume"
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
        "volume_fqn": "tfy-ea-dev-eo-az:my-ws:training-data"
      },
      {
        "type": "volume",
        "mount_path": "/checkpoints",
        "volume_fqn": "tfy-ea-dev-eo-az:my-ws:checkpoint-vol"
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

Example: `tfy-ea-dev-eo-az:my-ws:training-data`

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

TrueFoundry provides an optional Volume Browser UI for managing files in a volume without SSH. When creating a volume, this can be enabled by setting a password-protected secret for access.

## Composability

- **Before deploying with volumes**: Use `workspaces` skill to get workspace FQN, then create the volume in the same workspace
- **With deploy skill**: After creating a volume, add `VolumeMount` to the service's deploy.py to attach it
- **With llm-deploy skill**: Use `cache_volume` in LLM deployment manifests for model weight caching
- **With jobs skill**: Mount volumes to training jobs for checkpointing and shared data access
- **With applications skill**: List volumes alongside other application types to see what storage exists
- **After creating**: Use `applications` skill to verify the volume was created successfully

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
Volume workspace: tfy-ea-dev-eo-az:ws-a
Application workspace: tfy-ea-dev-eo-az:ws-b
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
