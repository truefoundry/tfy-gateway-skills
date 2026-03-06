# TrueFoundry API Endpoints Reference

Base URL: `$TFY_BASE_URL` (e.g. `https://your-org.truefoundry.cloud`)
Auth: `Authorization: Bearer $TFY_API_KEY`

## Applications
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/apps` | List applications (query: workspaceFqn, applicationName, clusterId). Returns `{"data": [{"id", "name", "status" (string), "url", "activeDeployment", "manifest"}], "pagination": {...}}` |
| GET | `/api/svc/v1/apps/{appId}` | Get application by ID. Returns single app object (same shape as `data[]` element above) |
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

## Provider Accounts
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/provider-accounts` | List provider accounts (query: type=secret-store for secret integrations) |

## Secrets
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/secret-groups` | List secret groups |
| GET | `/api/svc/v1/secret-groups/{id}` | Get secret group |
| POST | `/api/svc/v1/secret-groups` | Create secret group |
| POST | `/api/svc/v1/secrets` | List secrets in a group (body: secretGroupId, limit, offset) |
| GET | `/api/svc/v1/secrets/{id}` | Get secret by ID |
| PUT | `/api/svc/v1/secret-groups/{id}` | Update secret group (body: secrets array with key/value pairs; omitted secrets are deleted) |
| DELETE | `/api/svc/v1/secret-groups/{id}` | Delete secret group |
| DELETE | `/api/svc/v1/secrets/{id}` | Delete a secret |

## Jobs
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/svc/v1/jobs/trigger` | Trigger a job run (body: applicationId) |
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
| POST | `/api/ml/v1/prompts` | Create or update prompt (body: ChatPromptManifest) |
| DELETE | `/api/ml/v1/prompts/{id}` | Delete prompt |
| DELETE | `/api/ml/v1/prompt-versions/{id}` | Delete prompt version |

## Tracing
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/ml/v1/tracing-projects` | List tracing projects |
| POST | `/api/ml/v1/tracing-projects` | Create tracing project (body: name) |
| GET | `/api/ml/v1/tracing-projects/{id}` | Get tracing project |
| GET | `/api/ml/v1/tracing-projects/{id}/applications` | List applications in project |
| POST | `/api/ml/v1/tracing-projects/{id}/applications` | Create application in project (body: name) |

## ML Repos
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/ml/v1/ml-repos` | List ML repos |
| GET | `/api/ml/v1/ml-repos/{id}` | Get ML repo |

## Models
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/ml/v1/models` | List models (query: fqn, ml_repo_id, name) |

## Personal Access Tokens
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/personal-access-tokens` | List PATs |
| POST | `/api/svc/v1/personal-access-tokens` | Create PAT (body: name) |
| DELETE | `/api/svc/v1/personal-access-tokens/{id}` | Delete PAT |

## Model Catalogues
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/model-catalogues/deployment-specs` | Get recommended deployment specs for a HuggingFace model. Query: `huggingfaceHubUrl` (full HF URL), `workspaceId`, `huggingfaceHubTokenSecretFqn` (optional, for gated models), `pipelineTagOverride` (e.g. `text-generation`). Returns GPU, CPU, memory, storage requirements. |

## MCP Servers
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/mcp-servers` | List MCP servers (query: type, name) |
| GET | `/api/svc/v1/mcp-servers/{id}` | Get MCP server by ID |
| POST | `/api/svc/v1/mcp-servers` | Register a new MCP server (body: manifest) |
| DELETE | `/api/svc/v1/mcp-servers/{id}` | Delete an MCP server |

## Roles
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/roles` | List roles (query: resourceType) |
| POST | `/api/svc/v1/roles` | Create a role (body: name, displayName, description, resourceType, permissions) |
| GET | `/api/svc/v1/roles/{id}` | Get role by ID |
| DELETE | `/api/svc/v1/roles/{id}` | Delete a role |

## Teams
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/teams` | List teams |
| POST | `/api/svc/v1/teams` | Create a team (body: name, description) |
| GET | `/api/svc/v1/teams/{id}` | Get team by ID |
| DELETE | `/api/svc/v1/teams/{id}` | Delete a team |
| POST | `/api/svc/v1/teams/{id}/members` | Add member to team (body: subject, role) |
| DELETE | `/api/svc/v1/teams/{id}/members/{subject}` | Remove member from team |

## Collaborators
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/collaborators` | List collaborators on a resource (query: resourceType, resourceId) |
| POST | `/api/svc/v1/collaborators` | Add collaborator to a resource (body: resourceType, resourceId, subject, roleId) |
| DELETE | `/api/svc/v1/collaborators` | Remove collaborator from a resource (body: resourceType, resourceId, subject) |

## Guardrails
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/svc/v1/provider-accounts?type=guardrail-config-group` | List guardrail config groups |
| POST | `/api/svc/v1/provider-accounts` | Create guardrail config group (body: manifest with type provider-account/guardrail-config-group) |
| GET | `/api/svc/v1/gateway-guardrails-configs` | List gateway guardrails configs (query: gatewayRef) |
| POST | `/api/svc/v1/gateway-guardrails-configs` | Create gateway guardrails config (body: manifest) |
| PUT | `/api/svc/v1/gateway-guardrails-configs/{id}` | Update gateway guardrails config (body: manifest) |

## API Docs
- Full reference: `https://truefoundry.com/docs/api-reference`
- Generating API keys: `https://docs.truefoundry.com/docs/generating-truefoundry-api-keys`
