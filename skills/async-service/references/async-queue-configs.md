# Async Service Queue Configurations

Queue-specific connection JSON and infrastructure deployment references for Async Services.

## AWS SQS

```json
{
  "type": "sqs",
  "queue_url": "https://sqs.us-east-1.amazonaws.com/123456789/my-input-queue",
  "aws_access_key_id": "AKIA...",
  "aws_secret_access_key": "...",
  "aws_region": "us-east-1"
}
```

**Sending messages to SQS:**

```python
import boto3, json

sqs = boto3.client("sqs", region_name="us-east-1")
sqs.send_message(
    QueueUrl="https://sqs.us-east-1.amazonaws.com/123456789/my-input-queue",
    MessageBody=json.dumps({
        "request_id": "unique-id-123",
        "body": {"data": "your payload here"}
    })
)
```

## NATS

```json
{
  "type": "nats",
  "nats_url": "nats://nats.NAMESPACE.svc.cluster.local:4222",
  "subject": "my-input-subject",
  "stream": "my-stream",
  "consumer": "my-consumer"
}
```

To deploy NATS on your cluster, use the `helm` skill:

```json
{
  "manifest": {
    "name": "nats",
    "type": "helm",
    "source": {
      "type": "oci-repo",
      "version": "latest",
      "oci_chart_url": "oci://REGISTRY/NATS_CHART"
    },
    "values": {
      "jetstream": {"enabled": true}
    },
    "workspace_fqn": "cluster-id:workspace-name"
  },
  "workspaceId": "WORKSPACE_ID"
}
```

## Kafka

```json
{
  "type": "kafka",
  "broker_url": "kafka.NAMESPACE.svc.cluster.local:9092",
  "topic": "my-input-topic",
  "consumer_group": "my-consumer-group"
}
```

To deploy Kafka on your cluster, use the `helm` skill. Ask the user for the chart source URL.

## Google AMQP

```json
{
  "type": "google_amqp",
  "project_id": "my-gcp-project",
  "subscription": "my-subscription",
  "credentials_json": "..."
}
```

## Deploying Queue Infrastructure

If the user does not have a queue provisioned, use the `helm` skill to deploy one on the cluster.

### Common Queue Charts

| Queue | Default Port | Notes |
|-------|-------------|-------|
| NATS | 4222 | Ask user for chart source URL |
| Kafka | 9092 | Ask user for chart source URL |
| RabbitMQ | 5672 | Ask user for chart source URL |

**For AWS SQS or Google AMQP**, the queue is a managed cloud service -- no Helm deployment needed. The user provides the queue URL and credentials.

**Workflow:**

1. Ask the user which queue type they want
2. If self-hosted (NATS, Kafka, RabbitMQ): use the `helm` skill to deploy first
3. Collect the queue connection details (URL, topic/subject, credentials)
4. Then deploy the Async Service pointing to that queue
