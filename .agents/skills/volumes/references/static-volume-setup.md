# Static Volume Setup

For mounting pre-existing cloud storage as Kubernetes PersistentVolumes.

## Table of Contents

- [AWS EFS](#aws-efs)
- [AWS S3 (via CSI)](#aws-s3-via-csi)
- [GCP GCS (via GCS Fuse)](#gcp-gcs-via-gcs-fuse)
- [Azure Files / Blob](#azure-files--blob)
- [Important Notes](#important-notes)

## AWS EFS

1. Install the EFS CSI driver on the cluster
2. Create an EFS access point with proper permissions (UID:1000, GID:1000)
3. Create the PersistentVolume in Kubernetes referencing `file_system_id::access_point_id`
4. In TrueFoundry, create a volume with `type: existing` and the PV name

## AWS S3 (via CSI)

1. Configure IAM policies for S3 access
2. Create a PersistentVolume with the `s3.csi.aws.com` driver and bucket name in `volumeAttributes`
3. In TrueFoundry, create a volume with `type: existing` and the PV name

## GCP GCS (via GCS Fuse)

1. Enable the GCS Fuse CSI driver on the GKE cluster
2. Configure IAM service account with `storage.objectAdmin` role
3. Create a Kubernetes ServiceAccount with workload identity annotation
4. Create the PersistentVolume with `gcsfuse.csi.storage.gke.io` driver
5. In TrueFoundry, create a volume with `type: existing` and the PV name

## Azure Files / Blob

1. Ensure the Azure CSI drivers are installed on the AKS cluster
2. Create the Azure storage resource (File Share or Blob container)
3. Create the PersistentVolume referencing the Azure resource
4. In TrueFoundry, create a volume with `type: existing` and the PV name

## Important Notes

Static volume setup requires Kubernetes cluster access. If the user does not have cluster admin permissions, direct them to their platform administrator.
