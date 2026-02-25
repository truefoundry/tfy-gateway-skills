# Fine-Tuning Configuration Reference

## Full Configuration Template

Fine-tuning uses the `application-set` type with the `finetune-qlora` template:

```yaml
# tfy-manifest.yaml — LLM Fine-Tuning
type: application-set
template: finetune-qlora
convert_template_manifest: true
values:
  name: finetune-my-model
  model_id: unsloth/Llama-3.3-70B-Instruct    # HuggingFace model ID
  hf_token: ""                                  # optional, tfy-secret:// for gated models
  ml_repo: my-ml-repo                           # TrueFoundry ML repo (required)
  data_type: chat                                # "chat" or "completion"
  data:
    type: upload                                 # "upload", "truefoundry-artifact", or "file-url"
    training_uri: ""                             # path/URL/artifact-FQN depending on type
  hyperparams:
    batch_size: 1
    epochs: 10
    learning_rate: 0.0001
    lora_alpha: 64
    lora_r: 32
    max_length: 2048
  image_uri: tfy.jfrog.io/tfy-images/llm-finetune:0.4.1   # see container-versions.md
  resources:
    node:
      type: node_selector
    devices:
      - type: nvidia_gpu
        count: 2
        name: H100_94GB
    cpu_request: 78
    cpu_limit: 80
    memory_request: 535500
    memory_limit: 630000
    ephemeral_storage_request: 710000
    ephemeral_storage_limit: 810000
    shared_memory_size: 534500
workspace_fqn: "YOUR_WORKSPACE_FQN"
```

### Data Source Types

| Type | Description | Example `training_uri` |
|------|-------------|----------------------|
| `upload` | Local JSONL file uploaded to TrueFoundry | `""` (populated after upload) |
| `truefoundry-artifact` | TrueFoundry ML artifact reference | `"artifact:truefoundry/my-data:1"` |
| `file-url` | Public URL to JSONL file | `"https://example.com/data.jsonl"` |

### Sample Data URLs

- Chat format: `https://assets.production.truefoundry.com/chatalpaca-openai-1k.jsonl`
- Completion format: `https://assets.production.truefoundry.com/standford_alpaca_test_2k.jsonl`

## Key Hyperparameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| **epochs** | 3 | 1-10 | Number of passes over the full dataset. More epochs = better learning but risk of overfitting. |
| **learning_rate** | 2e-4 | 1e-5 to 5e-4 | Step size for weight updates. Start small and increase if training loss plateaus. |
| **batch_size** | 4 | 1-32 | Samples processed before a parameter update. Larger = smoother gradients but more VRAM. |
| **max_length** | 2048 | 512-8192 | Maximum sequence length. Longer = more context but more VRAM and slower training. |
| **lora_r** | 16 | 4-64 | LoRA rank -- controls adapter capacity. Higher = more expressive but more parameters. |
| **lora_alpha** | 32 | 8-128 | LoRA scaling factor. Common rule: `lora_alpha = 2 * lora_r`. |
| **warmup_ratio** | 0.1 | 0.0-0.2 | Fraction of steps with linearly increasing learning rate. Helps stabilize early training. |
| **weight_decay** | 0.01 | 0.0-0.1 | Regularization to prevent overfitting. |
| **gradient_accumulation_steps** | 4 | 1-16 | Simulates larger batch sizes without more VRAM. Effective batch = batch_size x grad_accum. |

## Hyperparameter Recommendations by Use Case

**Quick experiment (small dataset, < 1000 examples):**
```
epochs: 3-5
learning_rate: 2e-4
batch_size: 4
lora_r: 8
lora_alpha: 16
max_length: 1024
```

**Production training (large dataset, 1000+ examples):**
```
epochs: 2-3
learning_rate: 1e-4
batch_size: 8
lora_r: 16
lora_alpha: 32
max_length: 2048
gradient_accumulation_steps: 4
```

**Domain adaptation (specialized vocabulary/knowledge):**
```
epochs: 5-10
learning_rate: 5e-5
batch_size: 4
lora_r: 32
lora_alpha: 64
max_length: 4096
weight_decay: 0.05
```
