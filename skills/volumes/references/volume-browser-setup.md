# Volume Browser Configuration and Access

TrueFoundry provides an optional Volume Browser -- a web-based file manager UI for browsing, uploading, downloading, and managing files inside a volume without SSH access.

## Table of Contents

- [Configuration Fields](#configuration-fields)
- [Setting Up Volume Browser](#setting-up-volume-browser)
- [Accessing Volume Browser](#accessing-volume-browser)

## Configuration Fields

The `volume_browser` object is optional on the volume manifest. Omit it entirely to disable.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `username` | string | No | Login username for the browser UI (defaults to `admin`) |
| `password_secret_fqn` | string | No | FQN of a TrueFoundry secret containing the browser password. Create the secret first using the `secrets` skill. Format: `cluster:workspace:secret-name` |
| `endpoint` | object | **Yes** (if volume_browser is set) | Public endpoint where the browser will be served |
| `endpoint.host` | string | **Yes** | Hostname (e.g. the cluster's base domain). Get available hosts from the cluster details. |
| `endpoint.path` | string | No | URL path prefix (e.g. `/my-volume/`). Defaults to `/` |
| `service_account` | string | No | Kubernetes ServiceAccount for the browser pod. Defaults to `default` |

## Setting Up Volume Browser

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

3. **Include `volume_browser` in the volume manifest** -- see the main volumes SKILL.md for API examples.

## Accessing Volume Browser

Once enabled, the Volume Browser is accessible at `https://{endpoint.host}{endpoint.path}`. Users log in with the configured username and password.
