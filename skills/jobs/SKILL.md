---
name: jobs
description: This skill should be used when the user asks "deploy a job", "create a job", "run a batch task", "schedule a job", "show job runs", "list runs", "job status", "is my job running", "run a batch job", "execute a task", "cron job", "one-time job", "trigger a run", "check job run", "failed job", or wants to deploy or monitor TrueFoundry job executions. For listing job applications, use applications skill.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(*/tfy-api.sh *) Bash(python*) Bash(pip*)
---

<objective>

# Jobs

Deploy, schedule, and monitor TrueFoundry job runs.

## When to Use

- User asks "deploy a job", "create a job", "run a batch task"
- User asks "schedule a job", "run a cron job"
- User asks "show job runs", "list runs for my job"
- User asks "is my job running", "job status"
- User wants to check a specific job run
- Debugging a failed job run

## When NOT to Use

- User wants to list job *applications* → use `applications` skill with `application_type: "job"`

</objective>

<context>

## Job Deployment

### Prerequisites

Same as deploy skill: `TFY_BASE_URL`, `TFY_API_KEY`, `TFY_WORKSPACE_FQN` required. Run `pip install truefoundry`.

</context>

<instructions>

### Step 1: User Confirmation Checklist

**Before writing any code, walk through this checklist with the user and confirm every value.**

### Basic Configuration
- [ ] **Job name** — What to call this job
- [ ] **Job type** — One-time (manual trigger) or scheduled (cron)?
- [ ] **Environment** — Dev, staging, or production?

### Image Source
- [ ] **Image source** — Source code (local with PythonBuild), source code (Dockerfile), or pre-built Docker image?
- [ ] **If PythonBuild:**
  - [ ] **Command** — Entrypoint command (e.g., `python train.py`)
  - [ ] **Python version** — Which Python version? (e.g., 3.11)
  - [ ] **Requirements path** — Path to requirements.txt
- [ ] **If Dockerfile:**
  - [ ] **Dockerfile path** — Path to Dockerfile (e.g., `./Dockerfile`)
  - [ ] **Command** — Entrypoint command
  - [ ] **Build arguments** — Any Docker build args (optional)
- [ ] **If Docker image:**
  - [ ] **Image URI** — Full image URI (e.g., `registry/image:tag`)
  - [ ] **Command** — Container entrypoint command

### Resources
- [ ] **Device type** — CPU only, or GPU? If GPU, which type?
- [ ] **CPU** — Request and limit
- [ ] **Memory** — Request and limit in MB
- [ ] **Storage** — Ephemeral storage request and limit in MB
- [ ] **Capacity type** — Any, Spot, or On Demand?

### Scheduling (if cron)
- [ ] **Cron schedule** — Cron expression (minute hour day month weekday)
- [ ] **Concurrency policy** — Forbid, Allow, or Replace if runs overlap?

### Retry & Timeout
- [ ] **Retries** — Number of retries on failure (default: 0)
- [ ] **Timeout** — Max job duration in seconds (optional)

### Environment & Secrets
- [ ] **Environment variables** — Key-value pairs
- [ ] **Secrets** — TrueFoundry secret groups to mount
- [ ] **Volume mounts** — Persistent volumes to attach (optional)

**Do NOT deploy with hardcoded defaults without asking. Every `<PLACEHOLDER>` in the templates below MUST be replaced with a value confirmed by the user. If unsure about any field, ask — never assume.**

### Step 2: Create deploy.py

> **SDK v0.13.x breaking changes** (tested 2026-02-14):
> - `ManualTrigger` is now `Manual` — use `from truefoundry.deploy import Manual`
> - `CronTrigger` is now `Cron` — use `from truefoundry.deploy import Cron`
> - Job `image` with `DockerFileBuild` requires explicit `command` field (e.g., `command="python job.py"`)
> - Use Python 3.12 venv — 3.13+ / 3.14 are incompatible with the SDK

Provide SDK template:

```python
from truefoundry.deploy import Build, Job, PythonBuild, Resources, LocalSource, DockerFileBuild

# Option A: From local code with PythonBuild
job = Job(
    name="<JOB_NAME>",                              # ← ask user
    image=Build(
        build_source=LocalSource(local_build=False),
        build_spec=PythonBuild(
            command="<COMMAND>",                     # ← ask user (e.g., "python train.py")
            python_version="<PYTHON_VERSION>",       # ← ask user (e.g., "3.11")
            requirements_path="<REQUIREMENTS_PATH>", # ← ask user (e.g., "requirements.txt")
        ),
    ),
    resources=Resources(
        cpu_request=<CPU_REQUEST>,                   # ← ask user
        cpu_limit=<CPU_LIMIT>,                       # ← ask user
        memory_request=<MEMORY_REQUEST>,             # ← ask user (MB)
        memory_limit=<MEMORY_LIMIT>,                 # ← ask user (MB)
        ephemeral_storage_request=<STORAGE_REQUEST>, # ← ask user (MB)
        ephemeral_storage_limit=<STORAGE_LIMIT>,     # ← ask user (MB)
    ),
    env={
        # ← ask user for environment variables
    },
)

# Option B: From Dockerfile
job = Job(
    name="<JOB_NAME>",                              # ← ask user
    image=Build(
        build_spec=DockerFileBuild(
            dockerfile_path="<DOCKERFILE_PATH>",     # ← ask user
            command="<COMMAND>",                      # ← ask user
        ),
        build_source=LocalSource(local_build=False),
    ),
    resources=Resources(
        cpu_request=<CPU_REQUEST>,                   # ← ask user
        cpu_limit=<CPU_LIMIT>,                       # ← ask user
        memory_request=<MEMORY_REQUEST>,             # ← ask user (MB)
        memory_limit=<MEMORY_LIMIT>,                 # ← ask user (MB)
        ephemeral_storage_request=<STORAGE_REQUEST>, # ← ask user (MB)
        ephemeral_storage_limit=<STORAGE_LIMIT>,     # ← ask user (MB)
    ),
)

# Option C: Pre-built image
from truefoundry.deploy import Image
job = Job(
    name="<JOB_NAME>",                              # ← ask user
    image=Image(
        image_uri="<IMAGE_URI>",                     # ← ask user
        command="<COMMAND>",                          # ← ask user
    ),
    resources=Resources(
        cpu_request=<CPU_REQUEST>,                   # ← ask user
        cpu_limit=<CPU_LIMIT>,                       # ← ask user
        memory_request=<MEMORY_REQUEST>,             # ← ask user (MB)
        memory_limit=<MEMORY_LIMIT>,                 # ← ask user (MB)
        ephemeral_storage_request=<STORAGE_REQUEST>, # ← ask user (MB)
        ephemeral_storage_limit=<STORAGE_LIMIT>,     # ← ask user (MB)
    ),
)

job.deploy(workspace_fqn="<WORKSPACE_FQN>")          # ← ask user, never auto-pick
```

### Scheduled Jobs (Cron)

```python
from truefoundry.deploy import Job, CronTrigger

job = Job(
    name="<JOB_NAME>",                              # ← ask user
    # ... image and resources ...
    trigger=CronTrigger(
        schedule="<CRON_EXPRESSION>",                # ← ask user
    ),
)
```

Cron format: `minute hour day_of_month month day_of_week`

Common schedules:
| Schedule | Cron | Description |
|----------|------|-------------|
| Every hour | `0 * * * *` | Top of every hour |
| Daily at 2 AM | `0 2 * * *` | Nightly jobs |
| Weekly Monday | `0 9 * * 1` | Weekly Monday 9 AM |
| Monthly 1st | `0 0 1 * *` | First of month midnight |

### Retry Configuration

```python
from truefoundry.deploy import Job, ManualTrigger

job = Job(
    name="<JOB_NAME>",                              # ← ask user
    trigger=ManualTrigger(
        num_retries=<NUM_RETRIES>,                   # ← ask user
    ),
    # ... rest of config
)
```

### Concurrency Policies

Three options for scheduled jobs when a run overlaps:
- **Forbid** (default): Skip new run if previous still running
- **Allow**: Run in parallel
- **Replace**: Kill current, start new

### Parameterized Jobs

```python
import argparse
# In your job script, use argparse for dynamic params
parser = argparse.ArgumentParser()
parser.add_argument("--epochs", type=int, default=10)
parser.add_argument("--batch-size", type=int, default=32)
args = parser.parse_args()
```

Then set command: `python train.py --epochs 50 --batch-size 64`

### GPU Jobs

```python
from truefoundry.deploy import Resources, NvidiaGPU, GPUType

resources = Resources(
    cpu_request=<CPU_REQUEST>,                       # ← ask user
    cpu_limit=<CPU_LIMIT>,                           # ← ask user
    memory_request=<MEMORY_REQUEST>,                 # ← ask user (MB)
    memory_limit=<MEMORY_LIMIT>,                     # ← ask user (MB)
    devices=[NvidiaGPU(name=GPUType.<GPU_TYPE>, count=<GPU_COUNT>)],  # ← ask user
)
```

### Job with Volume Mounts

```python
from truefoundry.deploy import Job, VolumeMount

job = Job(
    name="<JOB_NAME>",                              # ← ask user
    # ... image, resources ...
    mounts=[
        VolumeMount(
            mount_path="<MOUNT_PATH>",               # ← ask user
            volume_fqn="<VOLUME_FQN>",               # ← ask user
        ),
    ],
)
```

### Step 3: Deploy

```bash
pip install truefoundry
python deploy.py
```

### Step 4: Trigger the Job

After deployment, trigger manually via API:

```bash
TFY_API_SH=~/.claude/skills/truefoundry-jobs/scripts/tfy-api.sh
$TFY_API_SH POST /api/svc/v1/jobs/trigger '{"applicationId":"JOB_APP_ID"}'
```

## After Deploy — Report Status

**CRITICAL: Always report the deployment status and job details to the user.**

### Check Job Status

```bash
TFY_API_SH=~/.claude/skills/truefoundry-jobs/scripts/tfy-api.sh

# Get job application details
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=JOB_NAME'
```

### Report to User

**Always present this summary after deployment:**

```
Job deployed successfully!

Job: {job-name}
Workspace: {workspace-fqn}
Status: Suspended (deployed, ready to trigger)
Schedule: {cron expression if scheduled, or "Manual trigger"}

To trigger the job:
  - Dashboard: Click "Run Job" on the job page
  - API: POST /api/svc/v1/jobs/trigger with {"applicationId":"JOB_APP_ID"}

To monitor runs:
  - Use the job monitoring commands below
  - Or check the TrueFoundry dashboard
```

**For scheduled jobs**, also show when the next run will execute.
**For manually triggered jobs**, remind the user how to trigger them.

### Via API Manifest

```bash
TFY_API_SH=~/.claude/skills/truefoundry-jobs/scripts/tfy-api.sh

# First, get workspace ID from FQN
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"

# Then deploy
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "name": "<JOB_NAME>",
    "type": "job",
    "image": {
      "type": "image",
      "image_uri": "<IMAGE_URI>",
      "command": "<COMMAND>"
    },
    "resources": {
      "cpu_request": <CPU_REQUEST>,
      "cpu_limit": <CPU_LIMIT>,
      "memory_request": <MEMORY_REQUEST>,
      "memory_limit": <MEMORY_LIMIT>
    },
    "workspace_fqn": "<WORKSPACE_FQN>"
  },
  "workspaceId": "<WORKSPACE_ID>"
}'
```

### .tfyignore

Create a `.tfyignore` file (follows `.gitignore` syntax) to exclude files from the Docker build:
```
.git/
__pycache__/
*.pyc
.env
data/
```

## List Job Runs

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

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

### Presenting Job Runs

```
Job Runs for data-pipeline:
| Run Name       | Status    | Started            | Duration |
|----------------|-----------|--------------------|---------| 
| run-20260210-1 | FINISHED  | 2026-02-10 09:00   | 5m 32s  |
| run-20260210-2 | FAILED    | 2026-02-10 10:00   | 1m 05s  |
| run-20260210-3 | RUNNING   | 2026-02-10 11:00   | —       |
```

</instructions>

<success_criteria>

## Success Criteria

- The job has been deployed to the target workspace and the user can see it in the TrueFoundry dashboard
- The user has been provided the job ID and knows how to trigger runs (manually or via cron schedule)
- The agent has reported the deployment status including job name, workspace, and trigger type
- Job logs are accessible for monitoring via the `logs` skill or the dashboard
- For scheduled jobs, the cron expression is confirmed and the user knows when the next run will execute

</success_criteria>

<references>

## Composability

- **Schedule jobs**: Use cron trigger for automated scheduling
- **Monitor runs**: Use the job runs monitoring sections below
- **Find job first**: Use `applications` skill with `application_type: "job"` to get job app ID
- **Check logs**: Use `logs` skill with `job_run_name` to see run output

</references>

<troubleshooting>

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

</troubleshooting>
