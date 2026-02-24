# Fine-Tuning Configuration Reference

## Full Configuration Template

```yaml
# Fine-tuning configuration
base_model: meta-llama/Llama-3.1-8B-Instruct
method: qlora                    # qlora | lora | full

# Data
dataset_path: /data/train.jsonl  # Path to JSONL training data
dataset_format: chat             # chat | completion
validation_split: 0.1            # Fraction of data for validation

# Training hyperparameters
epochs: 3
learning_rate: 2e-4
batch_size: 4
gradient_accumulation_steps: 4
max_length: 2048
warmup_ratio: 0.1
weight_decay: 0.01
lr_scheduler: cosine             # cosine | linear | constant

# LoRA configuration (for qlora/lora methods)
lora_r: 16
lora_alpha: 32
lora_dropout: 0.05
lora_target_modules: auto        # auto | q_proj,v_proj,k_proj,o_proj,...

# QLoRA-specific
quantization_bits: 4             # 4 | 8 (only for qlora)
bnb_4bit_compute_dtype: bfloat16 # bfloat16 | float16 (for A100/H100 use bfloat16)
bnb_4bit_quant_type: nf4         # nf4 | fp4

# Output
output_dir: /output
save_strategy: epoch             # epoch | steps
save_steps: 500                  # if save_strategy is steps
push_to_hub: false
```

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
