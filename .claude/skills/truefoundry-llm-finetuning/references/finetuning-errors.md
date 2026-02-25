# Fine-Tuning Error Handling

## CLI Errors

### tfy: command not found
```
The tfy CLI is not installed.
Fix:
  pip install truefoundry
  tfy login --host "$TFY_BASE_URL"
```

### Manifest Validation Failed
```
YAML manifest failed validation.
Check:
- YAML syntax is valid (no tabs, proper indentation)
- Required fields: name, type, workspace_fqn
- GPU device name matches cluster availability
- Memory values are in MB (not GB or bytes)
- env values must be strings (quote numbers: "3", "2e-4")
```

## Training Errors

### CUDA Out of Memory During Training
```
CUDA out of memory during training.
Fine-tuning uses more VRAM than inference due to gradients and optimizer states.
Fix:
- Reduce batch_size (e.g., from 4 to 2 or 1)
- Reduce max_length (e.g., from 2048 to 1024)
- Switch from LoRA to QLoRA (4-bit quantization)
- Reduce lora_r (e.g., from 16 to 8)
- Use gradient_accumulation_steps to compensate for smaller batch size
- Use a GPU with more VRAM
```

### Training Loss Not Decreasing
```
Training loss is flat or not decreasing.
Possible causes:
- Learning rate too low → increase by 2-5x
- Data quality issues → check for empty/corrupt examples
- Dataset too small → need more diverse training examples
- Wrong data format → verify JSONL format matches expected schema
```

### NaN Loss
```
Training loss became NaN.
Fix:
- Reduce learning_rate by 10x (e.g., from 2e-4 to 2e-5)
- Check for corrupt data (empty strings, invalid characters)
- Ensure max_length is not larger than model's native context window
- Try a different random seed
```

### Model Download Failed
```
Base model download failed.
Check:
- HF_TOKEN is set correctly for gated models (Llama, Gemma, etc.)
- Model ID is correct and case-sensitive
- You have accepted the model's license on HuggingFace
- Network access to huggingface.co from the cluster
```

### GPU Node Not Available
```
Job stuck in Pending — GPU node scaling up.
This can take 5-15 minutes if a new GPU node needs provisioning.
If it stays Pending for 15+ minutes:
- The cluster may not have the requested GPU type
- Check available GPUs via cluster API
- Try a different GPU type
```

### Overfitting (Validation Loss Increasing)
```
Validation loss increasing while training loss decreases — model is overfitting.
Fix:
- Reduce number of epochs
- Increase weight_decay (e.g., from 0.01 to 0.05)
- Add more diverse training data
- Reduce lora_r to limit model capacity
- Increase lora_dropout (e.g., from 0.05 to 0.1)
```

### Checkpoint Save Failed
```
Failed to save checkpoint — disk full.
Fix:
- Increase ephemeral_storage_limit in the manifest
- Reduce save frequency (save_strategy: epoch instead of steps)
- Clean up old checkpoints by setting save_total_limit
```

### HuggingFace Token Permission Denied
```
Access denied for gated model.
Fix:
- Accept the model license at https://huggingface.co/{model-id}
- Verify HF_TOKEN has read access to the model
- Use secrets skill to check the token is correctly stored in TrueFoundry
```

## REST API Fallback Errors

```
401 Unauthorized — Check TFY_API_KEY is valid and not expired
404 Not Found — Check TFY_BASE_URL and API endpoint path
422 Validation Error — Check manifest fields match expected schema
```
