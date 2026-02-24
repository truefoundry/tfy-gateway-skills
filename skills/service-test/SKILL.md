---
name: service-test
description: This skill should be used when the user asks "test my deployment", "is my service healthy", "smoke test my app", "validate endpoint", "check if app is working", "health check", "test deployed service", "monitor deployment", "verify my service", "run endpoint tests", "check service response time", "is my API up", or wants to verify a deployed TrueFoundry service is responding correctly.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *) Bash(curl *)
---

<objective>

# Service Testing

Validate that a deployed TrueFoundry service is healthy and responding correctly. Runs health checks, endpoint smoke tests, and optional load soak tests.

## When to Use

- After deploying a service, to verify it's actually working
- User asks "is my service healthy", "test my deployment"
- User asks "smoke test", "validate endpoint", "check if app is working"
- User wants to verify an MCP server is responding and listing tools
- User wants to measure basic response times for a deployed service
- As the final step in a deploy → verify workflow

## When NOT to Use

- User wants to benchmark LLM inference performance → use `llm-benchmarking` skill
- User wants to view logs → use `logs` skill
- User wants to check pod status only → use `applications` skill
- User wants to deploy something → use `deploy` skill

</objective>

<instructions>

## Test Workflow

Run these layers in order. Stop at the first failure and report clearly.

```
Layer 1: Platform Check    → Is the pod running? Replicas healthy?
Layer 2: Health Check      → Does the endpoint respond with 200?
Layer 3: Endpoint Tests    → Do the app's routes return expected responses?
Layer 4: Load Soak         → (Optional) Does it hold up under repeated requests?
```

## Layer 1: Platform Check

Verify the application is running on TrueFoundry before hitting any endpoints.

### Via MCP

```
tfy_applications_list(filters={"workspace_fqn": "WORKSPACE_FQN", "application_name": "APP_NAME"})
```

### Via Direct API

```bash
TFY_API_SH=~/.claude/skills/truefoundry-service-test/scripts/tfy-api.sh

# Get app status
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=APP_NAME'
```

### What to Check

| Field | Expected | Problem If Not |
|-------|----------|----------------|
| `status` | `RUNNING` | Pod hasn't started or crashed |
| Replica count | >= 1 ready | Scale-down or crash loop |
| `updatedAt` | Recent | Stale deployment |

**If status is not RUNNING, stop here.** Tell the user to check logs with the `logs` skill.

### Extract the Endpoint URL

From the application response, extract the public URL:

```
ports[0].host → https://{host}
```

If no `host` is set (internal-only service), extract the internal DNS:

```
{app-name}.{workspace-namespace}.svc.cluster.local:{port}
```

Internal services can only be tested from within the cluster. Tell the user if the service is internal-only.

## Layer 2: Health Check

Hit the service endpoint and verify it responds.

### Standard Health Check

```bash
# Try common health endpoints in order
curl -s -o /dev/null -w '%{http_code} %{time_total}s' --max-time 10 "https://HOST/health"
curl -s -o /dev/null -w '%{http_code} %{time_total}s' --max-time 10 "https://HOST/healthz"
curl -s -o /dev/null -w '%{http_code} %{time_total}s' --max-time 10 "https://HOST/"
```

### What to Report

```
Health Check: https://my-app.example.cloud/health
  Status: 200 OK
  Response Time: 45ms
  Body: {"status": "ok"}
```

### Common Failures

| HTTP Code | Meaning | Next Step |
|-----------|---------|-----------|
| Connection refused | Pod not listening on port | Check port config matches app |
| 502 Bad Gateway | Pod crashed or not ready | Check `logs` skill |
| 503 Service Unavailable | Pod starting or overloaded | Wait and retry (max 3 times, 5s apart) |
| 404 Not Found | No route at this path | Try `/healthz`, `/`, or ask user for health path |
| 401/403 | Auth required | Ask user for auth headers |

## Layer 3: Endpoint Smoke Tests

Test the service's actual functionality based on its type. Auto-detect the type, or ask the user.

### MCP Server

MCP servers expose an `/mcp` endpoint. Test the MCP protocol handshake:

```bash
# Test MCP initialize (streamable HTTP)
curl -s --max-time 15 \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-03-26",
      "capabilities": {},
      "clientInfo": {"name": "service-test", "version": "1.0.0"}
    }
  }' \
  "https://HOST/mcp"
```

**What to verify:**
- Response contains `"result"` with `"serverInfo"` and `"capabilities"`
- No `"error"` field in response

Then list tools:

```bash
# List available tools
curl -s --max-time 15 \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: SESSION_ID_FROM_INIT" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/list",
    "params": {}
  }' \
  "https://HOST/mcp"
```

**Report format:**

```
MCP Server Test: https://mcp-server.example.cloud/mcp
  Protocol: OK (initialized)
  Server: tfy-mcp-server v1.0.0
  Tools: 16 registered
  Tool list: tfy_applications_list, tfy_workspaces_list, ...
```

### REST API (FastAPI / Flask / Express)

```bash
# Test root endpoint
curl -s --max-time 10 "https://HOST/"

# Test OpenAPI docs (FastAPI)
curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://HOST/docs"
curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://HOST/openapi.json"
```

**Report format:**

```
REST API Test: https://my-api.example.cloud
  Root (/): 200 OK — {"message": "hello"}
  Docs (/docs): 200 OK — Swagger UI available
  OpenAPI (/openapi.json): 200 OK — 12 endpoints documented
```

If `/openapi.json` is available, parse it and report the endpoint count and list.

### Generic Web App

```bash
# Test root
curl -s -o /dev/null -w '%{http_code} %{size_download}bytes %{time_total}s' --max-time 10 "https://HOST/"
```

**Report format:**

```
Web App Test: https://my-app.example.cloud
  Root (/): 200 OK — 14832 bytes, 0.23s
  Content-Type: text/html
```

### User-Specified Endpoints

If the user provides specific endpoints to test, test each one:

```bash
# For each endpoint the user specifies
curl -s -w '\n%{http_code} %{time_total}s' --max-time 10 "https://HOST/ENDPOINT"
```

## Layer 4: Load Soak (Optional)

Only run if the user asks for it ("load test", "soak test", "stress test", "how fast is it"). This is NOT a full benchmark — use `llm-benchmarking` for LLM performance testing.

### Sequential Soak (Default)

Send N requests sequentially and report stats:

```bash
# Run 10 sequential requests to the health endpoint
for i in $(seq 1 10); do
  curl -s -o /dev/null -w '%{time_total}\n' --max-time 10 "https://HOST/health"
done
```

Collect the times and report:

```
Load Soak: 10 sequential requests to /health
  Min:  0.041s
  Avg:  0.048s
  Max:  0.062s
  P95:  0.059s
  Errors: 0/10
```

### Concurrent Soak

If the user asks for concurrent testing:

```bash
# Run 10 concurrent requests using background processes
for i in $(seq 1 10); do
  curl -s -o /dev/null -w '%{http_code} %{time_total}\n' --max-time 10 "https://HOST/health" &
done
wait
```

Report same stats plus error count.

### Soak Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Requests | 10 | Number of requests to send |
| Endpoint | `/health` | Endpoint to hit |
| Concurrency | 1 (sequential) | Parallel requests |
| Timeout | 10s | Max time per request |

**If error rate > 20%, stop the soak early and report the issue.**

## Full Report Format

After all layers, present a summary:

```
Service Test Report: my-app
============================================================

Platform:
  Status: RUNNING
  Replicas: 2/2 ready
  Last Deployed: 2026-02-14 10:30 UTC

Health Check:
  Endpoint: https://my-app.example.cloud/health
  Status: 200 OK
  Response Time: 45ms

Endpoint Tests:
  GET /         → 200 OK (12ms)
  GET /docs     → 200 OK (85ms)
  GET /health   → 200 OK (45ms)

Load Soak (10 requests):
  Avg: 48ms | P95: 59ms | Max: 62ms | Errors: 0/10

Result: ALL PASSED
```

If any layer fails:

```
Result: FAILED at Layer 2 (Health Check)
  Error: 502 Bad Gateway
  Action: Check logs with the logs skill — likely a crash on startup
```

</instructions>

<success_criteria>

## Success Criteria

- The agent has verified the application is in RUNNING state on the platform
- The user can see a clear pass/fail result for each test layer
- The agent has produced a formatted test report with response times and status codes
- The user can identify the exact failure point if any layer fails
- The agent has suggested next steps (e.g., check logs) on failure
- The user can optionally run a load soak and see min/avg/max/P95 stats

</success_criteria>

<references>

## Composability

- **Before testing**: Use `applications` skill to find the app and its endpoint URL
- **Before testing**: Use `workspaces` skill to get the workspace FQN
- **On failure**: Use `logs` skill to investigate what went wrong
- **After deploy**: Chain directly — `deploy` → `service-test`
- **For LLMs**: Use `llm-benchmarking` skill instead for inference performance testing
- **For status only**: Use `applications` skill if you just need pod status without endpoint testing

</references>

<troubleshooting>

## Error Handling

### Cannot Determine Endpoint URL

```
Could not find a public URL for this application.
The service may be internal-only (no host configured in ports).

Options:
- If this is intentional, the service can only be tested from within the cluster
- To expose it publicly, redeploy with a host configured (use deploy skill)
```

### SSL/TLS Errors

```
SSL certificate error when connecting to the endpoint.
This usually means the service was just deployed and the certificate hasn't provisioned yet.
Wait 2-3 minutes and retry.
```

### Timeout on All Endpoints

```
All endpoints timed out (10s).
Possible causes:
- App is still starting up (check logs)
- App is listening on wrong port
- Network issue between you and the cluster
Action: Use logs skill to check if the app started successfully.
```

### Auth Required (401/403)

```
Endpoint requires authentication.
Provide auth details:
- For API key auth: pass --header "Authorization: Bearer YOUR_KEY"
- For TrueFoundry auth: the endpoint may need TFY_API_KEY as a header
```

</troubleshooting>
