# Volume Storage Classes by Cloud Provider

## Table of Contents

- [AWS](#aws)
- [GCP](#gcp)
- [Azure](#azure)
- [Discovering Available Storage Classes](#discovering-available-storage-classes)

## AWS

| Storage Class | Driver | Description |
|---------------|--------|-------------|
| `efs-sc` | `efs.csi.aws.com` | Elastic File System -- shared NFS, scales automatically |

## GCP

| Storage Class | Driver | Description |
|---------------|--------|-------------|
| `standard-rwx` | Filestore | Basic HDD Filestore -- cost-effective shared storage |
| `premium-rwx` | Filestore | Premium SSD Filestore -- higher IOPS |
| `enterprise-rwx` | Filestore | Enterprise-grade Filestore -- highest durability and performance |

## Azure

| Storage Class | Driver | Description |
|---------------|--------|-------------|
| `azurefile` | `file.csi.azure.com` | Azure Files -- standard tier |
| `azurefile-premium` | `file.csi.azure.com` | Azure Files -- premium SSD tier |
| `azureblob-nfs-premium` | `blob.csi.azure.com` | Azure Blob NFS -- premium |
| `azureblob-fuse-premium` | `blob.csi.azure.com` | Azure Blob FUSE -- premium |

## Discovering Available Storage Classes

To discover available storage classes on a cluster, see `cluster-discovery.md` or check the cluster details:

```bash
# Via Tool Call
tfy_clusters_list(cluster_id="CLUSTER_ID")

# Via Direct API
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```
