# Async Service Error Handling

Common errors encountered when deploying and operating Async Services.

## TFY_WORKSPACE_FQN Not Set
```
TFY_WORKSPACE_FQN is required. Get it from:
- TrueFoundry dashboard -> Workspaces
- Or use: workspaces skill to list available workspaces
Do not auto-pick a workspace.
```

## Queue Connection Failed
```
Async Service cannot connect to the queue.
Check:
1. Queue URL/host is correct and reachable from the cluster
2. Credentials (access key, secret, token) are valid
3. For self-hosted queues: verify the queue pod is running (use `applications` skill)
4. For SQS: verify IAM permissions allow sqs:ReceiveMessage, sqs:DeleteMessage
5. Network: ensure the cluster can reach the queue endpoint
```

## Sidecar Cannot Reach HTTP Service
```
The tfy-async-sidecar cannot POST to your service.
Check:
1. destination_url is correct (e.g., http://0.0.0.0:8000/process)
2. Your service is listening on the correct port
3. The POST endpoint exists and accepts JSON
4. Your service health check is passing
```

## Messages Not Being Processed
```
Messages are queuing up but not being processed.
Check:
1. Replicas: Is min=0 and the service scaled to zero? Increase min or check autoscaling.
2. Processing errors: Use `logs` skill to check for application errors.
3. Message format: Ensure messages match the expected payload format.
4. Acknowledgment: Messages are only acked after successful processing. Repeated failures cause redelivery.
```

## Scale-to-Zero Not Working
```
Service is not scaling to zero when queue is empty.
Check:
1. replicas.min must be 0 for scale-to-zero
2. Queue metrics must be accessible to the autoscaler
3. Cooldown period: there may be a delay before scaling to zero (typically 5-10 minutes)
```
