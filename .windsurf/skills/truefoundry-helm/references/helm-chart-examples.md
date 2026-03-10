# Helm Chart Example Configurations

**Note:** All examples below use placeholder registry URLs (`oci://YOUR_REGISTRY/YOUR_CHART`). Replace these with your actual chart registry URL. Ask the user for the chart source — do not assume a specific registry.

All examples use `oci-repo`. You can also use `helm-repo` or `git-helm-repo`.

## Redis (Cache)

```json
{
  "manifest": {
    "name": "redis-cache",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "CHART_VERSION",
      "oci_chart_url": "oci://YOUR_REGISTRY/redis"
    },
    "values": {
      "auth": {
        "enabled": true,
        "password": "STRONG_PASSWORD"
      },
      "master": {
        "persistence": {
          "enabled": true,
          "size": "8Gi"
        },
        "resources": {
          "requests": {"cpu": "250m", "memory": "256Mi"},
          "limits": {"cpu": "1", "memory": "1Gi"}
        }
      },
      "replica": {
        "replicaCount": 3
      }
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

## MongoDB

```json
{
  "manifest": {
    "name": "mongodb",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "CHART_VERSION",
      "oci_chart_url": "oci://YOUR_REGISTRY/mongodb"
    },
    "values": {
      "auth": {
        "rootPassword": "STRONG_PASSWORD",
        "databases": ["myapp"],
        "usernames": ["appuser"],
        "passwords": ["USER_PASSWORD"]
      },
      "persistence": {
        "enabled": true,
        "size": "20Gi"
      },
      "resources": {
        "requests": {"cpu": "1", "memory": "1Gi"},
        "limits": {"cpu": "2", "memory": "2Gi"}
      },
      "replicaSet": {
        "enabled": true,
        "replicas": {"secondary": 2}
      }
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

## RabbitMQ (Message Queue)

```json
{
  "manifest": {
    "name": "rabbitmq",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "CHART_VERSION",
      "oci_chart_url": "oci://YOUR_REGISTRY/rabbitmq"
    },
    "values": {
      "auth": {
        "username": "admin",
        "password": "STRONG_PASSWORD"
      },
      "persistence": {
        "enabled": true,
        "size": "8Gi"
      },
      "resources": {
        "requests": {"cpu": "500m", "memory": "512Mi"},
        "limits": {"cpu": "2", "memory": "2Gi"}
      },
      "replicaCount": 3
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

## Qdrant (Vector Database)

```json
{
  "manifest": {
    "name": "qdrant",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "CHART_VERSION",
      "oci_chart_url": "oci://YOUR_REGISTRY/qdrant"
    },
    "values": {
      "persistence": {
        "enabled": true,
        "size": "20Gi"
      },
      "resources": {
        "requests": {"cpu": "1", "memory": "2Gi"},
        "limits": {"cpu": "2", "memory": "4Gi"}
      },
      "replicaCount": 1
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

## Elasticsearch (Search & Vector)

```json
{
  "manifest": {
    "name": "elasticsearch",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "CHART_VERSION",
      "oci_chart_url": "oci://YOUR_REGISTRY/elasticsearch"
    },
    "values": {
      "master": {
        "replicaCount": 1,
        "persistence": {
          "enabled": true,
          "size": "20Gi"
        },
        "resources": {
          "requests": {"cpu": "1", "memory": "2Gi"},
          "limits": {"cpu": "2", "memory": "4Gi"}
        }
      },
      "data": {
        "replicaCount": 2,
        "persistence": {
          "enabled": true,
          "size": "50Gi"
        },
        "resources": {
          "requests": {"cpu": "2", "memory": "4Gi"},
          "limits": {"cpu": "4", "memory": "8Gi"}
        }
      }
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

## Secrets Management

**Never hardcode passwords in manifests for production.** Use TrueFoundry secret groups:

1. Create secret group first (use `secrets` skill if available, or TrueFoundry dashboard)
2. Reference secrets in Helm values:

```json
{
  "values": {
    "auth": {
      "existingSecret": "SECRET_GROUP_NAME",
      "secretKeys": {
        "adminPassword": "POSTGRES_PASSWORD"
      }
    }
  }
}
```

Exact secret reference syntax varies by chart -- check the chart's `values.yaml` for `existingSecret` parameters.

## Environment-Specific Defaults

### Development
- **Replicas:** 1 (no high availability)
- **Resources:** Minimal (0.25 CPU, 256Mi RAM)
- **Storage:** Small (5-10Gi)
- **Persistence:** Can be disabled for ephemeral testing

### Staging
- **Replicas:** 2 (some redundancy)
- **Resources:** Medium (0.5-1 CPU, 512Mi-1Gi RAM)
- **Storage:** Moderate (10-20Gi)
- **Persistence:** Enabled

### Production
- **Replicas:** 3+ (high availability)
- **Resources:** Generous (1-4 CPU, 1-4Gi RAM)
- **Storage:** Large (20-100Gi+)
- **Persistence:** Always enabled with backups
- **Monitoring:** Enable Prometheus metrics if available
