# LLM Deployment Error Handling

Common errors encountered during LLM deployments and how to resolve them.

## GPU Node Not Available

```
Deployment stuck in Pending — GPU node scaling up.
This can take 5-15 minutes if a new GPU node needs to be provisioned.
Check the TrueFoundry dashboard for pod events.
If it stays Pending for 15+ minutes, the cluster may not have the requested GPU type available.
```

## Out of Memory (OOM)

```
Pod killed with OOMKilled.
The model needs more memory than allocated.
Fix: Increase memory_request and memory_limit.
For vLLM: also increase shared_memory_size and try reducing --max-model-len or --gpu-memory-utilization.
```

## Model Download Failed

```
Model download failed during startup.
Check:
- HF_TOKEN is set correctly for gated models
- Model ID is correct (case-sensitive)
- Network access to huggingface.co from the cluster
```

## CUDA Out of Memory

```
CUDA out of memory on GPU.
The model is too large for the selected GPU.
Fix:
- Use a GPU with more VRAM
- Reduce --max-model-len
- Use quantization (--quantization awq/gptq)
- Reduce --gpu-memory-utilization (e.g., 0.85)
```

## Startup Probe Failed

```
Pod killed by startup probe (exceeded failure_threshold).
The model took too long to load.
Fix: Increase startup_probe.failure_threshold (e.g., 50 or 60).
Large models (13B+) may need 600s+ to load.
```

## Invalid GPU Type

```
"None of the nodepools support {GPU_TYPE}"
The error message lists valid devices. Use one of those instead.
Always check available GPUs from the cluster API before deploying.
```

## Host Not Configured

```
"Provided host is not configured in cluster"
The host domain doesn't match cluster base_domains.
Fix: Look up base domains via GET /api/svc/v1/clusters/CLUSTER_ID
Use the wildcard domain (e.g., *.ml.your-org.truefoundry.cloud)
```
