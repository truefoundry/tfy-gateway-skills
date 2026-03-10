# Advanced Workflow Patterns

## Map Tasks (Parallel Execution)

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

## Conditional Tasks (Branching Logic)

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

## Spark Tasks

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
