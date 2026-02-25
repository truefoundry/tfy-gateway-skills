---
name: llm-finetuning
description: Fine-tunes large language models on custom datasets using TrueFoundry. Supports LoRA, QLoRA, and full finetuning methods. Use when adapting, retraining, or customizing LLMs on user-provided data.
license: MIT
compatibility: Requires Bash, curl, and access to a TrueFoundry instance
allowed-tools: Bash(tfy*) Bash(*/tfy-api.sh *)
---

<objective>

# LLM Fine-Tuning

Fine-tune large language models on TrueFoundry using QLoRA, LoRA, or full fine-tuning. Write a YAML manifest and apply with `tfy apply`. REST API fallback when CLI unavailable.

Supports models up to 70B parameters across Llama, Mistral, Qwen, Gemma, Phi, and other architectures. Training runs as a TrueFoundry **application-set** with the `finetune-qlora` template, GPU acceleration, experiment tracking via ML repos, and one-click deployment of the finetuned model.

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
- User wants to check training status → use `applications` skill (after the training is launched)

</objective>

<context>

## Prerequisites

**Always verify before launching a fine-tuning job:**

1. **Credentials** — `TFY_BASE_URL` and `TFY_API_KEY` must be set (env or `.env`)
2. **Workspace** — `TFY_WORKSPACE_FQN` required. **Never auto-pick. Ask the user if missing.**
3. **CLI** — Check `tfy --version`. Install if missing: `pip install truefoundry && tfy login --host "$TFY_BASE_URL"`
4. **GPU availability** — Fine-tuning requires GPU. Check cluster GPU types before proceeding.
5. **Training data** — User must have a dataset in a supported format (see Data Preparation).
6. **ML Repo** — Required for experiment tracking. User needs an existing TrueFoundry ML repo name.
7. **HuggingFace token** — Required for gated models (Llama, Gemma, etc.). Use the `secrets` skill to set up a TrueFoundry secret group.

For credential check commands and .env setup, see `references/prerequisites.md`.

### CLI Detection

```bash
tfy --version
```

| CLI Output | Status | Action |
|-----------|--------|--------|
| `tfy version X.Y.Z` (>= 0.5.0) | Current | Use `tfy apply` as documented below. |
| `tfy version X.Y.Z` (0.3.x-0.4.x) | Outdated | Upgrade: `pip install -U truefoundry`. Core `tfy apply` should still work. |
| Command not found | Not installed | Install: `pip install truefoundry && tfy login --host "$TFY_BASE_URL"` |
| CLI unavailable (no pip/Python) | Fallback | Use REST API via `tfy-api.sh`. See `references/cli-fallback.md`. |

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

1. Which base model? (e.g., unsloth/Llama-3.3-70B-Instruct, meta-llama/Llama-3.1-8B-Instruct)
2. Data format?
   - Chat (OpenAI Chat format — conversations with role/content)
   - Completion (prompt-completion pairs)
3. Where is your training data?
   - Upload — local JSONL file (will be uploaded)
   - TrueFoundry Artifact — reference an existing ML artifact
   - File URL — public URL to a JSONL file
4. ML Repo name? (required for experiment tracking)
5. Does the base model require authentication? (e.g., gated HuggingFace models needing HF_TOKEN)
6. Environment: Quick experiment or production training run?
```

## Step 2: Data Preparation

Training data must be in **JSONL format**. Two data types are supported:

### Data Types

- **`chat`** — OpenAI Chat format (conversations). Each line has a `messages` array with `role`/`content` fields.
  Sample: `https://assets.production.truefoundry.com/chatalpaca-openai-1k.jsonl`
- **`completion`** — OpenAI Completions format (prompt-completion pairs). Each line has `prompt` and `completion` keys.
  Sample: `https://assets.production.truefoundry.com/standford_alpaca_test_2k.jsonl`

### Data Sources

The manifest `data` section supports three source types:

| Type | Description | Manifest Value |
|------|-------------|----------------|
| `upload` | User uploads a local JSONL file | `type: upload`, `training_uri: ""` (set after upload) |
| `truefoundry-artifact` | Reference a TrueFoundry ML artifact | `type: truefoundry-artifact`, `training_uri: "artifact-fqn"` |
| `file-url` | Public URL to a JSONL file | `type: file-url`, `training_uri: "https://..."` |

For detailed format examples and validation, see `references/finetuning-data-validation.md`.

## Step 3: Select GPU & Resources

Fine-tuning requires **significantly more GPU resources** than inference because training stores gradients, optimizer states, and activation checkpoints in addition to model weights.

### Option A: Deployment Specs API (Recommended)

Call the deployment-specs API for resource recommendations:

```bash
$TFY_API_SH GET "/api/svc/v1/model-catalogues/deployment-specs?huggingfaceHubUrl=https://huggingface.co/${HF_MODEL_ID}&workspaceId=${WORKSPACE_ID}&pipelineTagOverride=text-generation"
```

If this returns recommendations, use those as a starting point. Scale up for training (training needs ~2x the resources of inference).

### Option B: GPU Sizing Table (Fallback)

For full GPU reference and DTYPE selection, see `references/gpu-reference.md`.

| Model Params | Min VRAM | Recommended GPU | CPU | Memory |
|-------------|----------|-----------------|-----|--------|
| < 1B | ~4 GB | T4 (16 GB) | 4 | 16 GB |
| 1B-3B | ~8 GB | T4 (16 GB) | 4-8 | 32 GB |
| 3B-7B | ~16 GB | A10_24GB or T4 (16 GB, tight) | 8 | 64 GB |
| 7B-13B | ~24-40 GB | A10_24GB or A100_40GB | 8-12 | 90 GB |
| 13B-30B | ~40-80 GB | A100_40GB or A100_80GB | 12-16 | 128 GB |
| 30B-70B | ~80-160 GB | A100_80GB x2 or H100 | 16+ | 256 GB+ |

### LoRA GPU Requirements

LoRA requires roughly **1.5x the VRAM** of QLoRA (base model is not quantized).

### Full Fine-Tuning GPU Requirements

Full fine-tuning requires roughly **3-4x the VRAM** of QLoRA. Models above 7B typically require multiple GPUs.

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

These go in the `values.hyperparams` section of the application-set manifest:

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| `batch_size` | 1 | 1-8 | Samples per GPU. Keep low for large models. |
| `epochs` | 10 | 1-20 | Training passes. More = risk of overfitting. |
| `learning_rate` | 0.0001 | 1e-5 to 5e-4 | Step size for weight updates. |
| `lora_alpha` | 64 | 8-128 | LoRA scaling factor. Common: `2 * lora_r`. |
| `lora_r` | 32 | 4-64 | LoRA rank — controls adapter capacity. |
| `max_length` | 2048 | 512-8192 | Max sequence length. Longer = more VRAM. |

For recommended values by use case (quick experiment, production, domain adaptation), see `references/finetuning-config.md`.

## Step 5: Launch Fine-Tuning

Fine-tuning uses the **`application-set`** type with the **`finetune-qlora`** template. This is NOT a regular `type: job` manifest.

### Via `tfy apply` (CLI — Recommended)

**1. Generate the manifest:**

```yaml
# tfy-manifest.yaml — LLM Fine-Tuning
type: application-set
template: finetune-qlora
convert_template_manifest: true
values:
  name: finetune-llama-3-8b
  model_id: unsloth/Llama-3.3-70B-Instruct    # HuggingFace model ID
  hf_token: ""                                  # optional, for gated models use tfy-secret:// reference
  ml_repo: my-ml-repo                           # TrueFoundry ML repo for experiment tracking (required)
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
  image_uri: tfy.jfrog.io/tfy-images/llm-finetune:0.4.1   # see references/container-versions.md
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

**Key fields:**
- `template: finetune-qlora` — tells TrueFoundry to use the fine-tuning template
- `convert_template_manifest: true` — required for template-based manifests
- `ml_repo` — TrueFoundry ML repo for experiment tracking (loss curves, metrics)
- `data.type` — one of `upload`, `truefoundry-artifact`, or `file-url`
- `data_type` — `chat` (OpenAI Chat format) or `completion` (prompt-completion pairs)
- `image_uri` — check `references/container-versions.md` for latest version

**2. Preview the manifest:**

```bash
tfy apply -f tfy-manifest.yaml --dry-run --show-diff
```

**3. Apply the manifest:**

```bash
tfy apply -f tfy-manifest.yaml
```

### Via REST API (Fallback)

If the CLI is not available, convert the YAML manifest to JSON and deploy via `tfy-api.sh`. See [references/cli-fallback.md](references/cli-fallback.md) for the conversion process.

## Step 6: Monitor Training Progress

### Check Status

Use the `applications` skill to check the fine-tuning application-set status:

```bash
$TFY_API_SH GET '/api/svc/v1/apps?workspaceFqn=WORKSPACE_FQN&applicationName=FINETUNE_NAME'
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

For detailed deployment options (LoRA adapter merging, dynamic adapter loading with vLLM, full fine-tuned model deployment), see [references/finetuning-model-deployment.md](references/finetuning-model-deployment.md).

## Deployment Flow Summary

1. Check credentials + workspace (prerequisites)
2. Get model info — HuggingFace model ID from user (Step 1)
3. Get ML repo — required for experiment tracking (Step 1)
4. Get training data — upload, artifact, or URL (Step 2)
5. Choose data type — `chat` or `completion` (Step 2)
6. Set hyperparameters with sensible defaults (Step 4)
7. Call deployment-specs API or use GPU sizing table for resources (Step 3)
8. Generate YAML manifest with `type: application-set` and `template: finetune-qlora` (Step 5)
9. Apply: `tfy apply -f tfy-manifest.yaml` (Step 5)

## Configuration Reference

For hyperparameter recommendations by use case, see `references/finetuning-config.md`. For the fine-tuning image version, see `references/container-versions.md`.

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
- **Check ML repos**: Use `ml-repos` skill to find or create an ML repo for experiment tracking
- **Monitor training**: Use `applications` skill to check fine-tuning status
- **View training logs**: Use `logs` skill to stream training output
- **Deploy after fine-tuning**: Use `llm-deploy` skill to serve the fine-tuned model

### Typical Workflow

```
1. workspaces       → get workspace FQN and cluster GPUs
2. secrets          → set up HF_TOKEN secret (if gated model)
3. ml-repos         → get or create ML repo for experiment tracking
4. llm-finetuning   → launch fine-tuning (this skill)
5. applications     → monitor training progress
6. logs             → debug any training issues
7. llm-deploy       → deploy the fine-tuned model for inference
```

</references>

<troubleshooting>

## Error Handling

### CLI Errors

```
tfy: command not found
Install the TrueFoundry CLI:
  pip install truefoundry
  tfy login --host "$TFY_BASE_URL"
```

```
Manifest validation failed.
Check:
- YAML syntax is valid
- Required fields: name, type, workspace_fqn
- Resource values use correct units (memory in MB)
- GPU device name matches cluster availability
```

### Training Errors

For detailed error diagnosis and fixes (OOM, NaN loss, training loss plateau, model download failures, GPU pending, overfitting, checkpoint save failures, HuggingFace token issues), see `references/finetuning-errors.md`.

### REST API Fallback Errors

```
401 Unauthorized — Check TFY_API_KEY is valid
404 Not Found — Check TFY_BASE_URL and API endpoint path
422 Validation Error — Check manifest fields match expected schema
```

</troubleshooting>
