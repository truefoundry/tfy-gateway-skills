---
name: jobs
description: This skill should be used when the user asks "deploy a job", "create a job", "run a batch task", "schedule a job", "show job runs", "list runs", "job status", "is my job running", or wants to deploy or monitor TrueFoundry job executions. For listing job applications, use applications skill.
allowed-tools: Bash(*/tfy-api.sh *), Bash(python*), Bash(pip*)
---

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

## Job Deployment

### Prerequisites

Same as deploy skill: `TFY_BASE_URL`, `TFY_API_KEY`, `TFY_WORKSPACE_FQN` required. Run `pip install truefoundry`.

### Step 1: Analyze the Job

- What does the job do? (training, batch processing, data pipeline, maintenance)
- One-time or scheduled?
- Resource requirements (CPU/GPU/memory)
- Expected duration

### Step 2: Create deploy.py

Provide SDK template:

```python
from truefoundry.deploy import Build, Job, PythonBuild, Resources, LocalSource, DockerFileBuild

# Option A: From local code with PythonBuild
job = Job(
    name="my-job",
    image=Build(
        build_source=LocalSource(local_build=False),
        build_spec=PythonBuild(
            command="python train.py",
            python_version="3.11",
            requirements_path="requirements.txt",
        ),
    ),
    resources=Resources(
        cpu_request=2, cpu_limit=4,
        memory_request=4000, memory_limit=8000,
        ephemeral_storage_request=1000, ephemeral_storage_limit=2000,
    ),
    env={
        "ENVIRONMENT": "production",
    },
)

# Option B: From Docker image
job = Job(
    name="my-job",
    image=Build(
        build_spec=DockerFileBuild(
            dockerfile_path="Dockerfile",
            command="python train.py",
        ),
        build_source=LocalSource(local_build=False),
    ),
    resources=Resources(
        cpu_request=2, cpu_limit=4,
        memory_request=4000, memory_limit=8000,
    ),
)

# Option C: Pre-built image
from truefoundry.deploy import Image
job = Job(
    name="my-job",
    image=Image(
        image_uri="my-registry/my-image:latest",
        command="python train.py",
    ),
    resources=Resources(
        cpu_request=2, cpu_limit=4,
        memory_request=4000, memory_limit=8000,
    ),
)

job.deploy(workspace_fqn="your-workspace-fqn")
```

### Scheduled Jobs (Cron)

```python
from truefoundry.deploy import Job, CronTrigger

job = Job(
    name="nightly-retrain",
    # ... image and resources ...
    trigger=CronTrigger(
        schedule="0 2 * * *",  # 2 AM daily
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
    name="my-job",
    trigger=ManualTrigger(
        num_retries=3,
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
    cpu_request=4, cpu_limit=8,
    memory_request=16000, memory_limit=32000,
    devices=[NvidiaGPU(name=GPUType.A10_24GB, count=1)],
)
```

### Job with Volume Mounts

```python
from truefoundry.deploy import Job, VolumeMount

job = Job(
    name="training-job",
    # ... image, resources ...
    mounts=[
        VolumeMount(
            mount_path="/data",
            volume_fqn="your-volume-fqn",
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
$TFY_API_SH POST /api/svc/v1/jobs/JOB_ID/runs -d '{}'
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
  - API: POST /api/svc/v1/jobs/{JOB_ID}/runs

To monitor runs:
  - Use the job monitoring commands below
  - Or check the TrueFoundry dashboard
```

**For scheduled jobs**, also show when the next run will execute.
**For manually triggered jobs**, remind the user how to trigger them.

### Via API Manifest

```bash
TFY_API_SH=~/.claude/skills/truefoundry-jobs/scripts/tfy-api.sh

$TFY_API_SH POST /api/svc/v1/applications -d '{
  "name": "my-batch-job",
  "type": "job",
  "workspace_fqn": "WORKSPACE_FQN",
  "manifest": {
    "name": "my-batch-job",
    "components": {
      "image": {
        "type": "image",
        "image_uri": "python:3.11-slim",
        "command": "python -c \"print('"'"'Hello from TrueFoundry Job!'"'"')\""
      },
      "resources": {
        "cpu_request": 0.5,
        "cpu_limit": 1,
        "memory_request": 500,
        "memory_limit": 1000
      }
    }
  }
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

- **Schedule jobs**: Use cron trigger for automated scheduling
- **Monitor runs**: Use the job runs monitoring sections below
- **Find job first**: Use `applications` skill with `application_type: "job"` to get job app ID
- **Check logs**: Use `logs` skill with `job_run_name` to see run output

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
