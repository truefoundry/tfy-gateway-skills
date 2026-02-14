---
name: workflows
description: This skill should be used when the user asks "create a workflow", "deploy a workflow", "run a pipeline", "schedule a workflow", "cron workflow", "TrueFoundry workflow", or wants to build data processing or ML training pipelines using TrueFoundry Workflows (built on Flyte).
allowed-tools: Bash(python*), Bash(pip*)
---

# TrueFoundry Workflows

Create, configure, and deploy workflows on TrueFoundry. Workflows are built on [Flyte](https://flyte.org/), an open-source orchestration platform, and use Python decorators (`@task`, `@workflow`) to define structured sequences of tasks as directed acyclic graphs (DAGs).

## When to Use

- User wants to create a data processing or ML training pipeline
- User says "create a workflow", "deploy a workflow", "run a pipeline"
- User wants to schedule recurring batch operations (cron workflows)
- User wants to orchestrate multi-step tasks: ETL, feature engineering, model training, batch inference
- User asks about Flyte tasks, map tasks, conditional tasks, or Spark tasks on TrueFoundry

## When NOT to Use

- User wants to deploy a web service or API -> use `deploy` skill
- User wants to deploy a one-off job (not a multi-step pipeline) -> use `deploy` skill with job type
- User wants to check running applications -> use `applications` skill
- User wants to monitor job runs -> use `jobs` skill
- User wants to serve an ML model behind an endpoint -> use `llm-deploy` or `deploy` skill

## Prerequisites

**Always verify before creating a workflow:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**
3. **Python** — Python 3.9+ required
4. **SDK** — Install the TrueFoundry SDK with workflow extras:
   ```bash
   pip install "truefoundry[workflow]"
   ```
5. **Cluster setup** — The Flyte data plane must be installed on the target cluster. The control plane ships with TrueFoundry (no additional setup). If the user gets errors about Flyte not being available, they need to contact their platform admin to install the data plane components.

For credential check commands and .env setup, see `references/prerequisites.md`.

## Core Concepts

- **Task** -- The smallest unit of execution. A Python function decorated with `@task`. Each task runs in its own container with configurable resources and dependencies.
- **Workflow** -- A composition of tasks arranged as a DAG using the `@workflow` decorator. Defines execution order and data flow between tasks.
- **Task Config** -- Specifies the container image, Python version, pip packages, and compute resources for each task.
- **Execution Config** -- Controls scheduling (cron), launch plans, and runtime parameters.

**Critical rule:** The workflow function must contain **only task calls and control flow**. Do not put business logic directly in the workflow function -- all computation must live inside `@task` functions.

## Basic Workflow Example

```python
from truefoundry.workflow import task, workflow, PythonTaskConfig, TaskPythonBuild
from truefoundry.deploy import Resources

# Define task configuration
task_config = PythonTaskConfig(
    image=TaskPythonBuild(
        python_version="3.11",
        pip_packages=[
            "truefoundry[workflow]",
            "pandas",
            "scikit-learn",
        ],
    ),
    resources=Resources(
        cpu_request=0.5,
        cpu_limit=1.0,
        memory_request=512,
        memory_limit=1024,
    ),
)

@task(task_config=task_config)
def fetch_data(source: str) -> dict:
    """Fetch and return raw data."""
    import pandas as pd
    # Your data fetching logic here
    data = {"records": 1000, "source": source}
    return data

@task(task_config=task_config)
def process_data(raw_data: dict) -> dict:
    """Clean and transform the data."""
    processed = {
        "records": raw_data["records"],
        "source": raw_data["source"],
        "status": "processed",
    }
    return processed

@task(task_config=task_config)
def train_model(data: dict) -> str:
    """Train a model on processed data."""
    # Your training logic here
    return f"model_trained_on_{data['records']}_records"

@workflow
def ml_pipeline(source: str = "default") -> str:
    """End-to-end ML pipeline."""
    raw = fetch_data(source=source)
    processed = process_data(raw_data=raw)
    result = train_model(data=processed)
    return result
```

## Task Configuration

### PythonTaskConfig

Every task needs a `PythonTaskConfig` that defines its execution environment:

```python
from truefoundry.workflow import PythonTaskConfig, TaskPythonBuild
from truefoundry.deploy import Resources

# CPU task
cpu_task_config = PythonTaskConfig(
    image=TaskPythonBuild(
        python_version="3.11",
        pip_packages=[
            "truefoundry[workflow]",
            "pandas==2.1.0",
            "numpy",
        ],
        # Or use a requirements file:
        # requirements_path="requirements.txt",
    ),
    resources=Resources(
        cpu_request=0.5,
        cpu_limit=1.0,
        memory_request=512,
        memory_limit=1024,
    ),
)

# GPU task (for training or inference steps)
gpu_task_config = PythonTaskConfig(
    image=TaskPythonBuild(
        python_version="3.11",
        pip_packages=[
            "truefoundry[workflow]",
            "torch",
            "transformers",
        ],
    ),
    resources=Resources(
        cpu_request=2.0,
        cpu_limit=4.0,
        memory_request=8192,
        memory_limit=16384,
        devices=[
            GPUDevice(name="T4", count=1),
        ],
    ),
)
```

**Key points:**
- `truefoundry[workflow]` must always be in `pip_packages` (or in the requirements file)
- `pip_packages` takes a list of pip-installable package specifiers
- `requirements_path` can point to a requirements file instead of inline packages
- Resource `memory_request` and `memory_limit` are in MB
- Different tasks can have different configs (e.g., lightweight preprocessing vs GPU-heavy training)

### Container Tasks

For tasks that need a pre-built Docker image instead of a Python build:

```python
from truefoundry.workflow import task, ContainerTask

container_task = ContainerTask(
    name="my-container-task",
    image="my-registry/my-image:latest",
    command=["python", "run.py"],
    resources=Resources(
        cpu_request=1.0,
        memory_request=2048,
    ),
)
```

Use container tasks when:
- You need a custom base image with system-level dependencies
- The task runs non-Python code
- You have a pre-built image with all dependencies baked in

## Cron Workflows (Scheduling)

Schedule workflows to run at fixed intervals using cron syntax. The schedule is always in **UTC timezone**.

```python
from truefoundry.workflow import workflow, ExecutionConfig

@workflow(
    execution_configs=[
        ExecutionConfig(schedule="0 6 * * *"),  # Every day at 6:00 AM UTC
    ]
)
def daily_etl_pipeline() -> str:
    raw = fetch_data(source="production_db")
    processed = process_data(raw_data=raw)
    return processed["status"]
```

### Common Cron Patterns

| Schedule | Cron Expression | Description |
|----------|----------------|-------------|
| Every 10 minutes | `*/10 * * * *` | Frequent data sync |
| Every hour | `0 * * * *` | Hourly aggregation |
| Daily at midnight UTC | `0 0 * * *` | Nightly batch jobs |
| Daily at 6 AM UTC | `0 6 * * *` | Morning data refresh |
| Every Monday at 9 AM UTC | `0 9 * * 1` | Weekly reports |
| First of month at midnight | `0 0 1 * *` | Monthly processing |

**Cron format:** `minute hour day-of-month month day-of-week`

## Advanced Patterns

### Map Tasks (Parallel Execution)

Process multiple inputs in parallel using map tasks. Useful for batch processing large datasets or running the same computation across many inputs.

```python
from truefoundry.workflow import task, workflow, map_task

@task(task_config=task_config)
def process_single_file(file_path: str) -> dict:
    """Process one file -- this runs in its own container."""
    # Heavy processing logic here
    return {"file": file_path, "status": "done"}

@workflow
def batch_processing_pipeline(file_paths: list[str]) -> list[dict]:
    """Process many files in parallel."""
    results = map_task(process_single_file)(file_path=file_paths)
    return results
```

Map tasks automatically parallelize across the input list. Each invocation gets its own container with the resources defined in the task config.

### Conditional Tasks (Branching Logic)

Execute different tasks based on runtime conditions:

```python
from truefoundry.workflow import task, workflow, conditional

@task(task_config=task_config)
def evaluate_data(data: dict) -> bool:
    """Check if data meets quality threshold."""
    return data["records"] > 500

@task(task_config=task_config)
def full_training(data: dict) -> str:
    return "full_model_trained"

@task(task_config=task_config)
def lightweight_training(data: dict) -> str:
    return "lightweight_model_trained"

@workflow
def adaptive_pipeline(source: str = "default") -> str:
    raw = fetch_data(source=source)
    processed = process_data(raw_data=raw)
    is_large = evaluate_data(data=processed)
    result = (
        conditional("training_branch")
        .if_(is_large.is_true())
        .then(full_training(data=processed))
        .else_()
        .then(lightweight_training(data=processed))
    )
    return result
```

### Spark Tasks

Run PySpark jobs as workflow tasks for large-scale data processing:

```python
from truefoundry.workflow import task
from flytekitplugins.spark import Spark

@task(
    task_config=Spark(
        spark_conf={
            "spark.executor.instances": "3",
            "spark.executor.memory": "4g",
            "spark.executor.cores": "2",
        }
    ),
)
def spark_etl(input_path: str) -> str:
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.getOrCreate()
    df = spark.read.parquet(input_path)
    # Transform data
    df_processed = df.filter(df["value"] > 0)
    output_path = input_path.replace("raw", "processed")
    df_processed.write.parquet(output_path)
    return output_path
```

**Note:** Spark tasks require the Spark operator to be installed on the cluster. Check with your platform admin if Spark tasks fail.

## Deploying Workflows

### Using the TrueFoundry CLI

```bash
tfy deploy workflow \
  --name my-ml-pipeline \
  --file workflow.py \
  --workspace_fqn "$TFY_WORKSPACE_FQN"
```

### Using the Python SDK

```python
from truefoundry.workflow import WorkflowDeployment

deployment = WorkflowDeployment(
    name="my-ml-pipeline",
    workflow_file="workflow.py",
    workspace_fqn="your-workspace-fqn",
)
deployment.deploy()
```

### Deployment Checklist

Before deploying, confirm with the user:

- [ ] **Workflow name** -- a descriptive name for the workflow
- [ ] **Workspace** -- `TFY_WORKSPACE_FQN` is set (never auto-pick)
- [ ] **Task configs** -- each task has appropriate resources, Python version, and packages
- [ ] **Pip packages** -- `truefoundry[workflow]` is included in every task's packages
- [ ] **Schedule** -- if cron, confirm the cron expression and timezone (always UTC)
- [ ] **Workflow file** -- path to the Python file containing `@workflow` and `@task` definitions

## Monitoring Workflow Runs

After deployment, monitor runs through:

1. **TrueFoundry Dashboard** -- Navigate to Workflows in the dashboard to see run history, task status, logs, and DAG visualization.
2. **Applications skill** -- Use the `applications` skill to list workflow applications:
   ```
   tfy_applications_list(filters={"application_type": "workflow"})
   ```
3. **Jobs skill** -- Use the `jobs` skill to inspect individual workflow run details and status.

### Run States

| State | Meaning |
|-------|---------|
| QUEUED | Run is waiting to be scheduled |
| RUNNING | Tasks are actively executing |
| SUCCEEDED | All tasks completed successfully |
| FAILED | One or more tasks failed |
| TIMED_OUT | Run exceeded its timeout |
| ABORTED | Run was manually cancelled |

## Composability

- **Check credentials first**: Use `status` skill to verify TrueFoundry connection
- **Find workspace**: Use `workspaces` skill to list available workspaces
- **List workflows**: Use `applications` skill with `application_type: "workflow"`
- **Monitor runs**: Use `jobs` skill to check run status and history
- **View logs**: Use `logs` skill to inspect task-level logs
- **Manage secrets**: Use `secrets` skill to set up secret groups for workflow tasks that need API keys or credentials

## Error Handling

### SDK Not Installed
```
Install the TrueFoundry SDK with workflow extras:
  pip install "truefoundry[workflow]"
```

### TFY_WORKSPACE_FQN Not Set
```
TFY_WORKSPACE_FQN is required. Get it from:
- TrueFoundry dashboard -> Workspaces
- Or use the workspaces skill to list available workspaces
Do not auto-pick a workspace.
```

### Flyte Data Plane Not Available
```
Flyte data plane is not installed on this cluster.
The control plane ships with TrueFoundry, but the data plane must be installed
on each cluster separately. Contact your platform admin to set up the Flyte
data plane components on the target cluster.
```

### Business Logic in Workflow Function
```
Error: Workflow function contains non-task code.
The @workflow function must only contain task calls and control flow.
Move all computation into @task-decorated functions.

Bad:
  @workflow
  def my_wf():
      data = pd.read_csv("file.csv")  # NOT allowed in workflow function
      return process(data)

Good:
  @workflow
  def my_wf():
      data = load_data()              # Call a @task instead
      return process(data)
```

### Missing truefoundry[workflow] in Task Packages
```
Each task's PythonTaskConfig must include "truefoundry[workflow]" in pip_packages.
Without it, the task container cannot communicate with the Flyte backend.

Fix: Add "truefoundry[workflow]" to the pip_packages list in every PythonTaskConfig.
```

### Task Resource Errors
```
Task failed due to resource limits (OOMKilled or CPU throttled).
Increase memory_limit or cpu_limit in the task's Resources config.
Check the task logs in the TrueFoundry dashboard for details.
```

### Cron Schedule Not Triggering
```
Cron schedules use UTC timezone. Verify your cron expression accounts for
UTC offset from your local timezone.
Use https://crontab.guru to validate your cron expression.
```
