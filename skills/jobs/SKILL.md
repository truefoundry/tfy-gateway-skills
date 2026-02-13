---
name: jobs
description: This skill should be used when the user asks "show job runs", "list runs", "job status", "is my job running", or wants to monitor TrueFoundry job executions. For listing job applications, use applications skill.
allowed-tools: Bash(*/tfy-api.sh *)
---

# Jobs

Monitor and inspect TrueFoundry job runs.

## When to Use

- User asks "show job runs", "list runs for my job"
- User asks "is my job running", "job status"
- User wants to check a specific job run
- Debugging a failed job run

## When NOT to Use

- User wants to list job *applications* → use `applications` skill with `application_type: "job"`
- User wants to deploy a job → use `deploy` skill

## List Job Runs

When using direct API, use the **full path** to this skill's `scripts/tfy-api.sh`. The path depends on which agent is installed (e.g. `~/.claude/skills/truefoundry-jobs/scripts/tfy-api.sh` for Claude Code, `~/.cursor/skills/truefoundry-jobs/scripts/tfy-api.sh` for Cursor). In the examples below, replace `TFY_API_SH` with the full path.

### Via MCP

```
tfy_jobs_list_runs(job_id="job-id")
tfy_jobs_list_runs(job_id="job-id", job_run_name="run-name")  # get specific run
tfy_jobs_list_runs(job_id="job-id", filters={"sort_by": "createdAt"})
```

### Via Direct API

```bash
# Set the path to tfy-api.sh for your agent (example for Claude Code):
TFY_API_SH=~/.claude/skills/truefoundry-jobs/scripts/tfy-api.sh

# List runs for a job
$TFY_API_SH GET /api/svc/v1/jobs/JOB_ID/runs

# Get specific run
$TFY_API_SH GET /api/svc/v1/jobs/JOB_ID/runs/RUN_NAME

# With filters
$TFY_API_SH GET '/api/svc/v1/jobs/JOB_ID/runs?sortBy=createdAt&searchPrefix=my-run'
```

### Filter Parameters

| Parameter | API Key | Description |
|-----------|---------|-------------|
| `search_prefix` | `searchPrefix` | Filter runs by name prefix |
| `sort_by` | `sortBy` | Sort field (e.g. `createdAt`) |
| `triggered_by` | `triggeredBy` | Filter by who triggered |

## Presenting Job Runs

```
Job Runs for data-pipeline:
| Run Name       | Status    | Started            | Duration |
|----------------|-----------|--------------------|---------| 
| run-20260210-1 | SUCCEEDED | 2026-02-10 09:00   | 5m 32s  |
| run-20260210-2 | FAILED    | 2026-02-10 10:00   | 1m 05s  |
| run-20260210-3 | RUNNING   | 2026-02-10 11:00   | —       |
```

## Composability

- **Find job first**: Use `applications` skill with `application_type: "job"` to get job app ID
- **Check logs**: Use `logs` skill with `job_run_name` to see run output
- **Redeploy job**: Use `deploy` skill

## Error Handling

### Job Not Found
```
Job ID not found. Use applications skill to list jobs:
tfy_applications_list(filters={"application_type": "job"})
```

### No Runs Found
```
No runs found for this job. The job may not have been triggered yet.
```
