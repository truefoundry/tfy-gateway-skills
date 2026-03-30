---
name: ai-monitoring
description: Monitors AI Gateway traffic, costs, latency, errors, and token usage by querying request traces via the spans query API.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *)
---

> Routing note: For ambiguous user intents, use the shared clarification templates in [references/intent-clarification.md](references/intent-clarification.md).

<objective>

# AI Monitoring

Query AI Gateway request traces, costs, latency, errors, and token usage via the spans query API.

## When to Use

Investigate gateway traffic: recent requests, cost breakdowns, error rates, model usage, per-user activity, MCP tool calls, or latency analysis.

## When NOT to Use

- User wants to instrument their own application with tracing -> prefer `tracing` skill (this skill is for querying existing gateway traces, not adding instrumentation)
- User wants to configure gateway models, routing, or rate limits -> prefer `ai-gateway` skill
- User wants to view application container logs -> prefer `logs` skill
- User wants to check platform connectivity -> prefer `status` skill

</objective>

<instructions>

## Prerequisites

Run the `status` skill first to confirm `TFY_BASE_URL` and `TFY_API_KEY` are set and valid.

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

## Required Parameter

Every query requires one of these two parameters. Ask the user which one to use:

| Parameter | Description |
|-----------|-------------|
| `tracingProjectFqn` | Fully qualified name of the tracing project, e.g. `tenant:tracing-project:name` |
| `dataRoutingDestination` | Data routing destination name, e.g. `default` |

If the user does not know which to use, suggest `"dataRoutingDestination": "default"` as a starting point.

## Query Spans API

**Endpoint:** `POST /api/svc/v1/spans/query`

### Via Direct API

```bash
# Set the path to tfy-api.sh for your agent (example for Claude Code):
TFY_API_SH=~/.claude/skills/truefoundry-ai-monitoring/scripts/tfy-api.sh

# Basic query: recent spans in the last 24 hours
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "endTime": "2026-03-27T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "limit": 50,
  "sortDirection": "desc"
}'
```

## Common Use Cases

### 1. Show Recent Requests

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "limit": 20,
  "sortDirection": "desc"
}'
```

### 2. Cost Analysis (LLM Spans)

Filter for LLM spans and extract cost attributes:

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "filters": [
    {"spanAttributeKey": "tfy.span_type", "operator": "eq", "value": "LLM"}
  ],
  "limit": 200,
  "sortDirection": "desc"
}'
```

Cost fields in `spanAttributes`:
- `gen_ai.usage.cost` or `tfy.request_cost` -- cost of the request
- `gen_ai.usage.input_tokens` -- input token count
- `gen_ai.usage.output_tokens` -- output token count

### 3. Show Errors

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "filters": [
    {"spanFieldName": "statusCode", "operator": "eq", "value": "ERROR"}
  ],
  "limit": 50,
  "sortDirection": "desc"
}'
```

### 4. Model Usage Breakdown

Query all LLM spans and extract model info from span attributes to see which models are being used:

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "filters": [
    {"spanAttributeKey": "tfy.span_type", "operator": "eq", "value": "LLM"}
  ],
  "limit": 200,
  "sortDirection": "desc"
}'
```

Parse `spanAttributes` in the response for model name fields.

### 5. Requests by a Specific User

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "createdBySubjectSlugs": ["user@example.com"],
  "limit": 50,
  "sortDirection": "desc"
}'
```

You can also filter by subject type:

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "createdBySubjectTypes": ["virtualaccount"],
  "limit": 50,
  "sortDirection": "desc"
}'
```

### 6. MCP Tool Calls

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "filters": [
    {"spanAttributeKey": "tfy.span_type", "operator": "eq", "value": "MCP"}
  ],
  "limit": 50,
  "sortDirection": "desc"
}'
```

For MCP Gateway spans use `"value": "MCPGateway"` instead.

### 7. Filter by Application Name

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "applicationNames": ["tfy-llm-gateway"],
  "limit": 50,
  "sortDirection": "desc"
}'
```

### 8. Filter by Span Name (endpoint pattern)

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "filters": [
    {"spanFieldName": "spanName", "operator": "contains", "value": "completions"}
  ],
  "limit": 50,
  "sortDirection": "desc"
}'
```

### 9. Filter by Gateway Request Metadata

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "filters": [
    {"gatewayRequestMetadataKey": "tfy_gateway_region", "operator": "eq", "value": "US"}
  ],
  "limit": 50,
  "sortDirection": "desc"
}'
```

## Request Body Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `startTime` | string (ISO 8601) | Yes | Start of time range |
| `endTime` | string (ISO 8601) | No | End of time range (defaults to now) |
| `tracingProjectFqn` | string | One of this or `dataRoutingDestination` | Tracing project FQN |
| `dataRoutingDestination` | string | One of this or `tracingProjectFqn` | Data routing destination |
| `traceIds` | string[] | No | Filter by trace IDs |
| `spanIds` | string[] | No | Filter by span IDs |
| `parentSpanIds` | string[] | No | Filter by parent span IDs |
| `createdBySubjectTypes` | string[] | No | Filter by subject type (`user`, `virtualaccount`) |
| `createdBySubjectSlugs` | string[] | No | Filter by subject slug (e.g. email) |
| `applicationNames` | string[] | No | Filter by application name |
| `limit` | integer | No | Max results (default 200) |
| `sortDirection` | string | No | `asc` or `desc` |
| `pageToken` | string | No | Pagination token from previous response |
| `filters` | array | No | Array of filter objects (see Filter Types) |
| `includeFeedbacks` | boolean | No | Include feedback data |

## Filter Types

### SpanFieldFilter

```json
{"spanFieldName": "<field>", "operator": "<op>", "value": "<val>"}
```

Fields: `spanName`, `serviceName`, `spanKind`, `statusCode`, etc.

### SpanAttributeFilter

```json
{"spanAttributeKey": "<key>", "operator": "<op>", "value": "<val>"}
```

Any key from the `spanAttributes` dict (e.g. `tfy.span_type`, `gen_ai.usage.cost`).

### GatewayRequestMetadataFilter

```json
{"gatewayRequestMetadataKey": "<key>", "operator": "<op>", "value": "<val>"}
```

Custom metadata keys set via `X-TFY-LOGGING-CONFIG` headers.

### Filter Operators

`eq`, `neq`, `contains`, `not_contains`, `starts_with`, `ends_with`

## Response Structure

```json
{
  "data": [
    {
      "spanId": "...",
      "traceId": "...",
      "parentSpanId": "...",
      "serviceName": "tfy-llm-gateway",
      "spanName": "POST https://api.openai.com/v1/chat/completions",
      "spanKind": "Client",
      "scopeName": "...",
      "scopeVersion": "...",
      "timestamp": "2026-03-26T14:30:00.000Z",
      "durationNs": 1234567890,
      "statusCode": "OK",
      "statusMessage": "",
      "spanAttributes": {
        "gen_ai.usage.input_tokens": 150,
        "gen_ai.usage.output_tokens": 80,
        "gen_ai.usage.cost": 0.0023,
        "tfy.request_cost": 0.0023,
        "tfy.span_type": "LLM"
      },
      "events": [],
      "createdBySubject": {
        "subjectId": "...",
        "subjectSlug": "user@example.com",
        "subjectType": "user",
        "tenantName": "my-tenant"
      },
      "feedbacks": []
    }
  ],
  "pagination": {
    "nextPageToken": "..."
  }
}
```

## Pagination

When the response includes `pagination.nextPageToken`, pass it as `pageToken` in the next request to fetch the next page:

```bash
$TFY_API_SH POST '/api/svc/v1/spans/query' '{
  "startTime": "2026-03-26T00:00:00.000Z",
  "dataRoutingDestination": "default",
  "limit": 200,
  "pageToken": "TOKEN_FROM_PREVIOUS_RESPONSE"
}'
```

Continue until `nextPageToken` is null or absent.

## Presenting Results

Format results as tables for readability:

```
Recent Gateway Requests (last 24h):
| Time                | Model          | Status | Tokens (in/out) | Cost     | Latency   | User              |
|---------------------|----------------|--------|-----------------|----------|-----------|-------------------|
| 2026-03-26 14:30:00 | openai/gpt-4o  | OK     | 150 / 80        | $0.0023  | 1.23s     | user@example.com  |
| 2026-03-26 14:29:55 | anthropic/...  | OK     | 200 / 120       | $0.0045  | 2.10s     | bot@svc           |
| 2026-03-26 14:29:30 | openai/gpt-4o  | ERROR  | 100 / 0         | $0.0000  | 0.45s     | user@example.com  |
```

For cost summaries, aggregate across spans:

```
Cost Summary (last 24h):
| Model              | Requests | Total Cost | Avg Cost/Req | Total Tokens |
|--------------------|----------|------------|--------------|--------------|
| openai/gpt-4o      | 142      | $3.21      | $0.023       | 45,200       |
| anthropic/claude    | 58       | $1.87      | $0.032       | 22,100       |
| Total               | 200      | $5.08      | $0.025       | 67,300       |
```

Convert `durationNs` (nanoseconds) to human-readable format: divide by 1,000,000,000 for seconds.

</instructions>

<success_criteria>

## Success Criteria

- The user can see recent AI Gateway request traces with timestamps, models, status, and costs
- Cost and token usage are summarized clearly with per-model breakdowns when requested
- Errors are identified with status codes and messages for debugging
- Results are presented as formatted tables, not raw JSON
- Pagination is handled correctly for large result sets
- The agent asked for `dataRoutingDestination` or `tracingProjectFqn` before querying

</success_criteria>

<references>

## Composability

- **Preflight check**: Use `status` skill to verify credentials before querying
- **Gateway configuration**: Use `ai-gateway` skill to configure models, routing, rate limits
- **Instrument your app**: Use `tracing` skill to add tracing to your own applications (different from monitoring existing gateway traces)
- **View container logs**: Use `logs` skill for application-level logs (not gateway request traces)
- **Manage access tokens**: Use `access-tokens` skill to create/manage PAT or VAT used for gateway auth

</references>

<troubleshooting>

## Error Handling

### 400 Bad Request
```
Missing required parameter. Ensure you provide either:
- "tracingProjectFqn": "tenant:tracing-project:name"
- "dataRoutingDestination": "default"
And a valid "startTime" in ISO 8601 format.
```

### 401 Unauthorized
```
Authentication failed. Run the status skill to verify your TFY_API_KEY is valid.
```

### No Data Returned
```
Empty results. Check:
- Time range is correct (startTime/endTime)
- The dataRoutingDestination or tracingProjectFqn exists
- Filters are not too restrictive (try removing filters first)
- Gateway has actually received requests in this time period
```

### Pagination Token Expired
```
If a pageToken returns an error, restart the query from the beginning
with a fresh request (no pageToken).
```

</troubleshooting>
</output>
