# TrueFoundry API Endpoints Reference

Base URL: `$TFY_BASE_URL` (e.g. `https://tfy-eo.truefoundry.cloud`)
Auth: `Authorization: Bearer $TFY_API_KEY`

## Applications
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/apps` | List applications (query: workspaceFqn, applicationName, clusterId) |
| GET | `/api/svc/v1/apps/{appId}` | Get application by ID |
| GET | `/api/svc/v1/apps/{appId}/deployments` | List deployments for an app |
| GET | `/api/svc/v1/apps/{appId}/deployments/{deploymentId}` | Get deployment details |
| PUT | `/api/svc/v1/apps` | Create/update application deployment (body: manifest + options) |

## Workspaces
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/workspaces` | List workspaces (query: clusterId, name, fqn) |
| GET | `/api/svc/v1/workspaces/{id}` | Get workspace by ID |

## Clusters
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/clusters` | List clusters |
| GET | `/api/svc/v1/clusters/{id}` | Get cluster |
| GET | `/api/svc/v1/clusters/{id}/is-connected` | Get cluster connection status |
| GET | `/api/svc/v1/clusters/{id}/get-addons` | List cluster addons |

## Secrets
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/secret-groups` | List secret groups |
| GET | `/api/svc/v1/secret-groups/{id}` | Get secret group |
| POST | `/api/svc/v1/secret-groups` | Create secret group |
| POST | `/api/svc/v1/secrets` | List secrets in a group (body: secretGroupId, limit, offset) |
| GET | `/api/svc/v1/secrets/{id}` | Get secret by ID |

## Jobs
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/jobs/{jobId}/runs` | List job runs (query: searchPrefix, sortBy) |
| GET | `/api/svc/v1/jobs/{jobId}/runs/{runName}` | Get a specific job run |

## Logs
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/logs` | Get logs (query: applicationId, startTs, endTs, searchString) |
| GET | `/api/svc/v1/logs/{workspaceId}/download` | Download logs |

## Prompts
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/ml/v1/prompts` | List prompts |
| GET | `/api/ml/v1/prompts/{id}` | Get prompt |
| GET | `/api/ml/v1/prompt-versions` | List prompt versions (query: prompt_id) |
| GET | `/api/ml/v1/prompt-versions/{id}` | Get prompt version |

## ML Repos
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/ml/v1/ml-repos` | List ML repos |
| GET | `/api/ml/v1/ml-repos/{id}` | Get ML repo |

## Personal Access Tokens
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/personal-access-tokens` | List PATs |
| POST | `/api/svc/v1/personal-access-tokens` | Create PAT |

## API Docs
- Full reference: `https://truefoundry.com/docs/api-reference`
- Generating API keys: `https://docs.truefoundry.com/docs/generating-truefoundry-api-keys`
