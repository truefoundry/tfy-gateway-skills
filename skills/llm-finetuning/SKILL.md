---
name: llm-finetuning
description: This skill should be used when the user asks "finetune a model", "fine-tune LLM", "train a model", "LoRA finetuning", "QLoRA finetuning", "full finetuning", "fine-tune on my data", "customize a model", "adapt a model", or wants to fine-tune a large language model on TrueFoundry.
allowed-tools: Bash(python*), Bash(pip*), Bash(*/tfy-api.sh *)
---

# LLM Fine-Tuning

Fine-tune large language models on TrueFoundry using QLoRA, LoRA, or full fine-tuning. Supports models up to 70B parameters across Llama, Mistral, Qwen, Gemma, Phi, and other architectures. Training runs as a TrueFoundry Job with GPU acceleration, experiment tracking, and one-click deployment of the finetuned model.

## When to Use

- User says "finetune a model", "fine-tune LLM", "train a model"
- User says "LoRA finetuning", "QLoRA finetuning", "full finetuning"
- User wants to customize a base model on their own data
- User wants to adapt a HuggingFace model for a specific task
- User says "train on my dataset", "fine-tune on my data"

## When NOT to Use

- User wants to deploy a pre-trained model for inference → use `llm-deploy` skill
- User wants to deploy a regular app or API → use `deploy` skill
- User wants to run a generic batch job → use `deploy` skill with job type
- User wants prompt engineering without training → use `prompts` skill
- User wants to check training job status → use `jobs` skill (after the job is launched)

## Prerequisites

**Always verify before launching a fine-tuning job:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` is **required**. Never auto-pick. Ask the user if missing.
3. **GPU availability** — Fine-tuning requires GPU. Check cluster GPU types before proceeding.
4. **Training data** — User must have a dataset in a supported format (see Data Preparation).
5. **HuggingFace token** — Required for gated models (Llama, Gemma, etc.). Use the `secrets` skill to set up a TrueFoundry secret group.

```bash
# Check credentials
echo "TFY_BASE_URL: ${TFY_BASE_URL:-(not set)}"
echo "TFY_API_KEY: ${TFY_API_KEY:+(set)}${TFY_API_KEY:-(not set)}"
echo "TFY_WORKSPACE_FQN: ${TFY_WORKSPACE_FQN:-(not set)}"
```

**If TFY_WORKSPACE_FQN is not set, STOP. Ask the user.** Suggest they use the `workspaces` skill or check the TrueFoundry dashboard.

## Supported Fine-Tuning Methods

| Method | Description | VRAM Required | Best For |
|--------|-------------|---------------|----------|
| **QLoRA** | Quantized LoRA — 4-bit quantized base model + LoRA adapters | Lowest (single GPU for 7B) | Most use cases. Recommended default. |
| **LoRA** | Low-Rank Adaptation — trains small adapter layers on top of frozen base model | Moderate | When you need slightly better quality than QLoRA |
| **Full Fine-Tuning** | Updates all model weights | Highest (multi-GPU for 7B+) | Maximum quality, requires significant GPU resources |

**Default recommendation: QLoRA.** It provides the best balance of quality, speed, and cost. Use LoRA or full fine-tuning only when QLoRA quality is insufficient for the task.

## Supported Model Architectures

Fully supported (up to 70B parameters):
- **Llama** (Meta) — Llama 2, Llama 3, Llama 3.1, Llama 3.2
- **Mistral** — Mistral 7B, Mistral Nemo
- **Qwen / Qwen2** (Alibaba)
- **Gemma / Gemma2** (Google)
- **Phi / Phi3 / Phi4** (Microsoft)

Best-effort support:
- Mixtral (MoE models)
- Falcon
- MPT
- GPT-BigCode (StarCoder)

## Step 0: Discover Cluster Capabilities

**Before asking about GPU types**, fetch the cluster's available GPUs.

### Get Cluster ID

Extract from workspace FQN (part before the colon):
- Workspace FQN `tfy-ea-dev-eo-az:sai-ws` → Cluster ID `tfy-ea-dev-eo-az`
- Or use `TFY_CLUSTER_ID` from environment if set.

### Fetch Cluster Details

When using direct API, use the **full path** to this skill's `scripts/tfy-api.sh`. The path depends on which agent is installed (e.g. `~/.claude/skills/truefoundry-llm-finetuning/scripts/tfy-api.sh` for Claude Code). In the examples below, replace `TFY_API_SH` with the full path.

```bash
$TFY_API_SH GET /api/svc/v1/clusters/CLUSTER_ID
```

Extract **available GPU types** from the response. Only present GPU types the cluster actually supports.

## Step 1: Gather Fine-Tuning Details

Ask the user these questions:

```
I'll help you fine-tune an LLM. Let me gather a few details:

1. Which base model? (e.g., meta-llama/Llama-3.1-8B-Instruct, mistralai/Mistral-7B-v0.3)
2. What task are you fine-tuning for?
   - Chat / instruction following
   - Text completion
   - Domain-specific Q&A
   - Code generation
   - Other (describe)
3. Fine-tuning method?
   - QLoRA (recommended — lowest resource requirements)
   - LoRA (slightly higher quality, more VRAM)
   - Full fine-tuning (maximum quality, highest resource requirements)
4. Where is your training data?
   - Local file (path to JSONL)
   - TrueFoundry Artifact (artifact FQN)
   - Cloud storage (S3/GCS/Azure Blob pre-signed URL)
5. Does the base model require authentication? (e.g., gated HuggingFace models needing HF_TOKEN)
6. Environment: Quick experiment or production training run?
```

## Step 2: Data Preparation

Training data must be in **JSONL format** (one JSON object per line). Two formats are supported:

### Chat Format (Recommended for Instruction-Tuned Models)

Each line contains a `messages` array with conversation turns:

```jsonl
{"messages": [{"role": "system", "content": "You are a helpful medical assistant."}, {"role": "user", "content": "What are the symptoms of flu?"}, {"role": "assistant", "content": "Common flu symptoms include fever, cough, sore throat, body aches, and fatigue."}]}
{"messages": [{"role": "user", "content": "Explain photosynthesis"}, {"role": "assistant", "content": "Photosynthesis is the process by which plants convert sunlight, water, and CO2 into glucose and oxygen."}]}
```

- `role` must be one of: `system`, `user`, `assistant`
- `system` message is optional but recommended for setting behavior
- Each line must be a complete conversation (can have multiple turns)
- Multi-turn conversations: alternate `user` and `assistant` messages

### Completion Format (For Text Completion Tasks)

Each line has `prompt` and `completion` keys:

```jsonl
{"prompt": "What is the capital of France?", "completion": "The capital of France is Paris."}
{"prompt": "Summarize: The quick brown fox...", "completion": "A fox jumped over a lazy dog."}
```

### Data Validation Checklist

Before launching training, verify:

- [ ] File is valid JSONL (one JSON object per line, no trailing commas)
- [ ] Chat format: each line has a `messages` array with `role` and `content` fields
- [ ] Completion format: each line has `prompt` and `completion` keys
- [ ] No empty `content` or `completion` values
- [ ] Dataset has at least 10 examples (50+ recommended for meaningful fine-tuning)
- [ ] Examples are representative of the target task
- [ ] Total tokens per example do not exceed the model's context window

### Data Validation Script

```python
import json
import sys

def validate_jsonl(filepath):
    errors = []
    line_count = 0
    with open(filepath, 'r') as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            line_count += 1
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                errors.append(f"Line {i}: Invalid JSON — {e}")
                continue

            # Chat format
            if "messages" in obj:
                if not isinstance(obj["messages"], list) or len(obj["messages"]) == 0:
                    errors.append(f"Line {i}: 'messages' must be a non-empty list")
                    continue
                for j, msg in enumerate(obj["messages"]):
                    if "role" not in msg or "content" not in msg:
                        errors.append(f"Line {i}, message {j}: missing 'role' or 'content'")
                    elif msg["role"] not in ("system", "user", "assistant"):
                        errors.append(f"Line {i}, message {j}: invalid role '{msg['role']}'")
                    elif not msg["content"].strip():
                        errors.append(f"Line {i}, message {j}: empty content")
            # Completion format
            elif "prompt" in obj and "completion" in obj:
                if not obj["prompt"].strip():
                    errors.append(f"Line {i}: empty prompt")
                if not obj["completion"].strip():
                    errors.append(f"Line {i}: empty completion")
            else:
                errors.append(f"Line {i}: must have 'messages' (chat) or 'prompt'+'completion' (completion)")

    if errors:
        print(f"Found {len(errors)} error(s):")
        for e in errors[:20]:
            print(f"  {e}")
        if len(errors) > 20:
            print(f"  ... and {len(errors) - 20} more")
        return False
    else:
        print(f"Valid JSONL with {line_count} examples.")
        return True

if __name__ == "__main__":
    validate_jsonl(sys.argv[1])
```

### Data Storage Options

| Storage | How to Reference | Notes |
|---------|-----------------|-------|
| **Local file** | Upload as TrueFoundry Artifact first | Recommended for reproducibility |
| **TrueFoundry Artifact** | Artifact FQN | Best option — versioned, tracked |
| **S3 / GCS / Azure Blob** | Pre-signed URL | Use for large datasets already in cloud |

## Step 3: Select GPU & Resources

Fine-tuning requires **significantly more GPU resources** than inference because training stores gradients, optimizer states, and activation checkpoints in addition to model weights.

### QLoRA GPU Requirements

| Model Params | Min VRAM | Recommended GPU | CPU | Memory |
|-------------|----------|-----------------|-----|--------|
| < 1B | ~4 GB | T4 (16 GB) | 4 | 16 GB |
| 1B–3B | ~8 GB | T4 (16 GB) | 4–8 | 32 GB |
| 3B–7B | ~16 GB | A10_24GB or T4 (16 GB, tight) | 8 | 64 GB |
| 7B–13B | ~24–40 GB | A10_24GB or A100_40GB | 8–12 | 90 GB |
| 13B–30B | ~40–80 GB | A100_40GB or A100_80GB | 12–16 | 128 GB |
| 30B–70B | ~80–160 GB | A100_80GB x2 or H100 | 16+ | 256 GB+ |

### LoRA GPU Requirements

LoRA requires roughly **1.5x the VRAM** of QLoRA (base model is not quantized).

### Full Fine-Tuning GPU Requirements

Full fine-tuning requires roughly **3–4x the VRAM** of QLoRA. Models above 7B typically require multiple GPUs.

**Present a resource suggestion table:**

```
Based on your model (meta-llama/Llama-3.1-8B-Instruct, ~8B params, QLoRA):

| Resource           | Suggested      | Notes                                     |
|--------------------|----------------|-------------------------------------------|
| GPU                | A10_24GB       | 8B params QLoRA needs ~20 GB VRAM         |
| GPU count          | 1              | Single GPU sufficient for QLoRA 8B        |
| CPU request/limit  | 8 / 8 cores    | Data loading + preprocessing              |
| Memory req/limit   | 64 / 80 GB     | Model + gradients + data batches          |
| Ephemeral storage  | 100 GB         | Model download + checkpoints              |

Available GPUs on your cluster: [list from Step 0]

Do you want to use these values, or adjust anything?
```

### Important: Training vs Inference Resources

Fine-tuning needs more resources than inference because:
- **Gradients** — stored for every trainable parameter
- **Optimizer states** — Adam stores 2 states per parameter (momentum + variance)
- **Activation checkpoints** — intermediate activations saved for backward pass
- **Data loading** — CPU and memory for batch preparation
- Rule of thumb: QLoRA training uses **~2x** the VRAM of QLoRA inference; full fine-tuning uses **~4x** the VRAM of FP16 inference

## Step 4: Configure Hyperparameters

### Key Hyperparameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| **epochs** | 3 | 1–10 | Number of passes over the full dataset. More epochs = better learning but risk of overfitting. |
| **learning_rate** | 2e-4 | 1e-5 to 5e-4 | Step size for weight updates. Start small and increase if training loss plateaus. |
| **batch_size** | 4 | 1–32 | Samples processed before a parameter update. Larger = smoother gradients but more VRAM. |
| **max_length** | 2048 | 512–8192 | Maximum sequence length. Longer = more context but more VRAM and slower training. |
| **lora_r** | 16 | 4–64 | LoRA rank — controls adapter capacity. Higher = more expressive but more parameters. |
| **lora_alpha** | 32 | 8–128 | LoRA scaling factor. Common rule: `lora_alpha = 2 * lora_r`. |
| **warmup_ratio** | 0.1 | 0.0–0.2 | Fraction of steps with linearly increasing learning rate. Helps stabilize early training. |
| **weight_decay** | 0.01 | 0.0–0.1 | Regularization to prevent overfitting. |
| **gradient_accumulation_steps** | 4 | 1–16 | Simulates larger batch sizes without more VRAM. Effective batch = batch_size x grad_accum. |

### Hyperparameter Recommendations by Use Case

**Quick experiment (small dataset, < 1000 examples):**
```
epochs: 3–5
learning_rate: 2e-4
batch_size: 4
lora_r: 8
lora_alpha: 16
max_length: 1024
```

**Production training (large dataset, 1000+ examples):**
```
epochs: 2–3
learning_rate: 1e-4
batch_size: 8
lora_r: 16
lora_alpha: 32
max_length: 2048
gradient_accumulation_steps: 4
```

**Domain adaptation (specialized vocabulary/knowledge):**
```
epochs: 5–10
learning_rate: 5e-5
batch_size: 4
lora_r: 32
lora_alpha: 64
max_length: 4096
weight_decay: 0.05
```

## Step 5: Launch Fine-Tuning

Fine-tuning runs as a **TrueFoundry Job**. Two deployment approaches:

### Approach A: Via TrueFoundry UI / Model Catalogue

Direct the user to:
1. Go to `$TFY_BASE_URL` → Model Catalogue
2. Find the base model
3. Click "Fine-tune"
4. Upload dataset and configure hyperparameters
5. Select workspace and GPU
6. Launch the job

### Approach B: Via API (Job Manifest)

Create a training job manifest and deploy via API.

```bash
# Get workspace ID from FQN
$TFY_API_SH GET "/api/svc/v1/workspaces?fqn=${TFY_WORKSPACE_FQN}"
# → use the "id" field from the response
```

Deploy the fine-tuning job:

```bash
$TFY_API_SH PUT /api/svc/v1/apps '{
  "manifest": {
    "type": "job",
    "name": "finetune-llama-3-8b",
    "image": {
      "type": "image",
      "image_uri": "public.ecr.aws/truefoundrycloud/sft-trainer:latest",
      "command": "python -u train.py --model_id $(MODEL_ID) --dataset_path $(DATASET_PATH) --output_dir /output --epochs $(EPOCHS) --learning_rate $(LEARNING_RATE) --batch_size $(BATCH_SIZE) --lora_r $(LORA_R) --lora_alpha $(LORA_ALPHA) --max_length $(MAX_LENGTH) --method $(METHOD)"
    },
    "env": {
      "MODEL_ID": "meta-llama/Llama-3.1-8B-Instruct",
      "DATASET_PATH": "/data/train.jsonl",
      "EPOCHS": "3",
      "LEARNING_RATE": "2e-4",
      "BATCH_SIZE": "4",
      "LORA_R": "16",
      "LORA_ALPHA": "32",
      "MAX_LENGTH": "2048",
      "METHOD": "qlora",
      "HF_TOKEN": "tfy-secret://{TFY_BASE_DOMAIN}:{SECRET_GROUP}:{SECRET_KEY}"
    },
    "resources": {
      "devices": [
        {"type": "nvidia_gpu", "count": 1, "name": "A10_24GB"}
      ],
      "cpu_request": 8,
      "cpu_limit": 8,
      "memory_request": 65536,
      "memory_limit": 81920,
      "ephemeral_storage_request": 50000,
      "ephemeral_storage_limit": 105000
    },
    "retries": 1
  },
  "workspaceId": "WORKSPACE_ID_HERE"
}'
```

### Approach C: Via Notebooks (Experimentation)

For hyperparameter exploration on small data subsets, launch a TrueFoundry Notebook:

1. Go to `$TFY_BASE_URL` → Notebooks
2. Select a GPU-enabled notebook image
3. Attach appropriate GPU (see Step 3)
4. Use the notebook for iterative experimentation
5. Once satisfied, run the full training as a Job (Approach B)

**Notebooks are best for**: Trying different hyperparameters, testing data formats, quick validation on a data subset. **Use Jobs for**: Full production training runs with retry mechanisms and reproducibility.

## Step 6: Monitor Training Progress

### Check Job Status

```bash
# List job runs
$TFY_API_SH GET /api/svc/v1/jobs/JOB_ID/runs

# Get specific run details
$TFY_API_SH GET /api/svc/v1/jobs/JOB_ID/runs/RUN_NAME
```

Or via MCP:
```
tfy_jobs_list_runs(job_id="JOB_ID")
```

### View Training Logs

Use the `logs` skill to stream training logs:
```bash
$TFY_API_SH GET '/api/svc/v1/logs?applicationId=APP_ID&startTs=START_TIMESTAMP'
```

### Key Metrics to Watch

| Metric | What It Means | Healthy Range |
|--------|---------------|---------------|
| **Training loss** | How well the model fits training data | Decreasing over time |
| **Validation loss** | How well the model generalizes | Decreasing, close to training loss |
| **Learning rate** | Current LR (with warmup/decay schedule) | Should follow expected schedule |
| **GPU memory usage** | VRAM utilization | < 95% (above = risk of OOM) |
| **Tokens per second** | Training throughput | Depends on model/GPU; higher is better |

### Signs of Problems

- **Training loss not decreasing** — Learning rate too low, or data quality issues
- **Validation loss increasing while training loss decreases** — Overfitting. Reduce epochs, increase weight_decay, or add more diverse data.
- **OOM (Out of Memory)** — Reduce batch_size, max_length, or lora_r. Switch to QLoRA if using LoRA.
- **NaN loss** — Learning rate too high. Reduce by 10x and retry.
- **Very slow training** — Check GPU utilization. If low, the bottleneck may be data loading (increase CPU/memory).

## Step 7: Deploy the Fine-Tuned Model

After training completes, the fine-tuned model (or LoRA adapter) is saved as a TrueFoundry Artifact. Deploy it for inference using the `llm-deploy` skill.

### Deploying a LoRA/QLoRA Adapter

For LoRA-based fine-tuning, you have two options:

**Option A: Merge adapter with base model, then deploy**

Use the merge script to combine the LoRA adapter with the base model:

```python
# merge_and_upload.py
# Required: pip install torch==2.3.0+cu121 transformers==4.42.3 peft==0.11.1
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer

# Load base model
base_model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")

# Load and merge adapter
model = PeftModel.from_pretrained(base_model, "/path/to/adapter")
merged_model = model.merge_and_unload()

# Save merged model
merged_model.save_pretrained("/output/merged-model")
tokenizer.save_pretrained("/output/merged-model")
```

Then deploy the merged model using the `llm-deploy` skill as a standard HuggingFace model.

**Option B: Deploy with dynamic adapter loading (vLLM)**

vLLM supports loading LoRA adapters at runtime:

```
--model base-model-path --enable-lora --lora-modules adapter-name=/path/to/adapter
```

This is useful for serving multiple fine-tuned variants from the same base model.

### Deploying a Fully Fine-Tuned Model

Deploy directly using the `llm-deploy` skill. The fine-tuned model is a complete model that can be served like any HuggingFace model.

## Configuration Reference

### Full Configuration Template

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

## Composability

- **Find workspace first**: Use `workspaces` skill to get workspace FQN
- **Check cluster GPUs**: Use `workspaces` skill or cluster API for GPU type reference
- **Manage secrets**: Use `secrets` skill to create/find HF token secret groups before launching training
- **Monitor training job**: Use `jobs` skill to check run status
- **View training logs**: Use `logs` skill to stream training output
- **Deploy after fine-tuning**: Use `llm-deploy` skill to serve the fine-tuned model
- **Check deployed model**: Use `applications` skill to verify deployment status

### Typical Workflow

```
1. workspaces   → get workspace FQN and cluster GPUs
2. secrets      → set up HF_TOKEN secret (if gated model)
3. llm-finetuning → launch the fine-tuning job (this skill)
4. jobs         → monitor training progress
5. logs         → debug any training issues
6. llm-deploy   → deploy the fine-tuned model for inference
7. applications → verify the deployed model is healthy
```

## Error Handling

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
- Increase ephemeral_storage_limit
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
