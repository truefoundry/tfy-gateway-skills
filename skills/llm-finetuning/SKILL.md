---
name: llm-finetuning
description: Fine-tunes LLMs on TrueFoundry using QLoRA, LoRA, or full fine-tuning. Supports models up to 70B with GPU jobs, experiment tracking, and one-click deploy. NOT for inference deployment (use llm-deploy skill).
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(python*) Bash(pip*) Bash(*/tfy-api.sh *)
---

<objective>

# LLM Fine-Tuning

Fine-tune large language models on TrueFoundry using QLoRA, LoRA, or full fine-tuning. Supports models up to 70B parameters across Llama, Mistral, Qwen, Gemma, Phi, and other architectures. Training runs as a TrueFoundry Job with GPU acceleration, experiment tracking, and one-click deployment of the finetuned model.

## Scope

Fine-tune LLMs on custom data using QLoRA (default), LoRA, or full fine-tuning. Runs as a TrueFoundry Job with GPU acceleration and experiment tracking.

## When NOT to Use

- User wants to deploy a pre-trained model for inference → use `llm-deploy` skill
- User wants to deploy a regular app or API → use `deploy` skill
- User wants to run a generic batch job → use `deploy` skill with job type
- User wants prompt engineering without training → use `prompts` skill
- User wants to check training job status → use `jobs` skill (after the job is launched)

</objective>

<context>

## Prerequisites

**Always verify before launching a fine-tuning job:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**
3. **GPU availability** — Fine-tuning requires GPU. Check cluster GPU types before proceeding.
4. **Training data** — User must have a dataset in a supported format (see Data Preparation).
5. **HuggingFace token** — Required for gated models (Llama, Gemma, etc.). Use the `secrets` skill to set up a TrueFoundry secret group.

For credential check commands and .env setup, see `references/prerequisites.md`.

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

</context>

<instructions>

## Step 0: Discover Cluster Capabilities

**Before asking about GPU types**, fetch the cluster's available GPUs.

Fetch the cluster's capabilities before asking about resources. See `references/cluster-discovery.md` for how to extract cluster ID from workspace FQN and fetch cluster details (GPUs, base domains, storage classes).

When using direct API, set `TFY_API_SH` to the full path of this skill's `scripts/tfy-api.sh`. See `references/tfy-api-setup.md` for paths per agent.

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

Training data must be in **JSONL format**. Two formats are supported:

- **Chat format** (recommended for instruction-tuned models): each line has a `messages` array with `role`/`content` fields
- **Completion format** (for text completion): each line has `prompt` and `completion` keys

For detailed format examples, validation checklist, validation script, and data storage options, see `references/finetuning-data-validation.md`.

## Step 3: Select GPU & Resources

Fine-tuning requires **significantly more GPU resources** than inference because training stores gradients, optimizer states, and activation checkpoints in addition to model weights.

### QLoRA GPU Requirements

For full GPU reference and DTYPE selection, see `references/gpu-reference.md`.

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

Key parameters to set: `epochs` (default 3), `learning_rate` (default 2e-4), `batch_size` (default 4), `max_length` (default 2048), `lora_r` (default 16), `lora_alpha` (default 32).

For the full hyperparameter table, recommended values by use case (quick experiment, production, domain adaptation), and the complete YAML configuration template, see `references/finetuning-config.md`.

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

For the full YAML configuration template (model, data, training, LoRA, QLoRA, and output settings), see `references/finetuning-config.md`.

</instructions>

<success_criteria>

## Success Criteria

- The fine-tuning job is submitted and running on the correct GPU in the user's chosen workspace
- The training data has been validated as correct JSONL format before job launch
- The user can monitor training loss and validation loss via logs or experiment tracking
- The training job completes without OOM errors, NaN loss, or crash-loops
- The fine-tuned model or LoRA adapter is saved as a TrueFoundry Artifact
- The user has clear next steps to deploy the fine-tuned model using the `llm-deploy` skill

</success_criteria>

<references>

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

</references>

<troubleshooting>

## Error Handling

For detailed error diagnosis and fixes (OOM, NaN loss, training loss plateau, model download failures, GPU pending, overfitting, checkpoint save failures, HuggingFace token issues), see `references/finetuning-errors.md`.

</troubleshooting>
